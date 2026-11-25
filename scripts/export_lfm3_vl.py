"""Export finetune-collect JSON projects as portable TRL vision SFT datasets.

The on-disk images column contains relative PNG paths. load_training_dataset()
resolves these paths and decodes them as PIL images for TRL's SFTTrainer.
"""

from __future__ import annotations

import argparse
import base64
import binascii
import hashlib
from io import BytesIO
import json
import math
from pathlib import Path
import re
import tempfile
from urllib.error import URLError
from urllib.parse import urlsplit
from urllib.request import Request, urlopen
import warnings

from PIL import Image, ImageOps, UnidentifiedImageError


class ExportError(ValueError):
    """A project cannot be converted without losing or corrupting its data."""


def _reject_constant(value):
    raise ExportError(f"Non-standard JSON constant {value} is not supported")


def read_project(path: str | Path) -> dict:
    """Read a JSON project, including JSON files saved with a UTF-8 BOM.

    Native .ftproj files use Godot store_var, not JSON. Save those as .json in
    finetune-collect first. The file extension alone is not used for detection.
    """
    try:
        project = json.loads(Path(path).read_text(encoding="utf-8-sig"),
                             parse_constant=_reject_constant)
    except (UnicodeError, json.JSONDecodeError) as exc:
        raise ExportError("Input is not a JSON project. Save it as .json in "
                          "finetune-collect; binary .ftproj is not supported.") from exc
    if not isinstance(project, dict) or not isinstance(project.get("conversations"), dict):
        raise ExportError("Project must contain a conversations object")
    if not isinstance(project.get("settings", {}), dict):
        raise ExportError("Project settings must be an object")
    return project


