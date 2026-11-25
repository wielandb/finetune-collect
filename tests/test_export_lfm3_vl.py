import base64
import copy
from functools import partial
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from io import BytesIO
import importlib.util
import json
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import threading
import unittest
from unittest.mock import patch

from PIL import Image

from scripts.export_lfm3_vl import ExportError, export_project, load_training_dataset


ROOT = Path(__file__).resolve().parents[1]


def image_bytes(mode="RGB", color="red", fmt="PNG", exif=None):
    buffer = BytesIO()
    kwargs = {"exif": exif} if exif else {}
    Image.new(mode, (8, 4), color).save(buffer, fmt, **kwargs)
    return buffer.getvalue()


def image_message(data=None):
    return {"role": "user", "type": "Image",
            "imageContent": data if data is not None else base64.b64encode(image_bytes()).decode()}


def conversation(ready=True):
    return [{"role": "meta", "type": "meta", "metaData": {"ready": ready, "notes": "private-note"}},
            {"role": "user", "type": "Text", "textContent": "Welches Zeichen?"},
            image_message(),
            {"role": "assistant", "type": "JSON", "jsonSchemaName": "Annotation",
             "jsonSchemaValue": '{\n  "zeichen": ["Fußweg"], "unsicher": false, "wert": null\n}'}]


