<?php
error_reporting(E_ALL);
ini_set('display_errors', '1');

$UPLOAD_DIR = __DIR__ . '/uploaded_images';
$SECRET_KEY = 'gaertner';
if (!file_exists($UPLOAD_DIR)) {
	mkdir($UPLOAD_DIR, 0755, true);
}
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, OPTIONS');
header('Access-Control-Allow-Headers: *');
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
	exit;
}

// helper to build base url
function base_url() {
	$protocol = (!empty($_SERVER['HTTPS']) && $_SERVER['HTTPS'] !== 'off') ? 'https://' : 'http://';
	// include the script name so that the returned url can be used directly
	return $protocol . $_SERVER['HTTP_HOST'] . $_SERVER['SCRIPT_NAME'];
}

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
	$input = file_get_contents('php://input');
	$data = [];
	if (isset($_SERVER['CONTENT_TYPE']) && strpos($_SERVER['CONTENT_TYPE'], 'application/json') !== false) {
		$json = json_decode($input, true);
		if ($json !== null) { $data = $json; }
	} else {
		$data = $_POST;
	}
	$key = $data['key'] ?? '';
	if ($key !== $SECRET_KEY) {
		http_response_code(403);
		echo 'invalid key';
		exit;
	}
	$image_b64 = $data['image'] ?? '';
	if ($image_b64 === '') {
		http_response_code(400);
		echo 'missing image';
		exit;
	}
        $img_data = base64_decode($image_b64);
        if ($img_data === false) {
                http_response_code(400);
                echo 'decode failed';
                exit;
        }
        $ext = strtolower($data['ext'] ?? '');
        if (!in_array($ext, ['jpg', 'jpeg', 'png'])) {
                $ext = 'jpg';
        }
        $filename = 'img_' . md5($img_data) . '.' . $ext;
        file_put_contents($UPLOAD_DIR . '/' . $filename, $img_data);
        echo base_url() . '?image=' . urlencode($filename);
        exit;
}

if ($_SERVER['REQUEST_METHOD'] === 'GET' && isset($_GET['image'])) {
	$file = basename($_GET['image']);
	$path = $UPLOAD_DIR . '/' . $file;
	if (!is_file($path)) {
		http_response_code(404);
		echo 'not found';
		exit;
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

http_response_code(400);
echo 'invalid request';
?>