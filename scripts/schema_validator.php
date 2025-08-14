<?php
declare(strict_types=1);

/**
 * Mini JSON Schema Validator – Single File, No Dependencies
 * ---------------------------------------------------------
 * Jetzt zusätzlich als einfache REST-API verwendbar.
 *
 * Unterstützt (draft-07 / 2020-12 Überschneidung, Kernumfang):
 *  - type, enum, const
 *  - properties, required, additionalProperties, patternProperties, propertyNames,
 *    minProperties, maxProperties
 *  - items (Schema oder Tupel), additionalItems, minItems, maxItems, uniqueItems, contains
 *  - minimum, maximum, exclusiveMinimum, exclusiveMaximum, multipleOf
 *  - minLength, maxLength, pattern, format (email, uri, ipv4, ipv6, date, time, date-time, uuid, hostname)
 *  - allOf, anyOf, oneOf, not
 *  - if / then / else
 *  - dependencies, dependentRequired, dependentSchemas
 *  - $ref (nur intern "#/..."), $defs / definitions
 *
 * REST-API (POST):
 *  - Endpoint: dieselbe Datei via Webserver aufrufen (z. B. PHP-Built-in: php -S 0.0.0.0:8000 validator.php)
 *  - Content-Type: application/json
 *  - Body (Variante 1: Instanz gegen Schema validieren):
 *      {
 *        "action": "validate",
 *        "schema": { ...JSON Schema... },
 *        "data":   { ...JSON Instanz... }
 *      }
 *    Antwort:
 *      { "ok": true/false, "phase": "instance", "errors": [ ... ] }
 *    Wenn das Schema ungültig ist:
 *      { "ok": false, "phase": "schema", "errors": [ ... ] }
 *
 *  - Body (Variante 2: Schema prüfen):
 *      {
 *        "action": "validateSchema",
 *        "schema": { ...JSON Schema... }
 *      }
 *    Antwort:
 *      { "ok": true/false, "phase": "schema", "errors": [ ... ] }
 *
 *  - Fehlerhafte Anfragen erhalten Status 400/405 mit:
 *      { "ok": false, "error": { "code": "bad_request", "message": "..." } }
 *
 * CORS:
 *  - OPTIONS wird beantwortet.
 *  - Access-Control-Allow-Origin: *
 *
 * CLI (optional weiterhin möglich):
 *   php validator.php --validate-schema schema.json
 *   php validator.php --schema schema.json --validate data.json
 *   (statt Datei '-' für STDIN)
 */

final class JsonSchemaValidator
{
    /** @var array<string,bool> */
    private $supportedKeywords = [
        // core
        '$ref' => true, '$defs' => true, 'definitions' => true,
        // types & enums
        'type' => true, 'enum' => true, 'const' => true,
        // object
        'properties' => true, 'required' => true, 'additionalProperties' => true,
        'patternProperties' => true, 'propertyNames' => true,
        'minProperties' => true, 'maxProperties' => true,
        // array
        'items' => true, 'additionalItems' => true, 'minItems' => true,
        'maxItems' => true, 'uniqueItems' => true, 'contains' => true,
        // number
        'minimum' => true, 'maximum' => true, 'exclusiveMinimum' => true,
        'exclusiveMaximum' => true, 'multipleOf' => true,
        // string
        'minLength' => true, 'maxLength' => true, 'pattern' => true, 'format' => true,
        // combinators
        'allOf' => true, 'anyOf' => true, 'oneOf' => true, 'not' => true,
        // conditionals
        'if' => true, 'then' => true, 'else' => true,
        // dependencies (draft-07) & 2020-12 style
        'dependencies' => true, 'dependentRequired' => true, 'dependentSchemas' => true,
        // annotations (ignored at runtime, accepted in schema)
        'title' => true, 'description' => true, 'default' => true, 'examples' => true,
        'readOnly' => true, 'writeOnly' => true,
        // permissive extensions used by upstream tools
        'template' => true, 'watch' => true, 'options' => true,
        // $id/$schema metadata allowed (ignored)
        '$id' => true, '$schema' => true,
    ];

    /** @var array<string,mixed> */
    private $rootSchema = [];

    /** @var int */
    private $maxDepth = 256;

    /**
     * Validate JSON data against a schema.
     * @param mixed $data
     * @param array $schema decoded JSON (associative arrays for objects)
     * @return array{0:bool,1:array<int,array<string,mixed>>} [isValid, errors]
     */
    public function validate($data, array $schema): array
    {
        $this->rootSchema = $schema;
        $errors = [];
        $this->check($data, $schema, '', $errors, 0);
        return [count($errors) === 0, $errors];
    }

    /**
     * Validate the schema itself (structure + supported keywords + $ref resolvable).
     * @param array $schema
     * @return array{0:bool,1:array<int,array<string,mixed>>}
     */
    public function validateSchema(array $schema): array
    {
        $this->rootSchema = $schema;
        $errors = [];
        $this->checkSchemaNode($schema, '', $errors, 0);
        $this->checkAllRefsResolvable($schema, '', $errors);
        return [count($errors) === 0, $errors];
    }

    // ------------------------ Core instance validation ------------------------