class _ExportFixture(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.directory = Path(self.temporary.name)
        self.input = self.directory / "project.json"
        self.output = self.directory / "bundle"
        self.project = {"conversations": {"ready": conversation(), "draft": conversation(False)},
                        "settings": {"useGlobalSystemMessage": True, "globalSystemMessage": "Nur JSON.",
                                     "apikey": "private-api-key", "projectCloudKey": "private-cloud-key"},
                        "schemas": [{"name": "Annotation", "schema": {"title": "private-schema"}}]}

    def export(self, **kwargs):
        self.input.write_text(json.dumps(self.project, ensure_ascii=False), encoding="utf-8-sig")
        return export_project(self.input, self.output, **kwargs)

    def rows(self):
        return [json.loads(line) for line in (self.output / "dataset.jsonl").read_text(encoding="utf-8").splitlines()]

    def assert_failure(self, message, **kwargs):
        with self.assertRaisesRegex(ExportError, message):
            self.export(**kwargs)
        self.assertFalse(self.output.exists())
        self.assertFalse(list(self.directory.glob(".lfm3-vl-*")))


class ExportTest(_ExportFixture):
    def test_ready_filter_json_payload_and_no_private_project_fields(self):
        report = self.export(offline=True)
        self.assertEqual(report["conversations"], ["ready"])
        self.assertEqual(report["skipped_unready"], ["draft"])
        row, = self.rows()
        self.assertEqual(set(row), {"messages", "images"})
        self.assertEqual([m["role"] for m in row["messages"]], ["system", "user", "assistant"])
        self.assertEqual([p["type"] for p in row["messages"][1]["content"]], ["text", "image"])
        self.assertEqual(row["messages"][-1]["content"][0]["text"],
                         self.project["conversations"]["ready"][-1]["jsonSchemaValue"])
        self.assertEqual(row["messages"][1]["content"][1], {"type": "image"})
        combined = "".join(p.read_text() for p in self.output.glob("*.json*"))
        for private in ("private-note", "private-api-key", "private-cloud-key", "private-schema"):
            self.assertNotIn(private, combined)
        with Image.open(self.output / row["images"][0]) as decoded:
            self.assertEqual(decoded.mode, "RGB")
            self.assertEqual(decoded.size, (8, 4))

    def test_source_project_is_unchanged(self):
        original = copy.deepcopy(self.project)
        self.export()
        self.assertEqual(self.project, original)
        self.assertEqual(json.loads(self.input.read_text(encoding="utf-8-sig")), original)

    def test_explicit_ids_respect_ready_filter_and_project_order(self):
        self.project["conversationOrder"] = ["draft", "ready", "ready", "deleted"]
        report = self.export(include_unready=True, conversation_ids=["ready", "draft"])
        self.assertEqual(report["conversations"], ["draft", "ready"])
        self.assertEqual(len(self.rows()), 2)

    def test_select_one_conversation(self):
        report = self.export(conversation_ids=["draft"], include_unready=True)
        self.assertEqual(report["conversations"], ["draft"])

    def test_unknown_id_is_an_error(self):
        self.assert_failure("Unknown conversation IDs", conversation_ids=["typo"])

    def test_no_ready_examples_is_an_error(self):
        self.project["conversations"] = {"draft": conversation(False)}
        self.assert_failure("No conversations selected")

    def test_missing_or_non_boolean_ready_is_not_selected(self):
        for value in (None, "true", 1):
            with self.subTest(value=value):
                self.project["conversations"] = {"draft": conversation(value)}
                self.assert_failure("No conversations selected")

    def test_unselected_broken_image_is_never_downloaded(self):
        self.project["conversations"]["draft"][2] = image_message("https://example.invalid/private")
        with patch("scripts.export_lfm3_vl.urlopen") as request:
            self.export()
            request.assert_not_called()

    def test_global_and_local_system_messages_are_both_retained(self):
        self.project["conversations"]["ready"].insert(1, {"role": "system", "type": "Text", "textContent": "Lokal."})
        self.export()
        self.assertEqual(self.rows()[0]["messages"][0]["content"],
                         [{"type": "text", "text": "Nur JSON.\n\nLokal."}])

    def test_disabled_global_system_is_not_used(self):
        self.project["settings"]["useGlobalSystemMessage"] = False
        self.export()
        self.assertEqual(self.rows()[0]["messages"][0]["role"], "user")

    def test_multiple_images_and_multiturn_keep_order_and_deduplicate(self):
        convo = self.project["conversations"]["ready"]
        blue = image_message(base64.b64encode(image_bytes(color="blue")).decode())
        convo.insert(3, blue)
        convo.extend([image_message("data:image/png;base64," + convo[2]["imageContent"]),
                      {"role": "assistant", "type": "Text", "textContent": "Noch einmal rot."}])
        report = self.export()
        row, = self.rows()
        self.assertEqual([m["role"] for m in row["messages"]], ["system", "user", "assistant", "user", "assistant"])
        self.assertEqual(len(row["images"]), 3)
        self.assertEqual(row["images"][0], row["images"][2])
        self.assertNotEqual(row["images"][0], row["images"][1])
        self.assertEqual(report["unique_images"], 2)
        self.assertEqual(sum(p["type"] == "image" for m in row["messages"] for p in m["content"]), 3)

    def test_legacy_json_schema_message_keeps_serialized_value(self):
        self.project["conversations"]["ready"][-1]["type"] = "JSON Schema"
        self.export()
        self.assertEqual(json.loads(self.rows()[0]["messages"][-1]["content"][0]["text"])["zeichen"], ["Fußweg"])

    def test_invalid_json_fails_with_id_and_message_and_cleans_partial_images(self):
        self.project["conversations"]["ready"][-1]["jsonSchemaValue"] = '{"broken":'
        self.assert_failure("Conversation 'ready', message 4:.*not valid JSON")

    def test_nonstandard_json_constants_are_rejected(self):
        self.project["conversations"]["ready"][-1]["jsonSchemaValue"] = '{"value": NaN}'
        self.assert_failure("Non-standard JSON constant")

    def test_unsupported_content_is_rejected_without_silent_data_loss(self):
        for kind in ("Function Call", "Audio", "PDF File", "Unknown"):
            with self.subTest(kind=kind):
                self.project["conversations"]["ready"][-1]["type"] = kind
                self.assert_failure("Unsupported message type")

    def test_incomplete_and_invalid_conversations_are_rejected(self):
        cases = [
            ([image_message()], "end with an assistant"),
            ([{ "role": "assistant", "type": "Text", "textContent": "Alone"}], "start with user"),
            ([{ "role": "user", "type": "Text", "textContent": "Hi"},
              { "role": "assistant", "type": "Text", "textContent": "Hello"}], "at least one input image"),
            ([{ "role": "user", "type": "Text", "textContent": ""}], "Text message is empty"),
            ([{ "role": "tool", "type": "Text", "textContent": "Tool"}], "Unsupported role"),
            ([{ "role": "assistant", "type": "Image", "imageContent": "AA=="}], "must have role user"),
            ([image_message(), {"role": "system", "type": "Text", "textContent": "Late"}], "must precede"),
        ]
        for messages, error in cases:
            with self.subTest(error=error):
                self.project["conversations"] = {"ready": conversation()[:1] + messages}
                self.assert_failure(error)

    def test_base64_data_uri_and_formats_become_rgb_png(self):
        cases = [("RGB", "red", "JPEG"), ("L", 120, "PNG"), ("RGBA", (0, 0, 0, 0), "PNG"),
                 ("RGB", "blue", "WEBP")]
        for index, (mode, color, fmt) in enumerate(cases):
            with self.subTest(mode=mode, fmt=fmt):
                self.output = self.directory / str(index)
                raw = image_bytes(mode, color, fmt)
                encoded = base64.b64encode(raw).decode()
                self.project["conversations"]["ready"][2]["imageContent"] = "data:image/png;base64,\n" + encoded + "\n"
                self.export()
                with Image.open(self.output / self.rows()[0]["images"][0]) as decoded:
                    self.assertEqual(decoded.mode, "RGB")
                    self.assertEqual(decoded.format, "PNG")
                    if mode == "RGBA":
                        self.assertEqual(decoded.getpixel((0, 0)), (255, 255, 255))

    def test_exif_orientation_follows_project_setting(self):
        exif = Image.Exif()
        exif[274] = 6
        encoded = base64.b64encode(image_bytes(fmt="JPEG", exif=exif)).decode()
        self.project["conversations"]["ready"][2]["imageContent"] = encoded
        for mode, size in ((0, (8, 4)), (1, (4, 8)), (2, (4, 8))):
            with self.subTest(mode=mode):
                self.output = self.directory / str(mode)
                self.project["settings"]["imageAutoRotateSetting"] = mode
                self.export()
                with Image.open(self.output / self.rows()[0]["images"][0]) as decoded:
                    self.assertEqual(decoded.size, size)
                    self.assertFalse(decoded.getexif())

    def test_bad_or_missing_image_sources_fail(self):
        for source in ("not base64!", "", None, "file:///etc/passwd", "data:text/plain;base64,AA==",
                       base64.b64encode(b"not an image").decode()):
            with self.subTest(source=source):
                self.project["conversations"]["ready"][2]["imageContent"] = source
                self.assert_failure("Conversation 'ready', message 3:")

    def test_size_limit_and_pixel_limit_are_enforced(self):
        self.assert_failure("byte limit", max_image_bytes=2)
        with patch.object(Image, "MAX_IMAGE_PIXELS", 20):
            self.assert_failure("cannot be decoded")

    def test_existing_output_and_input_are_not_overwritten(self):
        self.output.mkdir()
        (self.output / "keep.txt").write_text("keep")
        with self.assertRaisesRegex(ExportError, "already exists"):
            self.export()
        self.assertEqual((self.output / "keep.txt").read_text(), "keep")
        self.assertEqual(list(self.output.iterdir()), [self.output / "keep.txt"])

    def test_binary_ftproj_and_bad_project_shape_explain_json_requirement(self):
        self.input.write_bytes(b"\x00\xff\x01\x02")
        with self.assertRaisesRegex(ExportError, "binary .ftproj"):
            export_project(self.input, self.output)
        for project in ([], {}, {"conversations": []}, {"conversations": {}, "settings": []}):
            with self.subTest(project=project):
                self.project = project
                self.assert_failure("conversations|settings")

    def test_cli_exports_and_reports_errors_without_tracebacks(self):
        self.input.write_text(json.dumps(self.project))
        command = [sys.executable, str(ROOT / "scripts/export_lfm3_vl.py"), str(self.input), str(self.output)]
        success = subprocess.run(command + ["--offline"], capture_output=True, text=True)
        self.assertEqual(success.returncode, 0, success.stderr)
        self.assertIn("Exported 1 conversations", success.stdout)
        failure = subprocess.run(command, capture_output=True, text=True)
        self.assertEqual(failure.returncode, 1)
        self.assertIn("already exists", failure.stderr)
        self.assertNotIn("Traceback", failure.stderr)

    def test_importable_example_exports_one_ready_or_both_examples(self):
        example = ROOT / "examples/lfm3-vl-traffic-signs.json"
        self.project = json.loads(example.read_text())
        report = self.export(offline=True)
        self.assertEqual(report["conversations"], ["stop-demo"])
        annotation = json.loads(self.rows()[0]["messages"][-1]["content"][0]["text"])
        self.assertEqual(annotation["zeichen"][0]["referenz"], "DE:206")
        schema_name = self.project["conversations"]["stop-demo"][-1]["jsonSchemaName"]
        self.assertEqual(schema_name, self.project["schemas"][0]["name"])
        self.output = self.directory / "both"
        self.assertEqual(len(self.export(include_unready=True)["conversations"]), 2)

    @unittest.skipUnless(importlib.util.find_spec("datasets"), "optional Hugging Face datasets not installed")
    def test_real_huggingface_loader_decodes_images_after_bundle_is_moved(self):
        self.project["conversations"]["ready"].insert(3, image_message())
        self.export()
        moved = self.directory / "moved"
        shutil.move(self.output, moved)
        dataset = load_training_dataset(moved / "dataset.jsonl")
        self.assertEqual(len(dataset), 1)
        row = dataset[0]
        self.assertEqual(len(row["images"]), 2)
        self.assertEqual(row["images"][0].mode, "RGB")
        self.assertEqual(row["images"][0].size, (8, 4))
        self.assertEqual(row["messages"][-1]["content"][0]["text"],
                         self.project["conversations"]["ready"][-1]["jsonSchemaValue"])


class URLExportTest(_ExportFixture):
    def setUp(self):
        super().setUp()
        self.requests = []
        requests = self.requests
        raw = image_bytes(color="green")

        class Handler(BaseHTTPRequestHandler):
            def do_GET(self):
                requests.append(self.path)
                if self.path == "/redirect":
                    self.send_response(302)
                    self.send_header("Location", "/image.png")
                    self.end_headers()
                    return
                if self.path == "/404":
                    self.send_error(404)
                    return
                self.send_response(200)
                self.end_headers()
                self.wfile.write(b"not an image" if self.path == "/bad" else raw)

            def log_message(self, *args):
                pass

        self.server = ThreadingHTTPServer(("127.0.0.1", 0), Handler)
        self.thread = threading.Thread(target=partial(self.server.serve_forever, poll_interval=0.01), daemon=True)
        self.thread.start()
        self.addCleanup(self.server.server_close)
        self.addCleanup(self.thread.join)
        self.addCleanup(self.server.shutdown)
        self.url = f"http://127.0.0.1:{self.server.server_port}"

    def test_urls_redirects_and_cached_images_are_bundled(self):
        self.project["conversations"]["ready"][2] = image_message(self.url + "/redirect")
        self.project["conversations"]["ready"].insert(3, image_message(self.url + "/redirect"))
        self.export()
        row, = self.rows()
        self.assertEqual(row["images"][0], row["images"][1])
        self.assertEqual(self.requests, ["/redirect", "/image.png"])
        self.assertNotIn(self.url, (self.output / "dataset.jsonl").read_text())

    def test_offline_never_makes_a_request(self):
        self.project["conversations"]["ready"][2] = image_message(self.url + "/image.png")
        self.assert_failure("offline", offline=True)
        self.assertEqual(self.requests, [])

    def test_http_failures_and_non_image_responses_leave_no_partial_output(self):
        for route, error in (("/404", "Could not download"), ("/bad", "cannot be decoded")):
            with self.subTest(route=route):
                self.project["conversations"]["ready"][2] = image_message(self.url + route)
                self.assert_failure(error)

    def test_url_size_limit(self):
        self.project["conversations"]["ready"][2] = image_message(self.url + "/image.png")
        self.assert_failure("byte limit", max_image_bytes=2)


if __name__ == "__main__":
    unittest.main()
