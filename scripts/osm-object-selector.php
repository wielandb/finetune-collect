<?php
// osm_object_selector.php
// Create a data directory for token files
$dataDir = __DIR__ . '/data';
if (!file_exists($dataDir)) {
    mkdir($dataDir, 0755, true);
}
// CORS settings - change if hosted elsewhere
header('Access-Control-Allow-Origin: wielandb.github.io');
header('Access-Control-Allow-Methods: GET, POST, OPTIONS');
header('Access-Control-Allow-Headers: *');

// Cleanup old token files
$files = glob($dataDir . '/*.json');
foreach ($files as $file) {
    if (filemtime($file) < (time() - 7200)) {
        unlink($file);
    }
    $jsonData = @file_get_contents($file);
    if ($jsonData !== false) {
        $data = json_decode($jsonData, true);
        if (isset($data['ready']) && $data['ready'] === true) {
            if (filemtime($file) < time() - 15) {
                unlink($file);
            }
        }
    }
}

function getFilePath($token) {
    global $dataDir;
    return $dataDir . '/' . $token . '.json';
}

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    if (isset($_SERVER['CONTENT_TYPE']) && strpos($_SERVER['CONTENT_TYPE'], 'application/json') !== false) {
        $rawInput = file_get_contents('php://input');
        $jsonInput = json_decode($rawInput, true);
        if (json_last_error() === JSON_ERROR_NONE) {
            foreach ($jsonInput as $key => $value) {
                $_POST[$key] = $value;
            }
        } else {
            echo "Malformed JSON.";
        }
    }

    if (isset($_POST['token'])) {
        // Save the selected object
        $token = $_POST['token'];
        $filePath = getFilePath($token);
        if (!file_exists($filePath)) {
            echo "Invalid token.";
            exit;
        }
        $selected_type = $_POST['selected_type'] ?? '';
        $selected_id = $_POST['selected_id'] ?? '';
        $data = array(
            'selected_type' => $selected_type,
            'selected_id'   => $selected_id,
            'edited'        => true
        );
        file_put_contents($filePath, json_encode($data));
        echo "<html><body><script>window.close();</script></body></html>";
        exit;
    } else {
        // Create new selection session
        $lat = isset($_POST['lat']) ? floatval($_POST['lat']) : null;
        $lon = isset($_POST['lon']) ? floatval($_POST['lon']) : null;
        $selected_type = $_POST['selected_type'] ?? '';
        $selected_id   = $_POST['selected_id'] ?? '';
        if ($lat === null || $lon === null) {
            echo "Missing coordinates.";
            exit;
        }
        try {
            $token = bin2hex(random_bytes(16));
        } catch (Exception $e) {
            echo "Error generating token.";
            exit;
        }
        $filePath = getFilePath($token);
        $data = array(
            'lat'           => $lat,
            'lon'           => $lon,
            'selected_type' => $selected_type,
            'selected_id'   => $selected_id,
            'edited'        => false
        );
        file_put_contents($filePath, json_encode($data));
        echo $token;
        exit;
    }
} elseif ($_SERVER['REQUEST_METHOD'] === 'GET') {
    if (!isset($_GET['token'])) {
        echo "Token not provided.";
        exit;
    }
    $token = $_GET['token'];
    $filePath = getFilePath($token);
    if (!file_exists($filePath)) {
        echo "Invalid token or file not found.";
        exit;
    }

    if (isset($_GET['poll'])) {
        $fileContent = file_get_contents($filePath);
        $savedData = json_decode($fileContent, true);
        header('Content-Type: application/json');
        if (isset($savedData['edited']) && $savedData['edited'] === true) {
            $response = array(
                'ready'         => true,
                'selected_type' => $savedData['selected_type'],
                'selected_id'   => $savedData['selected_id']
            );
            unlink($filePath);
            echo json_encode($response);
        } else {
            echo json_encode(array('ready' => false));
        }
        exit;
    } else {
        $fileContent = file_get_contents($filePath);
        $savedData = json_decode($fileContent, true);
        if ($savedData === null) {
            echo "Error decoding saved data.";
            exit;
        }
        ?>
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>Select OSM Object</title>
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.2.2/dist/css/bootstrap.min.css" rel="stylesheet" crossorigin="anonymous">
    <link rel="stylesheet" href="https://unpkg.com/leaflet@1.9.4/dist/leaflet.css" />
    <script src="https://unpkg.com/leaflet@1.9.4/dist/leaflet.js"></script>
    <script src="https://cdn.jsdelivr.net/npm/osmtogeojson@3.0.0/osmtogeojson.js"></script>
    <style>
      #map { width: 100%; height: 60vh; }
      #objectList { height: 30vh; overflow-y: scroll; }
      .list-item:hover { background-color: #eef; cursor: pointer; }
      .selected { background-color: #cce !important; }
    </style>
</head>
<body class="p-2">
    <div id="map"></div>
    <ul id="objectList" class="list-group mt-2"></ul>
    <script>
        var token = <?php echo json_encode($token); ?>;
        var initLat = <?php echo json_encode($savedData['lat']); ?>;
        var initLon = <?php echo json_encode($savedData['lon']); ?>;
        var preType = <?php echo json_encode($savedData['selected_type']); ?>;
        var preId = <?php echo json_encode($savedData['selected_id']); ?>;

        var map = L.map('map').setView([initLat, initLon], 18);
        L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
            maxZoom: 19,
            attribution: '&copy; OpenStreetMap contributors'
        }).addTo(map);

        var highlightLayer = L.geoJSON(null, {
            style: {color: 'blue'}
        }).addTo(map);

        var objectData = [];

        function fetchObjects() {
            var overpassUrl = 'https://overpass-api.de/api/interpreter';
            var query = '[out:json];(' +
                'node(around:50,' + initLat + ',' + initLon + ');' +
                'way(around:50,' + initLat + ',' + initLon + ');' +
                'relation(around:50,' + initLat + ',' + initLon + ');' +
                ');out body;>;out skel qt;';
            fetch(overpassUrl, {method:'POST', body: query})
                .then(function(resp){ return resp.json(); })
                .then(function(data){ renderObjects(osmtogeojson(data)); })
                .catch(function(err){ console.error(err); });
        }

        function renderObjects(geo) {
            highlightLayer.clearLayers();
            objectData = [];
            var list = document.getElementById('objectList');
            list.innerHTML = '';
            geo.features.forEach(function(f){
                var t = f.properties.type;
                var id = f.properties.id;
                var name = (f.properties.tags && f.properties.tags.name) ? f.properties.tags.name : '';
                var layer = L.geoJSON(f);
                layer.on('mouseover', function(){ layer.setStyle({color:'orange'}); });
                layer.on('mouseout', function(){ if(!isSelected(t,id)) layer.setStyle({color:'blue'}); });
                layer.on('click', function(){ selectObject(t,id); });
                layer.addTo(highlightLayer);
                objectData.push({layer:layer,type:t,id:id,name:name});
                var li = document.createElement('li');
                li.className = 'list-group-item list-item';
                li.textContent = t + ' ' + id + (name ? ' - '+name : '');
                li.onmouseover = function(){ layer.setStyle({color:'orange'}); };
                li.onmouseout = function(){ if(!isSelected(t,id)) layer.setStyle({color:'blue'}); };
                li.onclick = function(){ selectObject(t,id); };
                list.appendChild(li);
                if(preType === t && String(preId) === String(id)) {
                    selectObject(t,id,true);
                }
            });
        }

        function isSelected(t,id) {
            return document.querySelector('#objectList li.selected[data-type="'+t+'"][data-id="'+id+'"]') !== null;
        }

        function selectObject(t,id,noSend) {
            document.querySelectorAll('#objectList li').forEach(function(li){
                li.classList.remove('selected');
            });
            document.querySelectorAll('#objectList li').forEach(function(li){
                if(li.textContent.startsWith(t + ' ' + id)) {
                    li.classList.add('selected');
                    li.setAttribute('data-type',t);
                    li.setAttribute('data-id',id);
                }
            });
            objectData.forEach(function(o){
                if(o.type === t && String(o.id) === String(id)) {
                    o.layer.setStyle({color:'red'});
                } else {
                    o.layer.setStyle({color:'blue'});
                }
            });
            if(!noSend) sendSelection(t,id);
        }

        function sendSelection(t,id) {
            var formData = new FormData();
            formData.append('token', token);
            formData.append('selected_type', t);
            formData.append('selected_id', id);
            fetch('<?php echo $_SERVER["PHP_SELF"]; ?>', {method:'POST', body: formData})
                .then(function(resp){ return resp.text(); })
                .then(function(){ window.close(); })
                .catch(function(err){ console.error(err); });
        }

        fetchObjects();
    </script>
</body>
</html>
<?php
        exit;
    }
} else {
    echo "Unsupported request method.";
    exit;
}
?>
