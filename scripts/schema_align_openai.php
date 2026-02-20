<?php
declare(strict_types=1);

/**
 * OpenAI Structured Outputs JSON Schema sanitizer and checker.
 *
 * This endpoint:
 * 1. Sanitizes unsupported keywords where safe.
 * 2. Enforces object requirements used by Structured Outputs.
 * 3. Returns `ok=false` with validation errors for hard constraints that
 *    cannot be auto-converted safely (for example enum limits).
 */

header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization, X-Requested-With');
header('Content-Type: application/json; charset=utf-8');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
	http_response_code(204);
	exit;
}

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
	http_response_code(405);
	echo json_encode(
		['error' => 'Method Not Allowed. Use POST with a JSON body.'],
		JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES
	);
	exit;
}

$raw = file_get_contents('php://input');
if ($raw === false || $raw === '') {
	http_response_code(400);
	echo json_encode(
		['error' => 'Empty request body. Expecting JSON.'],
		JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES
	);
	exit;
}

$input = json_decode($raw, true);
if (json_last_error() !== JSON_ERROR_NONE) {
	http_response_code(400);
	echo json_encode(
		['error' => 'Invalid JSON: ' . json_last_error_msg()],
		JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES
	);
	exit;
}

function is_assoc_array($arr): bool {
	if (!is_array($arr)) {
		return false;
	}
	return array_keys($arr) !== range(0, count($arr) - 1);
}

function utf8_len(string $value): int {
	return function_exists('mb_strlen') ? mb_strlen($value, 'UTF-8') : strlen($value);
}

function json_pointer_escape(string $value): string {
	return str_replace(['~', '/'], ['~0', '~1'], $value);
}

function child_path(string $base, string $segment): string {
	$escaped = json_pointer_escape($segment);
	if ($base === '' || $base === '/') {
		return '/' . $escaped;
	}
	return $base . '/' . $escaped;
}

function append_openai_error(array &$errors, string $path, string $code, string $message): void {
	$errors[] = [
		'path' => $path === '' ? '/' : $path,
		'code' => $code,
		'message' => $message,
	];
}

function is_schema_like($v): bool {
	if (!is_array($v) || !is_assoc_array($v)) {
		return false;
	}
	$keys = [
		'type', 'properties', 'required', 'items', 'enum', 'anyOf', '$ref', '$defs', 'definitions',
		'additionalProperties', 'description', 'pattern', 'format',
		'multipleOf', 'maximum', 'exclusiveMaximum', 'minimum', 'exclusiveMinimum',
		'minItems', 'maxItems', 'const'
	];
	foreach ($keys as $k) {
		if (array_key_exists($k, $v)) {
			return true;
		}
	}
	return false;
}

/**
 * Sanitize and fix a schema node recursively.
 *
 * @param mixed $node
 * @param bool $isRoot
 * @return mixed
 */
