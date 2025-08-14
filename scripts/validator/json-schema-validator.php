<?php
require __DIR__ . '/vendor/autoload.php';
use JsonSchema\Validator;
use JsonSchema\Constraints\Factory;
use JsonSchema\SchemaStorage;

header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');

$input = file_get_contents('php://input');
$decoded = json_decode($input);

if (json_last_error() !== JSON_ERROR_NONE) {
    echo json_encode(['valid' => false, 'error' => 'Invalid JSON: ' . json_last_error_msg()]);
    exit;
}

$schema = null;
$data = null;
$legacy = true;

if (is_object($decoded) && (property_exists($decoded, 'schema') || property_exists($decoded, 'data'))) {
    $schema = $decoded->schema ?? null;
    $data = $decoded->data ?? null;
    $legacy = false;
} else {
    $schema = $decoded;
}

if ($schema === null) {
    echo json_encode(['valid' => false, 'error' => 'Missing schema']);
    exit;
}

$schemaStorage = new SchemaStorage();
$baseDir = __DIR__ . '/';
$schemas = [
    'https://json-schema.org/draft/2020-12/schema' => 'draft-2020-12-schema.json',
    'https://json-schema.org/draft/2020-12/meta/core' => 'meta/core.json',
    'https://json-schema.org/draft/2020-12/meta/applicator' => 'meta/applicator.json',
    'https://json-schema.org/draft/2020-12/meta/unevaluated' => 'meta/unevaluated.json',
    'https://json-schema.org/draft/2020-12/meta/validation' => 'meta/validation.json',
    'https://json-schema.org/draft/2020-12/meta/meta-data' => 'meta/meta-data.json',
    'https://json-schema.org/draft/2020-12/meta/format-annotation' => 'meta/format-annotation.json',
    'https://json-schema.org/draft/2020-12/meta/content' => 'meta/content.json',
];
foreach ($schemas as $uri => $file) {
    $schemaStorage->addSchema($uri, json_decode(file_get_contents($baseDir . $file)));
}

$factory = new Factory($schemaStorage);

$validator = new Validator($factory);
$validator->validate($schema, $schemaStorage->getSchema('https://json-schema.org/draft/2020-12/schema'));

$response = [];
if ($legacy) {
    $responseKeyValid = 'valid';
    $responseKeyErrors = 'errors';
} else {
    $responseKeyValid = 'schema_valid';
    $responseKeyErrors = 'schema_errors';
}
$response[$responseKeyValid] = $validator->isValid();

if (!$validator->isValid()) {
    $errors = [];
    foreach ($validator->getErrors() as $error) {
        $errors[] = $error['property'] . ': ' . $error['message'];
    }
    $response[$responseKeyErrors] = $errors;
    echo json_encode($response);
    exit;
}

if (!$legacy && $data !== null) {
    $dataValidator = new Validator($factory);
    $dataValidator->validate($data, $schema);
    $response['data_valid'] = $dataValidator->isValid();
    if (!$dataValidator->isValid()) {
        $errors = [];
        foreach ($dataValidator->getErrors() as $error) {
            $errors[] = $error['property'] . ': ' . $error['message'];
        }
        $response['data_errors'] = $errors;
    }
}

echo json_encode($response);
?>