    /**
     * @param mixed $data
     * @param array $schema
     * @param string $path JSON Pointer path ('' for root)
     * @param array<int,array<string,mixed>> $errors
     */
    private function check($data, array $schema, string $path, array &$errors, int $depth): void
    {
        if ($depth > $this->maxDepth) {
            $this->err($errors, $path, 'depth', 'Maximum validation depth exceeded.');
            return;
        }

        // $ref (internal only)
        if (isset($schema['$ref']) && is_string($schema['$ref'])) {
            $ref = $schema['$ref'];
            $refSchema = $this->resolveRef($ref);
            if ($refSchema === null) {
                $this->err($errors, $path, '$ref', "Unresolvable \$ref: {$ref}");
                return;
            }
            $siblings = $schema;
            unset($siblings['$ref']);
            if (!empty($siblings)) {
                $schema = ['allOf' => [$refSchema, $siblings]];
            } else {
                $schema = $refSchema;
            }
        }

        // combinators
        if (isset($schema['allOf']) && is_array($schema['allOf'])) {
            foreach ($schema['allOf'] as $i => $sub) {
                if (!is_array($sub)) {
                    $this->err($errors, $path, 'allOf', "Subschema at index {$i} must be an object.");
                    continue;
                }
                $this->check($data, $sub, $path, $errors, $depth + 1);
            }
        }

        if (isset($schema['anyOf']) && is_array($schema['anyOf'])) {
            $ok = false;
            foreach ($schema['anyOf'] as $i => $sub) {
                if (!is_array($sub)) { continue; }
                [$valid, ] = $this->validate($data, $sub);
                if ($valid) { $ok = true; break; }
            }
            if (!$ok) {
                $this->err($errors, $path, 'anyOf', 'No subschema matched.');
            }
        }

        if (isset($schema['oneOf']) && is_array($schema['oneOf'])) {
            $matches = 0;
            foreach ($schema['oneOf'] as $sub) {
                if (!is_array($sub)) { continue; }
                [$valid, ] = $this->validate($data, $sub);
                if ($valid) { $matches++; }
                if ($matches > 1) { break; }
            }
            if ($matches !== 1) {
                $this->err($errors, $path, 'oneOf', "Exactly one subschema must match; got {$matches}.");
            }
        }

        if (isset($schema['not']) && is_array($schema['not'])) {
            [$valid, ] = $this->validate($data, $schema['not']);
            if ($valid) {
                $this->err($errors, $path, 'not', 'Subschema in "not" matched but must not.');
            }
        }

        // conditional
        if (isset($schema['if']) && is_array($schema['if'])) {
            [$cond, ] = $this->validate($data, $schema['if']);
            if ($cond) {
                if (isset($schema['then']) && is_array($schema['then'])) {
                    $this->check($data, $schema['then'], $path, $errors, $depth + 1);
                }
            } else {
                if (isset($schema['else']) && is_array($schema['else'])) {
                    $this->check($data, $schema['else'], $path, $errors, $depth + 1);
                }
            }
        }

        // type
        if (isset($schema['type'])) {
            $types = $schema['type'];
            $typeOk = false;
            if (is_string($types)) {
                $typeOk = $this->matchesType($data, $types);
            } elseif (is_array($types)) {
                foreach ($types as $t) {
                    if (is_string($t) && $this->matchesType($data, $t)) { $typeOk = true; break; }
                }
            }
            if (!$typeOk) {
                $this->err($errors, $path, 'type', 'Type mismatch.');
            }
        }

        // enum / const
        if (array_key_exists('const', $schema)) {
            if (!$this->deepEquals($data, $schema['const'])) {
                $this->err($errors, $path, 'const', 'Value must equal the specified constant.');
            }
        }
        if (isset($schema['enum']) && is_array($schema['enum'])) {
            $found = false;
            foreach ($schema['enum'] as $val) {
                if ($this->deepEquals($data, $val)) { $found = true; break; }
            }
            if (!$found) {
                $this->err($errors, $path, 'enum', 'Value not in enum.');
            }
        }

        // Per-type constraints
        $type = $this->typeOf($data);

        if ($type === 'string') {
            $len = $this->strlen($data);
            if (isset($schema['minLength']) && is_int($schema['minLength']) && $len < $schema['minLength']) {
                $this->err($errors, $path, 'minLength', "String is shorter than {$schema['minLength']}.");
            }
            if (isset($schema['maxLength']) && is_int($schema['maxLength']) && $len > $schema['maxLength']) {
                $this->err($errors, $path, 'maxLength', "String is longer than {$schema['maxLength']}.");
            }
            if (isset($schema['pattern']) && is_string($schema['pattern'])) {
                if (!$this->pregIsValid($schema['pattern']) || !preg_match($this->wrapRegex($schema['pattern']), $data)) {
                    $this->err($errors, $path, 'pattern', 'String does not match required pattern.');
                }
            }
            if (isset($schema['format']) && is_string($schema['format'])) {
                if (!$this->checkFormat($schema['format'], $data)) {
                    $this->err($errors, $path, 'format', "String does not match format '{$schema['format']}'.");
                }
            }
        }
        elseif ($type === 'number' || $type === 'integer') {
            $num = (float)$data;
            if (isset($schema['minimum']) && is_numeric($schema['minimum']) && $num < (float)$schema['minimum']) {
                if (($schema['exclusiveMinimum'] ?? false) === true && $num == (float)$schema['minimum']) {
                    $this->err($errors, $path, 'exclusiveMinimum', 'Number must be > minimum.');
                } else {
                    $this->err($errors, $path, 'minimum', 'Number is less than minimum.');
                }
            }
            if (isset($schema['maximum']) && is_numeric($schema['maximum']) && $num > (float)$schema['maximum']) {
                if (($schema['exclusiveMaximum'] ?? false) === true && $num == (float)$schema['maximum']) {
                    $this->err($errors, $path, 'exclusiveMaximum', 'Number must be < maximum.');
                } else {
                    $this->err($errors, $path, 'maximum', 'Number is greater than maximum.');
                }
            }
            if (isset($schema['exclusiveMinimum']) && is_numeric($schema['exclusiveMinimum']) && $num <= (float)$schema['exclusiveMinimum']) {
                $this->err($errors, $path, 'exclusiveMinimum', 'Number must be greater than exclusiveMinimum.');
            }
            if (isset($schema['exclusiveMaximum']) && is_numeric($schema['exclusiveMaximum']) && $num >= (float)$schema['exclusiveMaximum']) {
                $this->err($errors, $path, 'exclusiveMaximum', 'Number must be less than exclusiveMaximum.');
            }
            if (isset($schema['multipleOf']) && is_numeric($schema['multipleOf'])) {
                $div = (float)$schema['multipleOf'];
                if ($div <= 0.0) {
                    $this->err($errors, $path, 'multipleOf', 'multipleOf must be > 0.');
                } else {
                    $rem = fmod(abs($num), $div);
                    $eps = 1e-12;
                    if (!($rem < $eps || abs($rem - $div) < $eps)) {
                        $this->err($errors, $path, 'multipleOf', "Number is not a multiple of {$div}.");
                    }
                }
            }
        }
        elseif ($type === 'array') {
            /** @var array<int,mixed> $data */
            $count = count($data);
            if (isset($schema['minItems']) && is_int($schema['minItems']) && $count < $schema['minItems']) {
                $this->err($errors, $path, 'minItems', "Array has fewer than {$schema['minItems']} items.");
            }
            if (isset($schema['maxItems']) && is_int($schema['maxItems']) && $count > $schema['maxItems']) {
                $this->err($errors, $path, 'maxItems', "Array has more than {$schema['maxItems']} items.");
            }
            if (!empty($schema['uniqueItems'])) {
                $seen = [];
                foreach ($data as $i => $item) {
                    $k = json_encode($item, JSON_UNESCAPED_UNICODE|JSON_UNESCAPED_SLASHES|JSON_PRESERVE_ZERO_FRACTION);
                    if (isset($seen[$k])) {
                        $this->err($errors, $path.'/'.$i, 'uniqueItems', 'Array items must be unique.');
                        break;
                    }
                    $seen[$k] = true;
                }
            }
            if (isset($schema['items'])) {
                if (is_array($schema['items']) && $this->isAssoc($schema['items'])) {
                    foreach ($data as $i => $item) {
                        $this->check($item, $schema['items'], $path.'/'.$i, $errors, $depth + 1);
                    }
                } elseif (is_array($schema['items'])) {
                    $tupleSchemas = $schema['items'];
                    foreach ($tupleSchemas as $i => $sub) {
                        if (array_key_exists($i, $data)) {
                            if (!is_array($sub)) {
                                $this->err($errors, $path, 'items', "Tuple schema at index {$i} must be an object.");
                            } else {
                                $this->check($data[$i], $sub, $path.'/'.$i, $errors, $depth + 1);
                            }
                        }
                    }
                    if (isset($schema['additionalItems'])) {
                        if ($schema['additionalItems'] === false) {
                            if ($count > count($tupleSchemas)) {
                                for ($i = count($tupleSchemas); $i < $count; $i++) {
                                    $this->err($errors, $path.'/'.$i, 'additionalItems', 'Additional items are not allowed.');
                                }
                            }
                        } elseif (is_array($schema['additionalItems'])) {
                            for ($i = count($tupleSchemas); $i < $count; $i++) {
                                $this->check($data[$i], $schema['additionalItems'], $path.'/'.$i, $errors, $depth + 1);
                            }
                        }
                    }
                }
            }
            if (isset($schema['contains']) && is_array($schema['contains'])) {
                $ok = false;
                foreach ($data as $item) {
                    [$valid, ] = $this->validate($item, $schema['contains']);
                    if ($valid) { $ok = true; break; }
                }
                if (!$ok) {
                    $this->err($errors, $path, 'contains', 'Array must contain at least one item matching "contains".');
                }
            }
        }
        elseif ($type === 'object') {
            /** @var array<string,mixed> $data */
            $propCount = count($data);
            if (isset($schema['minProperties']) && is_int($schema['minProperties']) && $propCount < $schema['minProperties']) {
                $this->err($errors, $path, 'minProperties', "Object has fewer than {$schema['minProperties']} properties.");
            }
            if (isset($schema['maxProperties']) && is_int($schema['maxProperties']) && $propCount > $schema['maxProperties']) {
                $this->err($errors, $path, 'maxProperties', "Object has more than {$schema['maxProperties']} properties.");
            }

            if (isset($schema['required']) && is_array($schema['required'])) {
                foreach ($schema['required'] as $req) {
                    if (is_string($req) && !array_key_exists($req, $data)) {
                        $this->err($errors, $path, 'required', "Required property '{$req}' is missing.");
                    }
                }
            }

            if (isset($schema['propertyNames']) && is_array($schema['propertyNames'])) {
                foreach (array_keys($data) as $propName) {
                    $this->check($propName, $schema['propertyNames'], $path.'/'.self::escape($propName), $errors, $depth + 1);
                }
            }

            $ap = $schema['additionalProperties'] ?? true;
            $props = isset($schema['properties']) && is_array($schema['properties']) ? $schema['properties'] : [];
            $pProps = isset($schema['patternProperties']) && is_array($schema['patternProperties']) ? $schema['patternProperties'] : [];

            foreach ($data as $k => $v) {
                $matched = false;

                if (isset($props[$k]) && is_array($props[$k])) {
                    $this->check($v, $props[$k], $path.'/'.self::escape($k), $errors, $depth + 1);
                    $matched = true;
                }

                if (!$matched && !empty($pProps)) {
                    foreach ($pProps as $pat => $subschema) {
                        if (!is_array($subschema)) { continue; }
                        if ($this->pregIsValid($pat) && preg_match($this->wrapRegex($pat), $k)) {
                            $this->check($v, $subschema, $path.'/'.self::escape($k), $errors, $depth + 1);
                            $matched = true;
                        }
                    }
                }

                if (!$matched) {
                    if ($ap === false) {
                        $this->err($errors, $path.'/'.self::escape($k), 'additionalProperties', "Additional property '{$k}' is not allowed.");
                    } elseif (is_array($ap)) {
                        $this->check($v, $ap, $path.'/'.self::escape($k), $errors, $depth + 1);
                    }
                }
            }

            if (isset($schema['dependencies']) && is_array($schema['dependencies'])) {
                foreach ($schema['dependencies'] as $prop => $dep) {
                    if (!array_key_exists($prop, $data)) { continue; }
                    if (is_array($dep) && !$this->isAssoc($dep)) {
                        foreach ($dep as $need) {
                            if (is_string($need) && !array_key_exists($need, $data)) {
                                $this->err($errors, $path, 'dependencies', "Property '{$prop}' requires '{$need}'.");
                            }
                        }
                    } elseif (is_array($dep)) {
                        $this->check($data, $dep, $path, $errors, $depth + 1);
                    } elseif (is_string($dep)) {
                        if (!array_key_exists($dep, $data)) {
                            $this->err($errors, $path, 'dependencies', "Property '{$prop}' requires '{$dep}'.");
                        }
                    }
                }
            }

            if (isset($schema['dependentRequired']) && is_array($schema['dependentRequired'])) {
                foreach ($schema['dependentRequired'] as $prop => $needs) {
                    if (!array_key_exists($prop, $data)) { continue; }
                    if (is_array($needs)) {
                        foreach ($needs as $need) {
                            if (is_string($need) && !array_key_exists($need, $data)) {
                                $this->err($errors, $path, 'dependentRequired', "Property '{$prop}' requires '{$need}'.");
                            }
                        }
                    }
                }
            }

            if (isset($schema['dependentSchemas']) && is_array($schema['dependentSchemas'])) {
                foreach ($schema['dependentSchemas'] as $prop => $sub) {
                    if (!array_key_exists($prop, $data)) { continue; }
                    if (is_array($sub)) {
                        $this->check($data, $sub, $path, $errors, $depth + 1);
                    }
                }
            }
        }
    }

