import requests

BASE_URL = "http://localhost:8000/validator/json-schema-validator.php"

def test_valid_schema():
    payload = {
        "schema": {
            "$schema": "https://json-schema.org/draft/2020-12/schema",
            "title": "Test",
            "type": "object",
            "properties": {"name": {"type": "string"}}
        }
    }
    r = requests.post(BASE_URL, json=payload)
    assert r.json().get("schema_valid") is True

def test_invalid_schema():
    payload = {"schema": {"title": 5}}
    r = requests.post(BASE_URL, json=payload)
    assert r.json().get("schema_valid") is False

def test_data_validation():
    schema = {
        "$schema": "https://json-schema.org/draft/2020-12/schema",
        "title": "Test",
        "type": "object",
        "properties": {"name": {"type": "string"}},
        "required": ["name"]
    }
    valid_data = {"name": "Alice"}
    invalid_data = {"name": 5}
    r_ok = requests.post(BASE_URL, json={"schema": schema, "data": valid_data})
    assert r_ok.json().get("data_valid") is True
    r_bad = requests.post(BASE_URL, json={"schema": schema, "data": invalid_data})
    assert r_bad.json().get("data_valid") is False

if __name__ == "__main__":
    test_valid_schema()
    test_invalid_schema()
    test_data_validation()
