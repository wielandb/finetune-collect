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

    def test_integer_accepts_float_equivalent(self):
        payload = {
            "action": "validate",
            "schema": {
                "type": "object",
                "properties": {"age": {"type": "integer"}},
                "required": ["age"],
                "additionalProperties": False,
            },
            "data": {"age": 67.0},
        }
        result = self.request(payload)
        self.assertTrue(result["ok"])
        self.assertEqual(result["phase"], "instance")

    def test_schema_with_extras(self):
        schema = {
            "title": "Person",
            "type": "object",
            "required": [
                "name",
                "age",
                "date",
                "favorite_color",
                "gender",
                "location",
                "pets",
            ],
            "properties": {
                "name": {
                    "type": "string",
                    "description": "First and Last name",
                    "minLength": 4,
                    "default": "Jeremy Dorn",
                },
                "age": {
                    "type": "integer",
                    "default": 25,
                    "minimum": 18,
                    "maximum": 99,
                },
                "favorite_color": {
                    "type": "string",
                    "format": "color",
                    "title": "favorite color",
                    "default": "#ffa500",
                },
                "gender": {
                    "type": "string",
                    "enum": ["male", "female", "other"],
                },
                "date": {
                    "type": "string",
                    "format": "date",
                    "options": {"flatpickr": {}},
                },
                "location": {
                    "type": "object",
                    "title": "Location",
                    "properties": {
                        "city": {"type": "string", "default": "San Francisco"},
                        "state": {"type": "string", "default": "CA"},
                        "citystate": {
                            "type": "string",
                            "description": "This is generated automatically from the previous two fields",
                            "template": "{{city}}, {{state}}",
                            "watch": {
                                "city": "location.city",
                                "state": "location.state",
                            },
                        },
                    },
                },
                "pets": {
                    "type": "array",
                    "format": "table",
                    "title": "Pets",
                    "uniqueItems": True,
                    "items": {
                        "type": "object",
                        "title": "Pet",
                        "properties": {
                            "type": {
                                "type": "string",
                                "enum": ["cat", "dog", "bird", "reptile", "other"],
                                "default": "dog",
                            },
                            "name": {"type": "string"},
                        },
                    },
                    "default": [{"type": "dog", "name": "Walter"}],
                },
            },
        }
        payload = {"action": "validate_schema", "schema": schema}
        result = self.request(payload)
        self.assertTrue(result["ok"])
        self.assertEqual(result["phase"], "schema")

    def test_usage_on_get(self):
        with urllib.request.urlopen("http://127.0.0.1:8001/") as resp:
            self.assertEqual(resp.status, 200)
            data = json.load(resp)
        self.assertIn("usage", data)

if __name__ == "__main__":
    unittest.main()