function sanitize_schema($node, bool $isRoot = false) {
	if (!is_array($node)) {
		return $node;
	}

	if (!is_assoc_array($node)) {
		$out = [];
		foreach ($node as $item) {
			if (is_schema_like($item)) {
				$out[] = sanitize_schema($item, false);
			} else {
				$out[] = $item;
			}
		}
		return $out;
	}

	if (!is_schema_like($node)) {
		$out = $node;
		if (array_key_exists('schema', $out)) {
			$out['schema'] = sanitize_schema($out['schema'], true);
		}
		if (array_key_exists('parameters', $out)) {
			$out['parameters'] = sanitize_schema($out['parameters'], true);
		}
		if (isset($out['components']) && is_array($out['components'])) {
			$out['components'] = sanitize_schema($out['components'], false);
		}
		return $out;
	}

	$allowedStringFormats = ['date-time', 'time', 'date', 'duration', 'email', 'hostname', 'ipv4', 'ipv6', 'uuid'];
	$allowedTypes = ['string', 'number', 'boolean', 'integer', 'object', 'array', 'null'];

	$out = [];

	if (isset($node['type'])) {
		$t = $node['type'];
		if (is_string($t)) {
			if (in_array($t, $allowedTypes, true)) {
				$out['type'] = $t;
			}
		} elseif (is_array($t)) {
			$filtered = [];
			foreach ($t as $tv) {
				if (is_string($tv) && in_array($tv, $allowedTypes, true) && !in_array($tv, $filtered, true)) {
					$filtered[] = $tv;
				}
			}
			if (count($filtered) === 1) {
				$out['type'] = $filtered[0];
			} elseif (count($filtered) > 1) {
				$out['type'] = array_values($filtered);
			}
		}
	}

	if (isset($node['description']) && is_string($node['description'])) {
		$out['description'] = $node['description'];
	}

	if (isset($node['enum']) && is_array($node['enum'])) {
		$out['enum'] = array_values($node['enum']);
	}

	if (array_key_exists('const', $node)) {
		$out['const'] = $node['const'];
	}

	if (isset($node['pattern']) && (is_string($node['pattern']) || is_numeric($node['pattern']))) {
		$out['pattern'] = (string)$node['pattern'];
	}
	if (isset($node['format']) && is_string($node['format']) && in_array($node['format'], $allowedStringFormats, true)) {
		$out['format'] = $node['format'];
	}

	foreach (['multipleOf', 'maximum', 'exclusiveMaximum', 'minimum', 'exclusiveMinimum'] as $nk) {
		if (array_key_exists($nk, $node) && (is_int($node[$nk]) || is_float($node[$nk]))) {
			$out[$nk] = $node[$nk];
		}
	}

	if (isset($node['minItems']) && is_int($node['minItems']) && $node['minItems'] >= 0) {
		$out['minItems'] = $node['minItems'];
	}
	if (isset($node['maxItems']) && is_int($node['maxItems']) && $node['maxItems'] >= 0) {
		$out['maxItems'] = $node['maxItems'];
	}

	if (isset($node['properties']) && is_array($node['properties']) && is_assoc_array($node['properties'])) {
		$propsOut = [];
		foreach ($node['properties'] as $propName => $propSchema) {
			$propsOut[$propName] = sanitize_schema($propSchema, false);
		}
		$out['properties'] = $propsOut;
	}

	if (isset($node['items']) && is_array($node['items'])) {
		if (is_assoc_array($node['items'])) {
			$out['items'] = sanitize_schema($node['items'], false);
		} else {
			$tupleOut = [];
			foreach ($node['items'] as $itemSchema) {
				if (is_schema_like($itemSchema)) {
					$tupleOut[] = sanitize_schema($itemSchema, false);
				} else {
					$tupleOut[] = $itemSchema;
				}
			}
			$out['items'] = $tupleOut;
		}
	}

	if (isset($node['anyOf']) && is_array($node['anyOf'])) {
		$anyOf = [];
		foreach ($node['anyOf'] as $sub) {
			$anyOf[] = sanitize_schema($sub, false);
		}
		$out['anyOf'] = $anyOf;
	}

	if (isset($node['$ref']) && is_string($node['$ref'])) {
		$out['$ref'] = $node['$ref'];
	}

	$defs = [];
	if (isset($node['$defs']) && is_array($node['$defs']) && is_assoc_array($node['$defs'])) {
		foreach ($node['$defs'] as $k => $v) {
			$defs[$k] = sanitize_schema($v, false);
		}
	}
	if (isset($node['definitions']) && is_array($node['definitions']) && is_assoc_array($node['definitions'])) {
		foreach ($node['definitions'] as $k => $v) {
			$defs[$k] = sanitize_schema($v, false);
		}
	}
	if (!empty($defs)) {
		$out['$defs'] = $defs;
	}

	$isObject =
		(isset($out['type']) && (
			(is_string($out['type']) && $out['type'] === 'object') ||
			(is_array($out['type']) && in_array('object', $out['type'], true))
		))
		|| array_key_exists('properties', $out);

	if ($isObject) {
		$out['additionalProperties'] = false;
		if (isset($out['properties']) && is_array($out['properties'])) {
			$req = [];
			foreach (array_keys($out['properties']) as $k) {
				if (is_string($k) && $k !== '') {
					$req[] = $k;
				}
			}
			$out['required'] = array_values(array_unique($req));
		}
		if (isset($out['properties']) && (!isset($out['type']) || (is_array($out['type']) && !in_array('object', $out['type'], true)))) {
			$out['type'] = 'object';
		}
	} else {
		unset($out['additionalProperties']);
		if (!isset($out['properties'])) {
			unset($out['required']);
		}
	}

	if ($isRoot) {
		$rootIsObject = $isObject;
		$rootUsesAnyOf = array_key_exists('anyOf', $out);
		if (!$rootIsObject || $rootUsesAnyOf) {
			return [
				'type' => 'object',
				'properties' => ['value' => $out],
				'required' => ['value'],
				'additionalProperties' => false,
			];
		}
	}

	return $out;
}