    // ------------------------ Schema validation (structure) ------------------------

    /**
     * @param array $schema
     * @param string $path
     * @param array<int,array<string,mixed>> $errors
     */
    private function checkSchemaNode(array $schema, string $path, array &$errors, int $depth): void
    {
        if ($depth > $this->maxDepth) {
            $this->err($errors, $path, 'schema-depth', 'Maximum schema depth exceeded.');
            return;
        }

        // Only allow supported keywords (annotations & $id/$schema accepted)
        foreach ($schema as $k => $v) {
            if (!isset($this->supportedKeywords[$k])) {
                $this->err($errors, $path, 'unsupported', "Unsupported keyword '{$k}' (will be ignored at runtime).");
            }
        }

        // type
        if (isset($schema['type'])) {
            $t = $schema['type'];
            $valid = false;
            $allowed = ['null','boolean','object','array','number','integer','string'];
            if (is_string($t)) { $valid = in_array($t, $allowed, true); }
            elseif (is_array($t)) {
                $valid = count($t) > 0;
                foreach ($t as $tt) {
                    if (!is_string($tt) || !in_array($tt, $allowed, true)) { $valid = false; break; }
                }
            }
            if (!$valid) { $this->err($errors, $path, 'type', 'Invalid "type" value.'); }
        }

        // enum
        if (isset($schema['enum']) && !is_array($schema['enum'])) {
            $this->err($errors, $path, 'enum', '"enum" must be an array.');
        }

        // number constraints
        foreach (['minimum','maximum','exclusiveMinimum','exclusiveMaximum','multipleOf'] as $numKey) {
            if (isset($schema[$numKey]) && !is_numeric($schema[$numKey])) {
                if (is_bool($schema[$numKey]) && ($numKey === 'exclusiveMinimum' || $numKey === 'exclusiveMaximum')) {
                    // allow boolean (draft-04 style)
                } else {
                    $this->err($errors, $path, $numKey, "\"{$numKey}\" must be a number.");
                }
            }
        }

        // string constraints
        foreach (['minLength','maxLength'] as $key) {
            if (array_key_exists($key, $schema)) {
                $v = $schema[$key];
                $valid = false;
                if (is_int($v) && $v >= 0) {
                    $valid = true;
                } elseif (is_float($v) && $v >= 0 && floor($v) == $v) {
                    $valid = true;
                } elseif (is_string($v) && ctype_digit($v)) {
                    $valid = true;
                }
                if (!$valid) {
                    $this->err($errors, $path, $key, "\"{$key}\" must be a non-negative integer.");
                }
            }
        }
        if (isset($schema['pattern']) && !(is_string($schema['pattern']) && $this->pregIsValid($schema['pattern']))) {
            $this->err($errors, $path, 'pattern', '"pattern" must be a valid regex string.');
        }
        if (isset($schema['format']) && !is_string($schema['format'])) {
            $this->err($errors, $path, 'format', '"format" must be a string.');
        }

        // array constraints
        foreach (['minItems','maxItems'] as $key) {
            if (isset($schema[$key]) && !(is_int($schema[$key]) && $schema[$key] >= 0)) {
                $this->err($errors, $path, $key, "\"{$key}\" must be a non-negative integer.");
            }
        }
        if (isset($schema['uniqueItems']) && !is_bool($schema['uniqueItems'])) {
            $this->err($errors, $path, 'uniqueItems', '"uniqueItems" must be boolean.');
        }
        if (isset($schema['items'])) {
            if (is_array($schema['items']) && $this->isAssoc($schema['items'])) {
                $this->checkSchemaNode($schema['items'], $path.'/items', $errors, $depth + 1);
            } elseif (is_array($schema['items'])) {
                foreach ($schema['items'] as $i => $sub) {
                    if (!is_array($sub)) {
                        $this->err($errors, $path.'/items/'.$i, 'items', 'Tuple items must be schema objects.');
                    } else {
                        $this->checkSchemaNode($sub, $path.'/items/'.$i, $errors, $depth + 1);
                    }
                }
            } else {
                $this->err($errors, $path.'/items', 'items', '"items" must be an object or an array of objects.');
            }
        }
        if (isset($schema['additionalItems']) && !is_bool($schema['additionalItems']) && !is_array($schema['additionalItems'])) {
            $this->err($errors, $path, 'additionalItems', '"additionalItems" must be boolean or schema.');
        }
        if (isset($schema['contains']) && is_array($schema['contains'])) {
            $this->checkSchemaNode($schema['contains'], $path.'/contains', $errors, $depth + 1);
        } elseif (isset($schema['contains'])) {
            $this->err($errors, $path.'/contains', 'contains', '"contains" must be a schema object.');
        }

        // object constraints
        if (isset($schema['properties'])) {
            if (!is_array($schema['properties']) || !$this->isAssoc($schema['properties'])) {
                $this->err($errors, $path, 'properties', '"properties" must be an object.');
            } else {
                foreach ($schema['properties'] as $prop => $sub) {
                    if (!is_array($sub)) {
                        $this->err($errors, $path.'/properties/'.self::escape($prop), 'properties', 'Property schema must be an object.');
                    } else {
                        $this->checkSchemaNode($sub, $path.'/properties/'.self::escape($prop), $errors, $depth + 1);
                    }
                }
            }
        }
        if (isset($schema['patternProperties'])) {
            if (!is_array($schema['patternProperties']) || !$this->isAssoc($schema['patternProperties'])) {
                $this->err($errors, $path, 'patternProperties', '"patternProperties" must be an object.');
            } else {
                foreach ($schema['patternProperties'] as $pat => $sub) {
                    if (!$this->pregIsValid($pat)) {
                        $this->err($errors, $path.'/patternProperties', 'patternProperties', "Invalid regex key: {$pat}");
                    }
                    if (!is_array($sub)) {
                        $this->err($errors, $path.'/patternProperties', 'patternProperties', 'Value must be a schema object.');
                    } else {
                        $this->checkSchemaNode($sub, $path.'/patternProperties/'.self::escape($pat), $errors, $depth + 1);
                    }
                }
            }
        }
        if (isset($schema['additionalProperties']) && !is_bool($schema['additionalProperties']) && !is_array($schema['additionalProperties'])) {
            $this->err($errors, $path, 'additionalProperties', '"additionalProperties" must be boolean or schema.');
        }
        if (isset($schema['required'])) {
            if (!is_array($schema['required'])) {
                $this->err($errors, $path, 'required', '"required" must be an array of strings.');
            } else {
                foreach ($schema['required'] as $i => $name) {
                    if (!is_string($name)) {
                        $this->err($errors, $path.'/required/'.$i, 'required', 'Entries must be strings.');
                    }
                }
            }
        }
        foreach (['minProperties','maxProperties'] as $key) {
            if (isset($schema[$key]) && !(is_int($schema[$key]) && $schema[$key] >= 0)) {
                $this->err($errors, $path, $key, "\"{$key}\" must be a non-negative integer.");
            }
        }
        if (isset($schema['propertyNames'])) {
            if (!is_array($schema['propertyNames'])) {
                $this->err($errors, $path, 'propertyNames', '"propertyNames" must be a schema object.');
            } else {
                $this->checkSchemaNode($schema['propertyNames'], $path.'/propertyNames', $errors, $depth + 1);
            }
        }

        // combinators
        foreach (['allOf','anyOf','oneOf'] as $key) {
            if (isset($schema[$key])) {
                if (!is_array($schema[$key])) {
                    $this->err($errors, $path, $key, "\"{$key}\" must be an array of schemas.");
                } else {
                    foreach ($schema[$key] as $i => $sub) {
                        if (!is_array($sub)) {
                            $this->err($errors, $path.'/'.$key.'/'.$i, $key, 'Entry must be a schema object.');
                        } else {
                            $this->checkSchemaNode($sub, $path.'/'.$key.'/'.$i, $errors, $depth + 1);
                        }
                    }
                }
            }
        }
        if (isset($schema['not'])) {
            if (!is_array($schema['not'])) {
                $this->err($errors, $path, 'not', '"not" must be a schema object.');
            } else {
                $this->checkSchemaNode($schema['not'], $path.'/not', $errors, $depth + 1);
            }
        }

        // conditionals
        if (isset($schema['if']) && is_array($schema['if'])) { $this->checkSchemaNode($schema['if'], $path.'/if', $errors, $depth + 1); }
        if (isset($schema['then']) && is_array($schema['then'])) { $this->checkSchemaNode($schema['then'], $path.'/then', $errors, $depth + 1); }
        if (isset($schema['else']) && is_array($schema['else'])) { $this->checkSchemaNode($schema['else'], $path.'/else', $errors, $depth + 1); }

        // dependencies / dependents
        if (isset($schema['dependencies']) && is_array($schema['dependencies'])) {
            foreach ($schema['dependencies'] as $k => $dep) {
                if (!(is_string($k) && (is_array($dep) || is_string($dep)))) {
                    $this->err($errors, $path.'/dependencies', 'dependencies', 'Invalid dependency mapping.');
                } else {
                    if (is_array($dep) && $this->isAssoc($dep)) {
                        $this->checkSchemaNode($dep, $path.'/dependencies/'.self::escape($k), $errors, $depth + 1);
                    }
                }
            }
        }
        if (isset($schema['dependentRequired']) && is_array($schema['dependentRequired'])) {
            foreach ($schema['dependentRequired'] as $k => $arr) {
                if (!is_array($arr)) {
                    $this->err($errors, $path.'/dependentRequired/'.self::escape($k), 'dependentRequired', 'Must be an array of strings.');
                }
            }
        }
        if (isset($schema['dependentSchemas']) && is_array($schema['dependentSchemas'])) {
            foreach ($schema['dependentSchemas'] as $k => $sub) {
                if (!is_array($sub)) {
                    $this->err($errors, $path.'/dependentSchemas/'.self::escape($k), 'dependentSchemas', 'Must be a schema object.');
                } else {
                    $this->checkSchemaNode($sub, $path.'/dependentSchemas/'.self::escape($k), $errors, $depth + 1);
                }
            }
        }

        // $defs / definitions
        $defs = $schema['$defs'] ?? ($schema['definitions'] ?? null);
        if (is_array($defs)) {
            foreach ($defs as $name => $sub) {
                if (is_array($sub)) {
                    $this->checkSchemaNode($sub, $path.'/$defs/'.self::escape($name), $errors, $depth + 1);
                } else {
                    $this->err($errors, $path.'/$defs/'.self::escape($name), '$defs', 'Definition must be a schema object.');
                }
            }
        }
    }

