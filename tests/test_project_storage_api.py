import json
import os
import subprocess
import time
import unittest
import urllib.error
import urllib.request


class ProjectStorageAPITest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        repo_root = os.path.dirname(os.path.dirname(__file__))
        cls.repo_root = repo_root
        cls.script = os.path.join(repo_root, "scripts", "project-storage.php")
        cls.storage_dir = os.path.join(repo_root, "scripts", "stored_projects")
        cls.proc = subprocess.Popen(
            ["php", "-S", "127.0.0.1:8003", cls.script],
            cwd=repo_root,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
        time.sleep(1)

    @classmethod
    def tearDownClass(cls):
        cls.proc.terminate()
        try:
            cls.proc.wait(timeout=5)
        except subprocess.TimeoutExpired:
            cls.proc.kill()

    def _request(self, payload):
        data = json.dumps(payload).encode("utf-8")
        req = urllib.request.Request(
            "http://127.0.0.1:8003/",
            data=data,
            headers={"Content-Type": "application/json"},
            method="POST",
        )
        try:
            with urllib.request.urlopen(req) as resp:
                return resp.status, json.load(resp)
        except urllib.error.HTTPError as exc:
            body = exc.read().decode("utf-8")
            parsed = {}
            if body.strip():
                try:
                    parsed = json.loads(body)
                except json.JSONDecodeError:
                    parsed = {"ok": False, "error": body}
            return exc.code, parsed

    def test_save_and_load_roundtrip(self):
        project_name = "project_storage_roundtrip"
        save_status, save_result = self._request(
            {
                "action": "save",
                "key": "CHANGE_ME",
                "project": project_name,
                "data": {
                    "functions": [],
                    "conversations": {"abc": [{"role": "meta", "type": "meta"}]},
                    "settings": {"projectStorageMode": 1},
                    "graders": [],
                    "schemas": [],
                },
            }
        )
        self.assertEqual(save_status, 200)
        self.assertTrue(save_result.get("ok", False))
        self.assertEqual(save_result.get("project"), project_name)
        self.assertGreater(int(save_result.get("bytes", 0)), 0)

        load_status, load_result = self._request(
            {
                "action": "load",
                "key": "CHANGE_ME",
                "project": project_name,
            }
        )
        self.assertEqual(load_status, 200)
        self.assertTrue(load_result.get("ok", False))
        self.assertEqual(load_result.get("project"), project_name)
        loaded_data = load_result.get("data", {})
        self.assertIn("conversations", loaded_data)
        self.assertIn("settings", loaded_data)

    def test_invalid_key_returns_403(self):
        status, result = self._request(
            {
                "action": "test",
                "key": "WRONG_KEY",
            }
        )
        self.assertEqual(status, 403)
        self.assertFalse(result.get("ok", True))

    def test_invalid_project_name_returns_400(self):
        status, result = self._request(
            {
                "action": "save",
                "key": "CHANGE_ME",
                "project": "../bad-name",
                "data": {},
            }
        )
        self.assertEqual(status, 400)
        self.assertFalse(result.get("ok", True))

    def test_load_missing_project_returns_404(self):
        status, result = self._request(
            {
                "action": "load",
                "key": "CHANGE_ME",
                "project": "project_does_not_exist_404",
            }
        )
        self.assertEqual(status, 404)
        self.assertFalse(result.get("ok", True))


if __name__ == "__main__":
    unittest.main()