/**
 * If input is an envelope, sanitize schema-bearing keys and keep metadata.
 * Otherwise return {name, schema}.
 *
 * @param mixed $data
 * @return array<string,mixed>
 */
function sanitize_envelope_or_schema($data): array {
	if (is_array($data) && is_assoc_array($data) && !is_schema_like($data)) {
		$out = $data;
		if (array_key_exists('schema', $out)) {
			$schema = $out['schema'];
			if (is_array($schema) && isset($schema['title']) && is_string($schema['title'])) {
				$out['name'] = $schema['title'];
			} elseif (!array_key_exists('name', $out)) {
				$out['name'] = '';
			}
			$out['schema'] = sanitize_schema($schema, true);
		}
		if (array_key_exists('parameters', $out)) {
			$params = $out['parameters'];
			if (is_array($params) && isset($params['title']) && is_string($params['title'])) {
				$out['name'] = $params['title'];
			} elseif (!array_key_exists('name', $out)) {
				$out['name'] = '';
			}
			$out['parameters'] = sanitize_schema($params, true);
		}
		if (!array_key_exists('name', $out)) {
			$out['name'] = '';
		}
		return $out;
	}

	$name = '';
	if (is_array($data) && isset($data['title']) && is_string($data['title'])) {
		$name = $data['title'];
	}
	$sanitized = sanitize_schema($data, true);
	return ['name' => $name, 'schema' => $sanitized];
}

/**
 * @param mixed $schema
 * @param string $basePath
 * @param array<int,array<string,mixed>> $errors
 */
function validate_sanitized_schema($schema, string $basePath, array &$errors): void {
	if (!is_array($schema) || !is_assoc_array($schema)) {
		append_openai_error($errors, $basePath, 'schema_type', 'Schema must be a JSON object');
		return;
	}

	$state = [
		'propertyCount' => 0,
		'enumCount' => 0,
		'stringBudget' => 0,
	];

	collect_limits($schema, $basePath, 1, $errors, $state);

	if ($state['propertyCount'] > 5000) {
		append_openai_error(
			$errors,
			$basePath,
			'too_many_properties',
			'Schema has ' . $state['propertyCount'] . ' properties, max is 5000'
		);
	}
	if ($state['enumCount'] > 1000) {
		append_openai_error(
			$errors,
			$basePath,
			'too_many_enum_values',
			'Schema has ' . $state['enumCount'] . ' enum values, max is 1000'
		);
	}
	if ($state['stringBudget'] > 120000) {
		append_openai_error(
			$errors,
			$basePath,
			'string_budget_exceeded',
			'Schema string budget is ' . $state['stringBudget'] . ', max is 120000'
		);
	}
}

/**
 * @param array<string,mixed> $node
 * @param string $path
 * @param int $depth
 * @param array<int,array<string,mixed>> $errors
 * @param array<string,int> $state
 */