    private function checkAllRefsResolvable(array $schema, string $path, array &$errors): void
    {
        foreach ($schema as $k => $v) {
            if ($k === '$ref' && is_string($v)) {
                if ($this->resolveRef($v) === null) {
                    $this->err($errors, $path, '$ref', "Unresolvable \$ref: {$v}");
                }
            } elseif (is_array($v)) {
                $this->checkAllRefsResolvable($v, $path.'/'.$k, $errors);
            }
        }
    }

    /** @param array<int,array<string,mixed>> $errors */
    private function err(array &$errors, string $path, string $keyword, string $message, array $extra = []): void
    {
        $e = ['path' => $path === '' ? '/' : $path, 'keyword' => $keyword, 'message' => $message];
        foreach ($extra as $k => $v) { $e[$k] = $v; }
        $errors[] = $e;
    }

    private static function escape(string $segment): string
    {
        return str_replace(['~','/'], ['~0','~1'], $segment);
    }

    private function resolveRef(string $ref)
    {
        if ($ref === '#' || $ref === '#/') { return $this->rootSchema; }
        if (strlen($ref) > 1 && $ref[0] === '#') {
            $ptr = substr($ref, 1);
            return $this->jsonPointerGet($this->rootSchema, $ptr);
        }
        return null; // external $ref not supported
    }

