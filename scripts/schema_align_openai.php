<?php
declare(strict_types=1);

/**
 * OpenAI Structured Outputs – JSON Schema Normalizer
 *
 * Single-file REST endpoint (POST) that:
 *  - Accepts a JSON body containing either a JSON Schema directly, or an envelope
 *    like { "schema": { ... } } or { "parameters": { ... } }.
 *  - Removes unsupported features AND actively fixes the schema so that it is
 *    valid for OpenAI Structured Outputs:
 *      * Root MUST be an object and MUST NOT use anyOf at the root.
 *        (If needed, wraps the input under { type: "object", properties: { value: <schema> }, required: ["value"], additionalProperties: false }).
 *      * Every object MUST have additionalProperties: false (overrides true or schema-valued forms).
 *      * For every object with "properties", ALL fields MUST be in "required" (required = keys(properties)).
 *      * Only the supported subset of JSON Schema is kept.
 *
 * Supported subset (allowlist):
 *  - Core: type, properties, required, items, anyOf, enum, const, $ref, $defs (and legacy "definitions" -> normalized to $defs), description
 *  - Strings: pattern, format (only: date-time, time, date, duration, email, hostname, ipv4, ipv6, uuid)
 *  - Numbers: multipleOf, maximum, exclusiveMaximum, minimum, exclusiveMinimum
 *  - Arrays: minItems, maxItems
 *
 * Removed (examples):
 *  - allOf, oneOf, not, if, then, else, dependentRequired, dependentSchemas
 *  - patternProperties, propertyNames, unevaluatedProperties, additionalItems, contains
 *  - uniqueItems, prefixItems, minContains, maxContains, unevaluatedItems
 *  - minLength, maxLength, default, examples, deprecated, readOnly, writeOnly, contentEncoding, contentMediaType
 *
 * Notes:
 *  - Arrays/unions in "type" are allowed (e.g., ["string","null"]). For objects we still enforce additionalProperties:false
 *    and required = keys(properties) if "properties" is present.
 *  - anyOf is allowed only inside the schema (e.g., for a property). It is NOT allowed at the root.
 *  - Envelopes (e.g., {"name":"...","strict":true,"schema":{...}}) are preserved; only the schema-bearing keys are normalized.
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
    echo json_encode(['error' => 'Method Not Allowed. Use POST with a JSON body.'], JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);
    exit;
}

$raw = file_get_contents('php://input');
if ($raw === false || $raw === '') {
    http_response_code(400);
    echo json_encode(['error' => 'Empty request body. Expecting JSON.'], JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);
    exit;
}

$input = json_decode($raw, true);
if (json_last_error() !== JSON_ERROR_NONE) {
    http_response_code(400);
    echo json_encode(['error' => 'Invalid JSON: ' . json_last_error_msg()], JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);
    exit;
}

/** Helpers */
function is_assoc_array($arr): bool {
    if (!is_array($arr)) return false;
    return array_keys($arr) !== range(0, count($arr) - 1);
}

function is_schema_like($v): bool {
    if (!is_array($v) || !is_assoc_array($v)) return false;
    $keys = [
        'type','properties','required','items','enum','anyOf','$ref','$defs','definitions',
        'additionalProperties','description','pattern','format',
        'multipleOf','maximum','exclusiveMaximum','minimum','exclusiveMinimum',
        'minItems','maxItems','const'
    ];
    foreach ($keys as $k) {
        if (array_key_exists($k, $v)) return true;
    }
    return false;
}

/**
 * Sanitize and FIX a schema node recursively.
 *
 * @param mixed $node
 * @param bool $isRoot If true, enforce "root is object and no root anyOf".
 * @return mixed
 */
