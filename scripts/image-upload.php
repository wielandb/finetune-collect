<?php

declare(strict_types=1);

$UPLOAD_DIR = __DIR__ . '/uploaded_images';
$SECRET_KEY = 'gaertner';

if (!file_exists($UPLOAD_DIR)) {
	mkdir($UPLOAD_DIR, 0755, true);
}

header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, OPTIONS');
header('Access-Control-Allow-Headers: *');

if (($_SERVER['REQUEST_METHOD'] ?? '') === 'OPTIONS') {
	http_response_code(204);
	exit;
}

function base_url(): string {
	$protocol = (!empty($_SERVER['HTTPS']) && $_SERVER['HTTPS'] !== 'off') ? 'https://' : 'http://';
	return $protocol . ($_SERVER['HTTP_HOST'] ?? 'localhost') . ($_SERVER['SCRIPT_NAME'] ?? '');
}

function respond_text(int $status, string $message): void {
	http_response_code($status);
	header('Content-Type: text/plain; charset=utf-8');
	echo $message;
	exit;
}

function read_request_data(): array {
	$content_type = strtolower(strval($_SERVER['CONTENT_TYPE'] ?? ''));
	$raw_input = file_get_contents('php://input');
	if (strpos($content_type, 'application/json') !== false) {
		if ($raw_input === false || trim($raw_input) === '') {
			respond_text(400, 'invalid JSON request: empty body');
		}
		$decoded = json_decode($raw_input, true);
		if (!is_array($decoded)) {
			respond_text(400, 'invalid JSON request: ' . json_last_error_msg());
		}
		return $decoded;
	}
	if (!empty($_POST)) {
		return $_POST;
	}
	if ($raw_input !== false && trim($raw_input) !== '') {
		$parsed = [];
		parse_str($raw_input, $parsed);
		if (is_array($parsed) && !empty($parsed)) {
			return $parsed;
		}
	}
	return [];
}

$method = $_SERVER['REQUEST_METHOD'] ?? 'GET';

if ($method === 'GET' && array_key_exists('test', $_GET)) {
	$key = strval($_GET['key'] ?? '');
	if ($key === '') {
		respond_text(400, 'missing key parameter');
	}
	if ($key !== $SECRET_KEY) {
		respond_text(403, 'invalid key');
	}
	respond_text(200, 'ok');
}

if ($method === 'GET' && array_key_exists('image', $_GET)) {
	$file = basename(strval($_GET['image']));
	$path = $UPLOAD_DIR . '/' . $file;
	if (!is_file($path)) {
		respond_text(404, 'not found');
	}
	if (function_exists('mime_content_type')) {
		$mime = mime_content_type($path);
	} else if (class_exists('finfo')) {
		$finfo = new finfo(FILEINFO_MIME_TYPE);
		$mime = $finfo->file($path);
	} else {
		$mime = 'application/octet-stream';
	}
	header('Content-Type: ' . $mime);
	header('Content-Disposition: inline; filename="' . $file . '"');
	readfile($path);
	exit;
}

if ($method === 'POST') {
	$data = read_request_data();
	$key = strval($data['key'] ?? '');
	if ($key === '') {
		respond_text(400, 'missing key parameter');
	}
	if ($key !== $SECRET_KEY) {
		respond_text(403, 'invalid key');
	}

	if (array_key_exists('test', $data)) {
		respond_text(200, 'ok');
	}

	$image_b64 = strval($data['image'] ?? '');
	if ($image_b64 === '') {
		respond_text(400, "missing image payload in field 'image'");
	}

	// Accept data URLs and plain base64 payloads.
	if (strpos($image_b64, 'data:') === 0) {
		$comma_pos = strpos($image_b64, ',');
		if ($comma_pos === false) {
			respond_text(400, 'invalid data URL format');
		}
		$image_b64 = substr($image_b64, $comma_pos + 1);
	}

	$img_data = base64_decode($image_b64, true);
	if ($img_data === false) {
		respond_text(400, 'invalid base64 image payload');
	}

	$ext = strtolower(strval($data['ext'] ?? ''));
	if (!in_array($ext, ['jpg', 'jpeg', 'png'], true)) {
		$ext = 'jpg';
	}

	$filename = 'img_' . md5($img_data) . '.' . $ext;
	$write_result = @file_put_contents($UPLOAD_DIR . '/' . $filename, $img_data);
	if ($write_result === false) {
		respond_text(500, 'failed to write image file');
	}

	respond_text(200, base_url() . '?image=' . urlencode($filename));
}

$query_keys = array_keys($_GET);
if (empty($query_keys)) {
	$query_keys_text = '<none>';
} else {
	$query_keys_text = implode(', ', $query_keys);
}
respond_text(
	400,
	'invalid request: expected GET ?test=1&key=..., GET ?image=..., or POST with key+image. ' .
	'method=' . $method . ', query_keys=' . $query_keys_text
);