class _ImageStore:
    def __init__(self, directory, *, offline, timeout, max_bytes, auto_rotate):
        self.directory = directory
        self.offline = offline
        self.timeout = timeout
        self.max_bytes = max_bytes
        self.auto_rotate = auto_rotate
        self.cache = {}

    def _read(self, source):
        scheme = urlsplit(source).scheme.lower()
        if scheme in ("http", "https"):
            if self.offline:
                raise ExportError("Image URL requires a download; --offline is enabled")
            parsed = urlsplit(source)
            if not parsed.hostname or parsed.username or parsed.password:
                raise ExportError("Image URL must have a host and no embedded credentials")
            request = Request(source, headers={"User-Agent": "finetune-collect/lfm3-vl-export"})
            try:
                with urlopen(request, timeout=self.timeout) as response:
                    raw = response.read(self.max_bytes + 1)
            except (URLError, OSError, ValueError) as exc:
                # Do not echo URLs: they can contain private access tokens.
                raise ExportError("Could not download image URL") from exc
        else:
            payload = source
            if source.startswith("data:"):
                match = re.fullmatch(r"data:image/[\w.+-]+;base64,(.*)", source, re.DOTALL)
                if not match:
                    raise ExportError("Image data URI must use image/*;base64")
                payload = match.group(1)
            elif scheme:
                raise ExportError("Image source must be Base64, an image data URI, or HTTP(S)")
            payload = "".join(payload.split())
            if len(payload) > 4 * ((self.max_bytes + 2) // 3):
                raise ExportError("Image exceeds the configured byte limit")
            try:
                raw = base64.b64decode(payload, validate=True)
            except (ValueError, binascii.Error) as exc:
                raise ExportError("Invalid Base64 image") from exc
        if len(raw) > self.max_bytes:
            raise ExportError("Image exceeds the configured byte limit")
        return raw

    def add(self, source):
        if not isinstance(source, str) or not source.strip():
            raise ExportError("imageContent must contain an image")
        source = source.strip()
        if source in self.cache:
            return self.cache[source]
        try:
            raw = self._read(source)
            with warnings.catch_warnings():
                warnings.simplefilter("error", Image.DecompressionBombWarning)
                with Image.open(BytesIO(raw)) as image:
                    if getattr(image, "n_frames", 1) != 1:
                        raise ExportError("Multi-frame images are not supported")
                    image.load()
                    if self.auto_rotate:
                        image = ImageOps.exif_transpose(image)
                    if "A" in image.getbands() or "transparency" in image.info:
                        rgba = image.convert("RGBA")
                        rgb = Image.new("RGB", rgba.size, "white")
                        rgb.paste(rgba, mask=rgba.getchannel("A"))
                    else:
                        rgb = image.convert("RGB")
                    # Re-encode pixels only: no source URL, EXIF or other metadata.
                    clean = Image.new("RGB", rgb.size)
                    clean.paste(rgb)
                    buffer = BytesIO()
                    clean.save(buffer, format="PNG")
        except (UnidentifiedImageError, OSError, ValueError,
                Image.DecompressionBombError, Image.DecompressionBombWarning) as exc:
            if isinstance(exc, ExportError):
                raise
            raise ExportError("Image cannot be decoded as a supported raster image") from exc
        data = buffer.getvalue()
        relative = "images/" + hashlib.sha256(data).hexdigest() + ".png"
        target = self.directory / relative
        target.parent.mkdir(exist_ok=True)
        if not target.exists():
            target.write_bytes(data)
        self.cache[source] = relative
        return relative


def _append_part(messages, role, part):
    # The app stores a question and each image as separate messages of one role.
    if not messages or messages[-1]["role"] != role:
        messages.append({"role": role, "content": []})
    content = messages[-1]["content"]
    if content and content[-1]["type"] == part["type"] == "text":
        content[-1]["text"] += "\n\n" + part["text"]
    else:
        content.append(part)


def _convert_conversation(conversation, settings, images):
    messages = []
    image_paths = []
    if settings.get("useGlobalSystemMessage", False):
        text = settings.get("globalSystemMessage", "")
        if not isinstance(text, str):
            raise ExportError("globalSystemMessage must be text")
        if text.strip():
            _append_part(messages, "system", {"type": "text", "text": text})
    for index, message in enumerate(conversation, 1):
        try:
            if not isinstance(message, dict):
                raise ExportError("Message must be an object")
            role = message.get("role")
            kind = message.get("type", "Text")
            if role == "meta" or kind == "meta":
                continue
            if role not in ("system", "user", "assistant"):
                raise ExportError(f"Unsupported role: {role!r}")
            if role == "system" and any(m["role"] != "system" for m in messages):
                raise ExportError("System messages must precede user/assistant messages")
            if kind == "Image":
                if role != "user":
                    raise ExportError("Vision SFT input images must have role user")
                image_paths.append(images.add(message.get("imageContent")))
                part = {"type": "image"}
            elif kind in ("JSON", "JSON Schema"):
                text = message.get("jsonSchemaValue")
                if not isinstance(text, str):
                    raise ExportError("jsonSchemaValue must be serialized JSON text")
                try:
                    json.loads(text, parse_constant=_reject_constant)
                except json.JSONDecodeError as exc:
                    raise ExportError("jsonSchemaValue is not valid JSON") from exc
                part = {"type": "text", "text": text}
            elif kind == "Text":
                text = message.get("textContent", "")
                if not isinstance(text, str) or not text.strip():
                    raise ExportError("Text message is empty; provide textContent")
                part = {"type": "text", "text": text}
            else:
                raise ExportError(f"Unsupported message type: {kind!r}")
            _append_part(messages, role, part)
        except (ExportError, ValueError) as exc:
            raise ExportError(f"message {index}: {exc}") from exc
    roles = [m["role"] for m in messages if m["role"] != "system"]
    if not roles or roles[0] != "user" or roles[-1] != "assistant":
        raise ExportError("Conversation must start with user input and end with an assistant answer")
    if not image_paths:
        raise ExportError("Conversation must contain at least one input image")
    return {"messages": messages, "images": image_paths}


def export_project(input_file: str | Path, output_dir: str | Path, *,
                   include_unready: bool = False, conversation_ids: list[str] | None = None,
                   offline: bool = False, timeout: float = 30,
                   max_image_bytes: int = 32 * 1024 * 1024) -> dict:
    """Export completed conversations to a new directory; fail atomically.

    The OpenAI export settings are independent of this SFT-only converter.
    No source settings, credentials, notes or schema definitions enter the dataset.
    """
    if not math.isfinite(timeout) or timeout <= 0 or max_image_bytes <= 0:
        raise ExportError("timeout and max_image_bytes must be positive finite values")
    project = read_project(input_file)
    conversations = project["conversations"]
    settings = project.get("settings", {})
    selected = set(conversation_ids) if conversation_ids is not None else set(conversations)
    unknown = selected - conversations.keys()
    if unknown:
        raise ExportError(f"Unknown conversation IDs: {', '.join(sorted(unknown))}")
    order = project.get("conversationOrder", [])
    if not isinstance(order, list) or any(not isinstance(key, str) for key in order):
        raise ExportError("conversationOrder must be an array of conversation IDs")
    order = list(dict.fromkeys([key for key in order if key in conversations] + list(conversations)))
    exported = []
    skipped = []
    output = Path(output_dir).absolute()
    if output.exists():
        raise ExportError("Output directory already exists; choose a new directory")
    output.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix=".lfm3-vl-", dir=output.parent) as temporary:
        stage = Path(temporary)
        images = _ImageStore(stage, offline=offline, timeout=timeout, max_bytes=max_image_bytes,
                             auto_rotate=settings.get("imageAutoRotateSetting", 0) in (1, 2))
        with (stage / "dataset.jsonl").open("w", encoding="utf-8", newline="\n") as handle:
            for key in order:
                if key not in selected:
                    continue
                conversation = conversations[key]
                if not isinstance(conversation, list):
                    raise ExportError(f"Conversation {key!r}: expected an array of messages")
                ready = any(isinstance(m, dict) and m.get("type") == "meta"
                            and isinstance(m.get("metaData"), dict)
                            and m["metaData"].get("ready") is True for m in conversation)
                if not include_unready and not ready:
                    skipped.append(key)
                    continue
                try:
                    row = _convert_conversation(conversation, settings, images)
                except ExportError as exc:
                    raise ExportError(f"Conversation {key!r}, {exc}") from exc
                handle.write(json.dumps(row, ensure_ascii=False, allow_nan=False) + "\n")
                exported.append(key)
        if not exported:
            raise ExportError("No conversations selected for export. Mark examples ready or use --include-unready.")
        report = {"format": "trl-vision-sft", "conversations": exported,
                  "skipped_unready": skipped,
                  "unique_images": len(set(images.cache.values()))}
        (stage / "export-info.json").write_text(
            json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        stage.rename(output)
    return report


def load_training_dataset(dataset_file: str | Path):
    """Load a bundle's JSONL as a Hugging Face Dataset with decoded PIL images.

    Requires the optional `datasets` package. Paths resolve relative to the
    dataset file, so moving the complete bundle or changing cwd is supported.
    """
    from datasets import Dataset, Image as DatasetImage, Sequence

    path = Path(dataset_file).resolve()
    rows = []
    with path.open(encoding="utf-8") as handle:
        for line in handle:
            row = json.loads(line)
            row["images"] = [str((path.parent / image).resolve()) for image in row["images"]]
            rows.append(row)
    return Dataset.from_list(rows).cast_column("images", Sequence(DatasetImage()))


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("project", type=Path, help="JSON project saved by finetune-collect")
    parser.add_argument("output", type=Path, help="New output directory for JSONL and RGB images")
    parser.add_argument("--include-unready", action="store_true", help="Also export unfinished examples")
    parser.add_argument("--conversation-id", action="append", dest="conversation_ids",
                        help="Export only this ID (repeatable; ready filter still applies)")
    parser.add_argument("--offline", action="store_true", help="Fail on URLs; use embedded images only")
    parser.add_argument("--timeout", type=float, default=30, help="Image download timeout in seconds (default: 30)")
    parser.add_argument("--max-image-mib", type=int, default=32, help="Maximum source image size (default: 32 MiB)")
    args = parser.parse_args(argv)
    try:
        report = export_project(args.project, args.output, include_unready=args.include_unready,
                                conversation_ids=args.conversation_ids, offline=args.offline,
                                timeout=args.timeout, max_image_bytes=args.max_image_mib * 1024 * 1024)
    except (ExportError, OSError) as exc:
        parser.exit(1, f"Export failed: {exc}\n")
    print(f"Exported {len(report['conversations'])} conversations, {report['unique_images']} unique images; "
          f"skipped {len(report['skipped_unready'])} unfinished conversations.\n{args.output / 'dataset.jsonl'}")


if __name__ == "__main__":
    main()
