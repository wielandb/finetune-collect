extends RefCounted

const _EXIF_TAG_ORIENTATION = 0x0112
const _JPEG_MARKER_PREFIX = 0xFF
const _JPEG_SOI_MARKER = 0xD8
const _JPEG_EOI_MARKER = 0xD9
const _JPEG_SOS_MARKER = 0xDA
const _JPEG_APP1_MARKER = 0xE1
const _ROTATE_CLOCKWISE = 0
const _ROTATE_COUNTERCLOCKWISE = 1

static func base64_payload_from_data_uri(data: String) -> String:
	var trimmed = str(data).strip_edges()
	var marker = "base64,"
	var marker_index = trimmed.find(marker)
	if marker_index == -1:
		return trimmed
	return trimmed.substr(marker_index + marker.length())

static func guess_image_format_from_data_uri(data: String) -> String:
	var lower_data = str(data).strip_edges().to_lower()
	if not lower_data.begins_with("data:image/"):
		return ""
	var slash_index = lower_data.find("/")
	var semi_index = lower_data.find(";")
	if slash_index == -1 or semi_index == -1 or semi_index <= slash_index:
		return ""
	var image_format = lower_data.substr(slash_index + 1, semi_index - slash_index - 1)
	return _normalize_format_hint(image_format)

static func detect_image_format_from_raw(raw: PackedByteArray) -> String:
	if raw.size() >= 3 and raw[0] == 0xFF and raw[1] == 0xD8 and raw[2] == 0xFF:
		return "jpg"
	if raw.size() >= 8 and raw[0] == 0x89 and raw[1] == 0x50 and raw[2] == 0x4E and raw[3] == 0x47:
		return "png"
	if raw.size() >= 12 and raw[0] == 0x52 and raw[1] == 0x49 and raw[2] == 0x46 and raw[3] == 0x46 and raw[8] == 0x57 and raw[9] == 0x45 and raw[10] == 0x42 and raw[11] == 0x50:
		return "webp"
	return ""

static func decode_image_from_buffer(raw: PackedByteArray, image_type_hint: String = "", content_type_hint: String = "") -> Image:
	var image = Image.new()
	var decode_error = ERR_PARSE_ERROR
	var normalized_format = _normalize_format_hint(image_type_hint)
	var lower_content_type = str(content_type_hint).to_lower()
	if lower_content_type.find("image/png") != -1:
		decode_error = image.load_png_from_buffer(raw)
	elif lower_content_type.find("image/jpeg") != -1 or lower_content_type.find("image/jpg") != -1:
		decode_error = image.load_jpg_from_buffer(raw)
	elif lower_content_type.find("image/webp") != -1 and image.has_method("load_webp_from_buffer"):
		decode_error = int(image.call("load_webp_from_buffer", raw))
	elif normalized_format == "png":
		decode_error = image.load_png_from_buffer(raw)
	elif normalized_format == "jpg":
		decode_error = image.load_jpg_from_buffer(raw)
	elif normalized_format == "webp" and image.has_method("load_webp_from_buffer"):
		decode_error = int(image.call("load_webp_from_buffer", raw))
	else:
		decode_error = image.load_png_from_buffer(raw)
		if decode_error != OK:
			decode_error = image.load_jpg_from_buffer(raw)
		if decode_error != OK and image.has_method("load_webp_from_buffer"):
			decode_error = int(image.call("load_webp_from_buffer", raw))
	if decode_error != OK:
		return null
	return image