function sanitize_schema($node, bool $isRoot = false) {
    // Non-arrays pass through
    if (!is_array($node)) {
        return $node;
    }

    // Arrays (lists) – sanitize each element if schema-like
    if (!is_assoc_array($node)) {
        $out = [];
        foreach ($node as $item) {
            $out[] = is_schema_like($item) ? sanitize_schema($item, false) : $item;
        }
        return $out;
    }

    // If it's not schema-like, it's probably an envelope-ish object – sanitize nested schema-bearing keys only.
    if (!is_schema_like($node)) {
        $out = $node;
        if (array_key_exists('schema', $out)) {
            $out['schema'] = sanitize_schema($out['schema'], true);
        }
        if (array_key_exists('parameters', $out)) {
            $out['parameters'] = sanitize_schema($out['parameters'], true);
        }
        // Defensive: sometimes schema may appear deeper
        if (isset($out['components']) && is_array($out['components'])) {
            $out['components'] = sanitize_schema($out['components'], false);
        }
        return $out;
    }

    // --- Begin allowlist copy ---
    $allowedStringFormats = ['date-time','time','date','duration','email','hostname','ipv4','ipv6','uuid'];
    $allowedTypes = ['string','number','boolean','integer','object','array','null'];

    $out = [];

    // type
    if (isset($node['type'])) {
        $t = $node['type'];
        if (is_string($t)) {
            if (in_array($t, $allowedTypes, true)) {
                $out['type'] = $t;
            }
        } elseif (is_array($t)) {
            $filtered = [];
            foreach ($t as $tv) {
                if (is_string($tv) && in_array($tv, $allowedTypes, true)) {
                    $filtered[] = $tv;
                }
            }
            $filtered = array_values(array_unique($filtered));
            if (count($filtered) === 1) {
                $out['type'] = $filtered[0];
            } elseif (count($filtered) > 1) {
                $out['type'] = $filtered;
            }
        }
    }

    // description
    if (isset($node['description']) && is_string($node['description'])) {
        $out['description'] = $node['description'];
    }

    // enum
    if (isset($node['enum']) && is_array($node['enum'])) {
        $out['enum'] = array_values($node['enum']);
    }

    // const
    if (array_key_exists('const', $node)) {
        $out['const'] = $node['const'];
    }

    // string keywords
    if (isset($node['pattern']) && (is_string($node['pattern']) || is_numeric($node['pattern']))) {
        $out['pattern'] = (string)$node['pattern'];
    }
    if (isset($node['format']) && is_string($node['format']) && in_array($node['format'], $allowedStringFormats, true)) {
        $out['format'] = $node['format'];
    }

    // number keywords
    foreach (['multipleOf','maximum','exclusiveMaximum','minimum','exclusiveMinimum'] as $nk) {
        if (array_key_exists($nk, $node) && (is_int($node[$nk]) || is_float($node[$nk]))) {
            $out[$nk] = $node[$nk];
        }
    }

    // array keywords
    if (isset($node['minItems']) && is_int($node['minItems']) && $node['minItems'] >= 0) {
        $out['minItems'] = $node['minItems'];
    }
    if (isset($node['maxItems']) && is_int($node['maxItems']) && $node['maxItems'] >= 0) {
        $out['maxItems'] = $node['maxItems'];
    }

    // properties
    if (isset($node['properties']) && is_array($node['properties']) && is_assoc_array($node['properties'])) {
        $propsOut = [];
        foreach ($node['properties'] as $propName => $propSchema) {
            $propsOut[$propName] = sanitize_schema($propSchema, false);
        }
        $out['properties'] = $propsOut;
    }

    // items
    if (isset($node['items'])) {
        if (is_array($node['items'])) {
            $out['items'] = is_assoc_array($node['items'])
                ? sanitize_schema($node['items'], false)
                : array_map(fn($el) => is_schema_like($el) ? sanitize_schema($el, false) : $el, $node['items']);
        }
    }

    // anyOf (allowed for nested schemas, not root)
    if (isset($node['anyOf']) && is_array($node['anyOf'])) {
        $san = [];
        foreach ($node['anyOf'] as $sub) {
            $san[] = sanitize_schema($sub, false);
        }
        $out['anyOf'] = $san;
    }

    // $ref
    if (isset($node['$ref']) && is_string($node['$ref'])) {
        $out['$ref'] = $node['$ref'];
    }

    // $defs / definitions -> $defs
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
    // --- End allowlist copy ---

    // Determine if this node is an object schema
    $isObject =
        (isset($out['type']) && (
            (is_string($out['type']) && $out['type'] === 'object') ||
            (is_array($out['type']) && in_array('object', $out['type'], true))
        ))
        || array_key_exists('properties', $out);

    // Enforce OpenAI requirements for objects
    if ($isObject) {
        // Force additionalProperties:false on ALL objects (override anything else)
        $out['additionalProperties'] = false;

        // If properties exist, ALL fields must be required
        if (isset($out['properties']) && is_array($out['properties'])) {
            $req = array_keys($out['properties']);
            $out['required'] = array_values(array_unique(array_filter($req, fn($s) => is_string($s) && $s !== '')));
        }

        // Make sure type explicitly says "object" when properties exist (helps clarity)
        if (isset($out['properties']) && (!isset($out['type']) || (is_array($out['type']) && !in_array('object', $out['type'], true)))) {
            $out['type'] = 'object';
        }
    } else {
        // Ensure we don't accidentally carry additionalProperties on non-objects
        unset($out['additionalProperties']);
        // "required" only makes sense for objects
        if (!isset($out['properties'])) {
            unset($out['required']);
        }
    }

    // Root-level enforcement:
    if ($isRoot) {
        // Root must be an object and MUST NOT use anyOf at the root level
        $rootIsObject = $isObject;

        // Does root use anyOf directly?
        $rootUsesAnyOf = array_key_exists('anyOf', $out);

        if (!$rootIsObject || $rootUsesAnyOf) {
            // Wrap into an object schema with a single "value" property
            $wrapped = [
                'type' => 'object',
                'properties' => [
                    'value' => $out
                ],
                'required' => ['value'],
                'additionalProperties' => false
            ];
            return $wrapped;
        }
    }

    return $out;
}

/**
 * If the input is an envelope, sanitize schema-bearing keys and ensure a name field.
 * Otherwise, wrap the sanitized schema in an envelope with a name derived from the title.
 */
function sanitize_envelope_or_schema($data) {
    if (is_array($data) && is_assoc_array($data) && !is_schema_like($data)) {
        $out = $data;
        if (array_key_exists('schema', $out)) {
            $schema = $out['schema'];
            if (isset($schema['title']) && is_string($schema['title'])) {
                $out['name'] = $schema['title'];
            } elseif (!array_key_exists('name', $out)) {
                $out['name'] = '';
            }
            $out['schema'] = sanitize_schema($schema, true);
        }
        if (array_key_exists('parameters', $out)) {
            $params = $out['parameters'];
            if (isset($params['title']) && is_string($params['title'])) {
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

$result = sanitize_envelope_or_schema($input);

echo json_encode(
    $result,
    JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES | JSON_PRESERVE_ZERO_FRACTION | JSON_PRETTY_PRINT
);