    private function jsonPointerGet($doc, string $pointer)
    {
        if ($pointer === '') { return $doc; }
        if ($pointer[0] !== '/') { return null; }
        $parts = explode('/', $pointer);
        array_shift($parts);
        $cur = $doc;
        foreach ($parts as $raw) {
            $seg = str_replace(['~1','~0'], ['/','~'], $raw);
            if (is_array($cur)) {
                if (array_key_exists($seg, $cur)) {
                    $cur = $cur[$seg];
                } elseif (!$this->isAssoc($cur) && ctype_digit((string)$seg) && array_key_exists((int)$seg, $cur)) {
                    $cur = $cur[(int)$seg];
                } else {
                    return null;
                }
            } else {
                return null;
            }
        }
        return $cur;
    }

    private function matchesType($data, string $type): bool
    {
        switch ($type) {
            case 'null': return $data === null;
            case 'boolean': return is_bool($data);
            case 'integer': return is_int($data);
            case 'number': return is_int($data) || is_float($data);
            case 'string': return is_string($data);
            case 'array': return is_array($data) && $this->isList($data);
            case 'object': return is_array($data) && $this->isAssoc($data);
            default: return false;
        }
    }

    private function typeOf($data): string
    {
        if ($data === null) return 'null';
        if (is_bool($data)) return 'boolean';
        if (is_int($data)) return 'integer';
        if (is_float($data)) return 'number';
        if (is_string($data)) return 'string';
        if (is_array($data)) return $this->isList($data) ? 'array' : 'object';
        return 'unknown';
    }