static func process_base64_image(base64_data: String, auto_rotate_mode: int, format_hint: String = "", content_type_hint: String = "", jpg_quality: float = 0.95) -> Dictionary:
	var payload = base64_payload_from_data_uri(base64_data)
	if payload == "":
		return {
			"ok": false,
			"error": "empty_payload",
			"payload": "",
			"format": "",
			"changed": false,
			"orientation_applied": false
		}
	var raw = Marshalls.base64_to_raw(payload)
	if raw.size() == 0:
		return {
			"ok": false,
			"error": "decode_base64_failed",
			"payload": payload,
			"format": _normalize_format_hint(format_hint),
			"changed": false,
			"orientation_applied": false
		}
	var normalized_hint = _normalize_format_hint(format_hint)
	if normalized_hint == "":
		normalized_hint = detect_image_format_from_raw(raw)
	var image = decode_image_from_buffer(raw, normalized_hint, content_type_hint)
	if image == null:
		return {
			"ok": false,
			"error": "decode_image_failed",
			"payload": payload,
			"format": normalized_hint,
			"changed": false,
			"orientation_applied": false
		}
	var orientation = 1
	var orientation_applied = false
	if int(auto_rotate_mode) > 0 and normalized_hint == "jpg":
		orientation = get_jpeg_exif_orientation(raw)
		orientation_applied = apply_orientation_transform(image, orientation)
	var output_payload = payload
	var changed = false
	if int(auto_rotate_mode) == 2 and orientation_applied:
		output_payload = encode_image_to_base64(image, normalized_hint, jpg_quality)
		if output_payload == "":
			return {
				"ok": false,
				"error": "encode_image_failed",
				"payload": payload,
				"format": normalized_hint,
				"changed": false,
				"orientation_applied": false
			}
		changed = output_payload != payload
	return {
		"ok": true,
		"image": image,
		"payload": output_payload,
		"format": normalized_hint,
		"changed": changed,
		"orientation": orientation,
		"orientation_applied": orientation_applied
	}

static func encode_image_to_base64(image: Image, format_hint: String, jpg_quality: float = 0.95) -> String:
	var normalized_hint = _normalize_format_hint(format_hint)
	var encoded_buffer = PackedByteArray()
	if normalized_hint == "png":
		encoded_buffer = image.save_png_to_buffer()
	elif normalized_hint == "webp" and image.has_method("save_webp_to_buffer"):
		encoded_buffer = image.save_webp_to_buffer(false, jpg_quality)
	else:
		encoded_buffer = image.save_jpg_to_buffer(jpg_quality)
	if encoded_buffer.size() == 0:
		return ""
	return Marshalls.raw_to_base64(encoded_buffer)

static func get_jpeg_exif_orientation(raw: PackedByteArray) -> int:
	if raw.size() < 4:
		return 1
	if raw[0] != _JPEG_MARKER_PREFIX or raw[1] != _JPEG_SOI_MARKER:
		return 1
	var offset = 2
	while offset + 3 < raw.size():
		if raw[offset] != _JPEG_MARKER_PREFIX:
			offset += 1
			continue
		var marker = int(raw[offset + 1])
		offset += 2
		while marker == _JPEG_MARKER_PREFIX and offset < raw.size():
			marker = int(raw[offset])
			offset += 1
		if marker == _JPEG_EOI_MARKER or marker == _JPEG_SOS_MARKER:
			break
		if offset + 1 >= raw.size():
			break
		var segment_length = _read_u16_big_endian(raw, offset)
		if segment_length < 2:
			break
		var segment_data_start = offset + 2
		var segment_data_length = segment_length - 2
		var segment_data_end = segment_data_start + segment_data_length
		if segment_data_end > raw.size():
			break
		if marker == _JPEG_APP1_MARKER and segment_data_length >= 14:
			var orientation = _parse_exif_orientation_segment(raw, segment_data_start, segment_data_end)
			if orientation >= 1 and orientation <= 8:
				return orientation
		offset = segment_data_end
	return 1

static func apply_orientation_transform(image: Image, orientation: int) -> bool:
	match int(orientation):
		2:
			image.flip_x()
		3:
			image.rotate_180()
		4:
			image.flip_y()
		5:
			image.rotate_90(_ROTATE_CLOCKWISE)
			image.flip_x()
		6:
			image.rotate_90(_ROTATE_CLOCKWISE)
		7:
			image.flip_x()
			image.rotate_90(_ROTATE_CLOCKWISE)
		8:
			image.rotate_90(_ROTATE_COUNTERCLOCKWISE)
		_:
			return false
	return true

