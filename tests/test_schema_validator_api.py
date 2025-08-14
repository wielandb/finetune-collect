import json
import os
import subprocess
import time
import unittest
import urllib.request

class SchemaValidatorAPITest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        repo_root = os.path.dirname(os.path.dirname(__file__))
        script = os.path.join(repo_root, "scripts", "schema_validator.php")
        cls.proc = subprocess.Popen(
            ["php", "-S", "127.0.0.1:8001", script],
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

    def request(self, payload):
        data = json.dumps(payload).encode("utf-8")
        req = urllib.request.Request(
            "http://127.0.0.1:8001/",
            data=data,
            headers={"Content-Type": "application/json"},
            method="POST",
        )
        with urllib.request.urlopen(req) as resp:
            return json.load(resp)

    def test_validate_success(self):
        payload = {
            "action": "validate",
            "schema": {
                "type": "object",
                "properties": {"name": {"type": "string"}},
                "required": ["name"],
                "additionalProperties": False,
            },
            "data": {"name": "Alice"},
        }
        result = self.request(payload)
        self.assertTrue(result["ok"])
        self.assertEqual(result["phase"], "instance")

    def test_validate_failure(self):
        payload = {
            "action": "validate",
            "schema": {
                "type": "object",
                "properties": {"name": {"type": "string"}},
                "required": ["name"],
                "additionalProperties": False,
            },
            "data": {},
        }
        result = self.request(payload)
        self.assertFalse(result["ok"])
        self.assertEqual(result["phase"], "instance")
        self.assertGreater(len(result["errors"]), 0)

    def test_validate_schema_only(self):
        payload = {
            "action": "validate_schema",
            "schema": {
                "type": "object",
                "properties": {"name": {"type": "string"}},
                "required": ["name"],
                "additionalProperties": False,
            },
        }
        result = self.request(payload)
        self.assertTrue(result["ok"])
        self.assertEqual(result["phase"], "schema")

if __name__ == "__main__":
    unittest.main()
