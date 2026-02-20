extends RefCounted

class_name SchemaRemoteRefLoader

const MAX_REMOTE_SCHEMA_FETCHES = 64
const ACCEPT_HEADER = "Accept: application/schema+json, application/json"

static var _schema_cache = {}

static func clear_cache() -> void:
	_schema_cache.clear()

static func resolve_schema_with_remote(owner: Node, schema: Dictionary, seed_external_schemas: Dictionary = {}) -> Dictionary:
	var external_schemas = {}
	for cache_key in _schema_cache.keys():
		var cache_schema = _schema_cache[cache_key]
		if cache_schema is Dictionary:
			external_schemas[str(cache_key)] = cache_schema.duplicate(true)
	for seed_key in seed_external_schemas.keys():
		var seed_schema = seed_external_schemas[seed_key]
		if seed_schema is Dictionary:
			external_schemas[str(seed_key)] = seed_schema.duplicate(true)

	var queue = SchemaRefResolver.collect_external_document_urls(schema)
	var seen = {}
	var errors = []
	var fetch_count = 0

	while queue.size() > 0:
		if fetch_count >= MAX_REMOTE_SCHEMA_FETCHES:
			errors.append({"url": "", "message": "max external schema fetch limit reached"})
			break
		var document_url = str(queue.pop_front())
		if document_url == "":
			continue
		if seen.has(document_url):
			continue
		seen[document_url] = true

		if external_schemas.has(document_url):
			var cached_nested = SchemaRefResolver.collect_external_document_urls(external_schemas[document_url], document_url)
			_append_pending_urls(queue, seen, cached_nested)
			continue

		var fetch_result = await _fetch_schema_document(owner, document_url)
		fetch_count += 1
		if not bool(fetch_result.get("ok", false)):
			errors.append({
				"url": document_url,
				"message": str(fetch_result.get("error", "request failed"))
			})
			continue

		var fetched_schema = fetch_result.get("schema", null)
		if not (fetched_schema is Dictionary):
			errors.append({"url": document_url, "message": "schema response must be a JSON object"})
			continue
		external_schemas[document_url] = fetched_schema
		_schema_cache[document_url] = fetched_schema.duplicate(true)
		var nested_urls = SchemaRefResolver.collect_external_document_urls(fetched_schema, document_url)
		_append_pending_urls(queue, seen, nested_urls)

	var resolved = SchemaRefResolver.resolve_schema(schema, external_schemas)
	resolved["external_schemas"] = external_schemas
	resolved["external_errors"] = errors
	return resolved

static func _append_pending_urls(queue: Array, seen: Dictionary, urls: Array) -> void:
	for url in urls:
		var normalized_url = str(url)
		if normalized_url == "":
			continue
		if seen.has(normalized_url):
			continue
		if queue.has(normalized_url):
			continue
		queue.append(normalized_url)

static func _fetch_schema_document(owner: Node, url: String) -> Dictionary:
	if owner == null or not owner.is_inside_tree():
		return {"ok": false, "error": "owner node is not ready for HTTP requests"}
	var request = HTTPRequest.new()
	owner.add_child(request)
	var headers = PackedStringArray()
	headers.append(ACCEPT_HEADER)
	var request_err = request.request(url, headers, HTTPClient.METHOD_GET, "")
	if request_err != OK:
		request.queue_free()
		return {"ok": false, "error": "request start failed: " + str(request_err)}
	var response = await request.request_completed
	request.queue_free()
	var request_status = int(response[0])
	var http_status = int(response[1])
	if request_status != HTTPRequest.RESULT_SUCCESS:
		return {"ok": false, "error": "network error: " + str(request_status)}
	if http_status < 200 or http_status >= 300:
		return {"ok": false, "error": "HTTP status " + str(http_status)}
	var response_body = response[3]
	var json_text = response_body.get_string_from_utf8()
	var parsed = JSON.parse_string(json_text)
	if not (parsed is Dictionary):
		return {"ok": false, "error": "response is not a JSON object"}
	return {"ok": true, "schema": parsed}