static func _parse_exif_orientation_segment(raw: PackedByteArray, segment_start: int, segment_end: int) -> int:
	if segment_end - segment_start < 14:
		return 1
	if raw[segment_start] != 0x45 or raw[segment_start + 1] != 0x78 or raw[segment_start + 2] != 0x69 or raw[segment_start + 3] != 0x66:
		return 1
	if raw[segment_start + 4] != 0x00 or raw[segment_start + 5] != 0x00:
		return 1
	var tiff_start = segment_start + 6
	if tiff_start + 8 > segment_end:
		return 1
	var little_endian = false
	if raw[tiff_start] == 0x49 and raw[tiff_start + 1] == 0x49:
		little_endian = true
	elif raw[tiff_start] == 0x4D and raw[tiff_start + 1] == 0x4D:
		little_endian = false
	else:
		return 1
	var tiff_magic = _read_u16_endian(raw, tiff_start + 2, little_endian)
	if tiff_magic != 0x002A:
		return 1
	var ifd_offset = _read_u32_endian(raw, tiff_start + 4, little_endian)
	var ifd_start = tiff_start + ifd_offset
	if ifd_start + 2 > segment_end:
		return 1
	var entry_count = _read_u16_endian(raw, ifd_start, little_endian)
	var entry_offset = ifd_start + 2
	for i in range(entry_count):
		var current_entry = entry_offset + (i * 12)
		if current_entry + 12 > segment_end:
			break
		var tag = _read_u16_endian(raw, current_entry, little_endian)
		if tag != _EXIF_TAG_ORIENTATION:
			continue
		var value_type = _read_u16_endian(raw, current_entry + 2, little_endian)
		var value_count = _read_u32_endian(raw, current_entry + 4, little_endian)
		if value_count < 1:
			return 1
		if value_type == 3:
			if value_count == 1:
				return _clamp_orientation(_read_u16_endian(raw, current_entry + 8, little_endian))
			var value_offset = _read_u32_endian(raw, current_entry + 8, little_endian)
			var value_pos = tiff_start + value_offset
			if value_pos + 2 > segment_end:
				return 1
			return _clamp_orientation(_read_u16_endian(raw, value_pos, little_endian))
		var generic_offset = _read_u32_endian(raw, current_entry + 8, little_endian)
		var generic_pos = tiff_start + generic_offset
		if generic_pos >= segment_end:
			return 1
		return _clamp_orientation(int(raw[generic_pos]))
	return 1

static func _clamp_orientation(orientation: int) -> int:
	var value = int(orientation)
	if value < 1 or value > 8:
		return 1
	return value

static func _normalize_format_hint(format_hint: String) -> String:
	var normalized = str(format_hint).to_lower().strip_edges()
	if normalized == "jpeg" or normalized == "pjpeg":
		return "jpg"
	return normalized

static func _read_u16_big_endian(raw: PackedByteArray, offset: int) -> int:
	if offset + 1 >= raw.size():
		return 0
	return (int(raw[offset]) << 8) | int(raw[offset + 1])

static func _read_u16_endian(raw: PackedByteArray, offset: int, little_endian: bool) -> int:
	if offset + 1 >= raw.size():
		return 0
	var first_byte = int(raw[offset])
	var second_byte = int(raw[offset + 1])
	if little_endian:
		return first_byte | (second_byte << 8)
	return (first_byte << 8) | second_byte

static func _read_u32_endian(raw: PackedByteArray, offset: int, little_endian: bool) -> int:
	if offset + 3 >= raw.size():
		return 0
	var b0 = int(raw[offset])
	var b1 = int(raw[offset + 1])
	var b2 = int(raw[offset + 2])
	var b3 = int(raw[offset + 3])
	if little_endian:
		return b0 | (b1 << 8) | (b2 << 16) | (b3 << 24)
	return (b0 << 24) | (b1 << 16) | (b2 << 8) | b3