    private function isList(array $a): bool
    {
        if (function_exists('array_is_list')) { return array_is_list($a); }
        $i = 0;
        foreach ($a as $k => $_) {
            if ($k !== $i) return false;
            $i++;
        }
        return true;
    }

    private function isAssoc(array $a): bool
    {
        return !$this->isList($a);
    }

    private function strlen(string $s): int
    {
        return function_exists('mb_strlen') ? mb_strlen($s, 'UTF-8') : strlen($s);
    }

    private function deepEquals($a, $b): bool
    {
        return json_encode($a, JSON_UNESCAPED_UNICODE|JSON_UNESCAPED_SLASHES|JSON_PRESERVE_ZERO_FRACTION)
             === json_encode($b, JSON_UNESCAPED_UNICODE|JSON_UNESCAPED_SLASHES|JSON_PRESERVE_ZERO_FRACTION);
    }

    private function pregIsValid(string $pattern): bool
    {
        set_error_handler(static function(){});
        $ok = @preg_match($this->wrapRegex($pattern), '') !== false;
        restore_error_handler();
        return $ok;
    }

    private function wrapRegex(string $pattern): string
    {
        $delim = '/';
        if (strlen($pattern) > 2 && $pattern[0] === '/' && strrpos($pattern, '/') !== 0) {
            $last = strrpos($pattern, '/');
            $body = substr($pattern, 1, $last - 1);
            $mods = substr($pattern, $last + 1);
            if (strpos($mods, 'u') === false) $mods .= 'u';
            return "/{$body}/{$mods}";
        }
        return $delim . $pattern . $delim . 'u';
    }

