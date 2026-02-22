<?php

declare(strict_types=1);

$STORAGE_DIR = __DIR__ . '/stored_projects';
$SECRET_KEY = 'CHANGE_ME';
$MAX_PROJECT_NAME_LENGTH = 120;

if (!file_exists($STORAGE_DIR)) {
	mkdir($STORAGE_DIR, 0755, true);
}

header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, OPTIONS');
header('Access-Control-Allow-Headers: *');
header('Content-Type: application/json; charset=utf-8');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
	http_response_code(204);
	exit;
}

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
	http_response_code(405);
	echo json_encode([
		'ok' => false,
		'error' => 'Method not allowed',
	]);
	exit;
}

function respond(int $status, array $payload): void {
	http_response_code($status);
	echo json_encode($payload, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);
	exit;
}

function sanitize_project_name(string $name, int $max_length): string {
	$name = trim($name);
	if ($name === '') {
		return '';
	}
	if (strlen($name) > $max_length) {
		return '';
	}
	if (!preg_match('/^[A-Za-z0-9._-]+$/', $name)) {
		return '';
	}
	return $name;
}

$raw_input = file_get_contents('php://input');
if ($raw_input === false || trim($raw_input) === '') {
	respond(400, ['ok' => false, 'error' => 'Empty request body']);
}

$data = json_decode($raw_input, true);
if (!is_array($data)) {
	respond(400, ['ok' => false, 'error' => 'Invalid JSON']);
}

$key = strval($data['key'] ?? '');
if ($key === '' || $key !== $SECRET_KEY) {
	respond(403, ['ok' => false, 'error' => 'invalid key']);
}

$action = strval($data['action'] ?? '');
if ($action === '') {
	respond(400, ['ok' => false, 'error' => 'Missing action']);
}

if ($action === 'test') {
	respond(200, ['ok' => true]);
}

$project_name = sanitize_project_name(strval($data['project'] ?? ''), $MAX_PROJECT_NAME_LENGTH);
if ($project_name === '') {
	respond(400, ['ok' => false, 'error' => 'Invalid project name']);
}

$project_path = $STORAGE_DIR . '/' . $project_name . '.json';

if ($action === 'save') {
	if (!array_key_exists('data', $data)) {
		respond(400, ['ok' => false, 'error' => 'Missing data payload']);
	}
	$project_data = $data['data'];
	$encoded = json_encode($project_data, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES | JSON_PRETTY_PRINT);
	if ($encoded === false) {
		respond(400, ['ok' => false, 'error' => 'Data payload is not JSON encodable']);
	}
	$result = @file_put_contents($project_path, $encoded);
	if ($result === false) {
		respond(500, ['ok' => false, 'error' => 'Failed to write project file']);
	}
	respond(200, [
		'ok' => true,
		'project' => $project_name,
		'bytes' => strlen($encoded),
	]);
}

if ($action === 'load') {
	if (!is_file($project_path)) {
		respond(404, ['ok' => false, 'error' => 'Project not found']);
	}
	$stored_content = @file_get_contents($project_path);
	if ($stored_content === false) {
		respond(500, ['ok' => false, 'error' => 'Failed to read project file']);
	}
	$stored_data = json_decode($stored_content, true);
	if (!is_array($stored_data)) {
		respond(500, ['ok' => false, 'error' => 'Stored project file is invalid JSON']);
	}
	respond(200, [
		'ok' => true,
		'project' => $project_name,
		'data' => $stored_data,
	]);
}

respond(400, ['ok' => false, 'error' => 'Unsupported action']);
?>