function collect_limits(array $node, string $path, int $depth, array &$errors, array &$state): void {
	if ($depth > 10) {
		append_openai_error($errors, $path, 'nesting_depth_exceeded', 'Schema nesting depth exceeds 10');
		return;
	}

	if (isset($node['$ref']) && is_string($node['$ref']) && strpos($node['$ref'], '#') !== 0) {
		append_openai_error(
			$errors,
			child_path($path, '$ref'),
			'external_ref_not_supported',
			'Only local $ref values starting with # are supported'
		);
	}

	if (isset($node['properties']) && is_array($node['properties']) && is_assoc_array($node['properties'])) {
		$state['propertyCount'] += count($node['properties']);
		foreach ($node['properties'] as $propName => $propSchema) {
			if (is_string($propName)) {
				$state['stringBudget'] += utf8_len($propName);
			}
			if (is_array($propSchema) && is_assoc_array($propSchema)) {
				$child = child_path(child_path($path, 'properties'), (string)$propName);
				collect_limits($propSchema, $child, $depth + 1, $errors, $state);
			}
		}
	}

	$defs = [];
	if (isset($node['$defs']) && is_array($node['$defs']) && is_assoc_array($node['$defs'])) {
		$defs = $node['$defs'];
	} elseif (isset($node['definitions']) && is_array($node['definitions']) && is_assoc_array($node['definitions'])) {
		$defs = $node['definitions'];
	}
	foreach ($defs as $defName => $defSchema) {
		if (is_string($defName)) {
			$state['stringBudget'] += utf8_len($defName);
		}
		if (is_array($defSchema) && is_assoc_array($defSchema)) {
			$child = child_path(child_path($path, '$defs'), (string)$defName);
			collect_limits($defSchema, $child, $depth + 1, $errors, $state);
		}
	}

	if (isset($node['enum']) && is_array($node['enum'])) {
		$enum = $node['enum'];
		$state['enumCount'] += count($enum);

		$allStrings = count($enum) > 0;
		$enumStringBudget = 0;
		foreach ($enum as $enumValue) {
			if (is_string($enumValue)) {
				$length = utf8_len($enumValue);
				$enumStringBudget += $length;
				$state['stringBudget'] += $length;
			} else {
				$allStrings = false;
			}
		}

		if ($allStrings && count($enum) > 250 && $enumStringBudget > 15000) {
			append_openai_error(
				$errors,
				child_path($path, 'enum'),
				'enum_string_budget_exceeded',
				'Enum string budget is ' . $enumStringBudget . ' for ' . count($enum) . ' values, max is 15000 when enum has more than 250 values'
			);
		}
	}

	if (array_key_exists('const', $node) && is_string($node['const'])) {
		$state['stringBudget'] += utf8_len($node['const']);
	}

	if (isset($node['items'])) {
		if (is_array($node['items']) && is_assoc_array($node['items'])) {
			collect_limits($node['items'], child_path($path, 'items'), $depth + 1, $errors, $state);
		} elseif (is_array($node['items'])) {
			foreach ($node['items'] as $idx => $tupleSchema) {
				if (is_array($tupleSchema) && is_assoc_array($tupleSchema)) {
					$child = child_path(child_path($path, 'items'), (string)$idx);
					collect_limits($tupleSchema, $child, $depth + 1, $errors, $state);
				}
			}
		}
	}

	if (isset($node['anyOf']) && is_array($node['anyOf'])) {
		foreach ($node['anyOf'] as $idx => $branch) {
			if (is_array($branch) && is_assoc_array($branch)) {
				$child = child_path(child_path($path, 'anyOf'), (string)$idx);
				collect_limits($branch, $child, $depth + 1, $errors, $state);
			}
		}
	}
}

/**
 * @param mixed $data
 * @return array{ok:bool,result:array<string,mixed>,errors:array<int,array<string,mixed>>}
 */
function sanitize_envelope_or_schema_with_report($data): array {
	$result = sanitize_envelope_or_schema($data);
	$errors = [];

	if (array_key_exists('schema', $result)) {
		validate_sanitized_schema($result['schema'], '/schema', $errors);
	}
	if (array_key_exists('parameters', $result)) {
		validate_sanitized_schema($result['parameters'], '/parameters', $errors);
	}
	if (!array_key_exists('schema', $result) && !array_key_exists('parameters', $result)) {
		append_openai_error($errors, '/', 'missing_schema', 'Missing schema or parameters object');
	}

	return [
		'ok' => empty($errors),
		'result' => $result,
		'errors' => $errors,
	];
}

$report = sanitize_envelope_or_schema_with_report($input);
$response = $report['result'];
$response['ok'] = $report['ok'];
$response['errors'] = $report['errors'];

echo json_encode(
	$response,
	JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES | JSON_PRESERVE_ZERO_FRACTION | JSON_PRETTY_PRINT
);