    private function checkFormat(string $fmt, string $value): bool
    {
        switch (strtolower($fmt)) {
            case 'email':
                return filter_var($value, FILTER_VALIDATE_EMAIL) !== false;
            case 'uri':
                return filter_var($value, FILTER_VALIDATE_URL) !== false;
            case 'ipv4':
                return filter_var($value, FILTER_VALIDATE_IP, FILTER_FLAG_IPV4) !== false;
            case 'ipv6':
                return filter_var($value, FILTER_VALIDATE_IP, FILTER_FLAG_IPV6) !== false;
            case 'uuid':
                return (bool)preg_match('/^[a-f0-9]{8}-[a-f0-9]{4}-[1-5][a-f0-9]{3}-[ab89][a-f0-9]{3}-[a-f0-9]{12}$/i', $value);
            case 'hostname':
                return (bool)preg_match('/^(?=.{1,253}$)(?!-)[A-Za-z0-9-]{1,63}(?<!-)(\.(?!-)[A-Za-z0-9-]{1,63}(?<!-))*$/', $value);
            case 'date':
                if (!preg_match('/^\d{4}-\d{2}-\d{2}$/', $value)) return false;
                [$y,$m,$d] = array_map('intval', explode('-', $value));
                return checkdate($m, $d, $y);
            case 'time':
                return (bool)preg_match('/^\d{2}:\d{2}(:\d{2}(\.\d+)?)?(Z|[+\-]\d{2}:\d{2})?$/', $value);
            case 'date-time':
                return (bool)preg_match('/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d+)?(Z|[+\-]\d{2}:\d{2})$/', $value);
            default:
                return true; // unbekannte Formate -> akzeptieren (keine Prüfung)
        }
    }
}

