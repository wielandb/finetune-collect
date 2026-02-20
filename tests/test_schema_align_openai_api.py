import json
import os
import subprocess
import time
import unittest
import urllib.request

class SchemaAlignOpenAITest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        repo_root = os.path.dirname(os.path.dirname(__file__))
        script = os.path.join(repo_root, "scripts", "schema_align_openai.php")
        cls.proc = subprocess.Popen(
            ["php", "-S", "127.0.0.1:8002", script],
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
            "http://127.0.0.1:8002/",
            data=data,
            headers={"Content-Type": "application/json"},
            method="POST",
        )
        with urllib.request.urlopen(req) as resp:
            return json.load(resp)

    def test_normalization(self):
        payload = {
            "schema": {
                "title": "Example",
                "type": "object",
                "properties": {"a": {"type": "string"}},
                "additionalProperties": True,
            }
        }
        result = self.request(payload)
        self.assertTrue(result["ok"])
        self.assertEqual(result["errors"], [])
        self.assertEqual(result["name"], "Example")
        schema = result["schema"]
        self.assertEqual(schema["additionalProperties"], False)
        self.assertEqual(schema["required"], ["a"])

    def test_too_many_enum_values_error(self):
        enum_values = [f"v{i}" for i in range(1001)]
        payload = {
            "schema": {
                "type": "object",
                "properties": {
                    "choice": {
                        "type": "string",
                        "enum": enum_values,
                    }
                }
            }
        }
        result = self.request(payload)
        self.assertFalse(result["ok"])
        self.assertTrue(any(err.get("code") == "too_many_enum_values" for err in result["errors"]))

if __name__ == "__main__":
    unittest.main()