/** ------------------------ REST API Handler ------------------------ */
if (php_sapi_name() !== 'cli') {
    // CORS + Content-Type
    header('Content-Type: application/json; charset=utf-8');
    header('Access-Control-Allow-Origin: *');
    header('Access-Control-Allow-Methods: POST, OPTIONS');
    header('Access-Control-Allow-Headers: Content-Type');

    if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
        http_response_code(204);
        exit;
    }

    if ($_SERVER['REQUEST_METHOD'] === 'GET') {
        http_response_code(200);
        echo json_encode([
            'ok' => true,
            'usage' => 'Send POST with JSON body: {"action":"validate"|"validateSchema","schema":{...},"data":{...}}'
        ], JSON_UNESCAPED_UNICODE);
        exit;
    }

    if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
        http_response_code(405);
        echo json_encode([
            'ok' => false,
            'error' => ['code' => 'method_not_allowed', 'message' => 'Use POST with application/json.']
        ], JSON_UNESCAPED_UNICODE);
        exit;
    }

    $raw = file_get_contents('php://input');
    if ($raw === false || $raw === '') {
        http_response_code(400);
        echo json_encode(['ok' => false, 'error' => ['code' => 'bad_request', 'message' => 'Empty request body']], JSON_UNESCAPED_UNICODE);
        exit;
    }

    $payload = json_decode($raw, true);
    if (json_last_error() !== JSON_ERROR_NONE) {
        http_response_code(400);
        echo json_encode([
            'ok' => false,
            'error' => ['code' => 'invalid_json', 'message' => 'Request body is not valid JSON: '.json_last_error_msg()]
        ], JSON_UNESCAPED_UNICODE);
        exit;
    }

    $actionRaw = $payload['action'] ?? $payload['mode'] ?? '';
    $action = is_string($actionRaw) ? strtolower(trim($actionRaw)) : '';

    $normalizeJsonNode = static function($node) {
        if (is_string($node)) {
            $decoded = json_decode($node, true);
            if (json_last_error() === JSON_ERROR_NONE) {
                return $decoded;
            }
        }
        return $node;
    };

    $v = new JsonSchemaValidator();

    if ($action === 'validate' || $action === 'validate_instance' || $action === 'validateinstance') {
        $schema = $normalizeJsonNode($payload['schema'] ?? null);
        $data   = $normalizeJsonNode($payload['data'] ?? null);

        if (!is_array($schema)) {
            http_response_code(400);
            echo json_encode([
                'ok' => false,
                'error' => ['code' => 'bad_request', 'message' => '"schema" must be an object (or JSON string of an object).']
            ], JSON_UNESCAPED_UNICODE);
            exit;
        }
        // Schema zuerst prüfen
        [$schemaOk, $schemaErrors] = $v->validateSchema($schema);
        if (!$schemaOk) {
            echo json_encode(['ok' => false, 'phase' => 'schema', 'errors' => $schemaErrors], JSON_UNESCAPED_UNICODE);
            exit;
        }
        // Instanz validieren
        [$ok, $errors] = $v->validate($data, $schema);
        echo json_encode(['ok' => $ok, 'phase' => 'instance', 'errors' => $errors], JSON_UNESCAPED_UNICODE);
        exit;
    }

    if ($action === 'validateschema' || $action === 'validate_schema' || $action === 'validateschemaonly' || $action === 'validateschemaonly') {
        $schema = $normalizeJsonNode($payload['schema'] ?? null);
        if (!is_array($schema)) {
            http_response_code(400);
            echo json_encode([
                'ok' => false,
                'error' => ['code' => 'bad_request', 'message' => '"schema" must be an object (or JSON string of an object).']
            ], JSON_UNESCAPED_UNICODE);
            exit;
        }
        [$ok, $errors] = $v->validateSchema($schema);
        echo json_encode(['ok' => $ok, 'phase' => 'schema', 'errors' => $errors], JSON_UNESCAPED_UNICODE);
        exit;
    }

    http_response_code(400);
    echo json_encode([
        'ok' => false,
        'error' => ['code' => 'bad_request', 'message' => 'Unknown action. Use "validate" or "validateSchema".']
    ], JSON_UNESCAPED_UNICODE);
    exit;
}

/** ------------------------ CLI entrypoint ------------------------ */
if (php_sapi_name() === 'cli' && realpath($argv[0]) === realpath($_SERVER['SCRIPT_FILENAME'])) {
    $args = $argv;
    array_shift($args);

    $schemaFile = null;
    $validateFile = null;
    $validateSchemaFile = null;

    for ($i=0; $i<count($args); $i++) {
        $a = $args[$i];
        if ($a === '--schema' && isset($args[$i+1])) { $schemaFile = $args[++$i]; }
        elseif ($a === '--validate' && isset($args[$i+1])) { $validateFile = $args[++$i]; }
        elseif ($a === '--validate-schema' && isset($args[$i+1])) { $validateSchemaFile = $args[++$i]; }
        elseif ($a === '-h' || $a === '--help') {
            fwrite(STDERR, "Usage:\n".
                "  php ".$_SERVER['SCRIPT_FILENAME']." --validate-schema schema.json\n".
                "  php ".$_SERVER['SCRIPT_FILENAME']." --schema schema.json --validate data.json\n".
                "  (use '-' to read JSON from STDIN)\n");
            exit(0);
        }
    }

    $v = new JsonSchemaValidator();

    $readJson = function (?string $file) {
        if ($file === null) return null;
        $json = $file === '-' ? stream_get_contents(STDIN) : @file_get_contents($file);
        if ($json === false) {
            fwrite(STDERR, "Error: cannot read file {$file}\n"); exit(2);
        }
        $data = json_decode($json, true);
        if (json_last_error() !== JSON_ERROR_NONE) {
            fwrite(STDERR, "Error: invalid JSON in {$file}: ".json_last_error_msg()."\n"); exit(2);
        }
        return $data;
    };

    if ($validateSchemaFile !== null) {
        $schema = $readJson($validateSchemaFile);
        [$ok, $errors] = $v->validateSchema($schema);
        echo json_encode(['ok'=>$ok, 'errors'=>$errors], JSON_PRETTY_PRINT|JSON_UNESCAPED_UNICODE).PHP_EOL;
        exit($ok ? 0 : 1);
    }

    if ($schemaFile !== null && $validateFile !== null) {
        $schema = $readJson($schemaFile);
        [$schemaOk, $schemaErrors] = $v->validateSchema($schema);
        if (!$schemaOk) {
            fwrite(STDERR, "Schema errors:\n".json_encode($schemaErrors, JSON_PRETTY_PRINT|JSON_UNESCAPED_UNICODE)."\n");
            exit(1);
        }
        $data = $readJson($validateFile);
        [$ok, $errors] = $v->validate($data, $schema);
        echo json_encode(['ok'=>$ok, 'errors'=>$errors], JSON_PRETTY_PRINT|JSON_UNESCAPED_UNICODE).PHP_EOL;
        exit($ok ? 0 : 1);
    }

    if ($schemaFile === null && $validateSchemaFile === null) {
        fwrite(STDERR, "Run with --help for usage.\n");
        exit(2);
    }
}
