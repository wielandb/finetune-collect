<?php
// json_editor.php
// Make sure a data directory exists to store token files.
$dataDir = __DIR__ . '/data';
if (!file_exists($dataDir)) {
    mkdir($dataDir, 0755, true);
}
// Make sure to chenge this depending on where you are hosting this
header('Access-Control-Allow-Origin: wielandb.github.io');
header('Access-Control-Allow-Methods: GET, POST, OPTIONS');
header('Access-Control-Allow-Headers: *');


$files = glob('data/*.json');

// Loop through each matching file
foreach ($files as $file) {
    // Check if the file is older than two hours (7200 seconds)
    if (filemtime($file) < (time() - 7200)) {
        unlink($file);
    }
    // 2. Otherwise, load and check if "ready" is true, 
    // and if the file was last modified more than 15 seconds ago.
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
    // The token is used as the filename (with .json extension)
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
	echo "Smth wrong with the JSON!";
		}
    }
    // -------------------------------
    // POST requests:
    // 1. Without a token: initial creation (receives json_schema and json_data)
    // 2. With a token: the editor is saving updated data.
    // -------------------------------
    if (isset($_POST['token'])) {
        // --- Save/Submit updated data from the editor ---
        $token = $_POST['token'];
        $filePath = getFilePath($token);
        if (!file_exists($filePath)) {
            echo "Invalid token.";
            exit;
        }
        // Expect updated JSON data and schema in POST parameters.
        $json_data = $_POST['json_data'] ?? '';
        $json_schema = $_POST['json_schema'] ?? '';
        // Save the new values and mark as edited.
        $data = array(
            'schema'  => $json_schema,
            'data'    => $json_data,
            'edited'  => true
        );
        file_put_contents($filePath, json_encode($data));
        // Respond with JavaScript that will automatically close the page.
        echo "<html><body><script>window.close();</script></body></html>";
        exit;
    } else {
        // --- Create a new editing session ---
        // Expect JSON strings in POST parameters (named 'json_schema' and 'json_data').
        $json_data = $_POST['json_data'] ?? '';
        $json_schema = $_POST['json_schema'] ?? '';
        if (!$json_data || !$json_schema) {
            echo "Missing json_data or json_schema.";
            echo "json_data:".$json_data;
            echo "json_schema:".$json_schema;
            echo var_dump($_POST);
            exit;
        }
        // Generate a unique token.
        try {
            $token = bin2hex(random_bytes(16));
        } catch (Exception $e) {
            echo "Error generating token.";
            exit;
        }
        $filePath = getFilePath($token);
        // Save the initial data (edited flag set to false).
        $data = array(
            'schema'  => $json_schema,
            'data'    => $json_data,
            'edited'  => false
        );
        file_put_contents($filePath, json_encode($data));
        // Return the token (plain text) so the native app can use it.
        echo $token;
        exit;
    }
} elseif ($_SERVER['REQUEST_METHOD'] === 'GET') {
    // -------------------------------
    // GET requests:
    // 1. With a token and no extra parameter: display the JSON Editor page.
    // 2. With a token and a poll parameter: return status (and new data if editing is complete).
    // -------------------------------
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
    
    // Polling endpoint: e.g., ?token=...&poll=1
    if (isset($_GET['poll'])) {
        $fileContent = file_get_contents($filePath);
        $savedData = json_decode($fileContent, true);
        header('Content-Type: application/json');
        if (isset($savedData['edited']) && $savedData['edited'] === true) {
            // Editing has concluded.
            $response = array(
                'ready'       => true,
                'json_schema' => $savedData['schema'],
                'json_data'   => $savedData['data']
            );
            // Delete the file now that the new data has been delivered.
            unlink($filePath);
            echo json_encode($response);
        } else {
            echo json_encode(array('ready' => false));
        }
        exit;
    } else {
        // --- Render the JSON Editor interface ---
        $fileContent = file_get_contents($filePath);
        $savedData = json_decode($fileContent, true);
        // The data saved is expected to be valid JSON strings.
        // Decode these to embed them as JavaScript objects.
        $schemaObj = json_decode($savedData['schema']);
        $dataObj   = json_decode($savedData['data']);
        if ($schemaObj === null || $dataObj === null) {
            echo "Error decoding saved JSON.";
            exit;
        }
        ?>
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>JSON Editor</title>

  <!-- Enable responsive viewport -->
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <!-- Bootstrap4 -->
  <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.2.2/dist/css/bootstrap.min.css" rel="stylesheet" crossorigin="anonymous">

  <!-- fontawesome5 -->
  <link rel='stylesheet' href='https://use.fontawesome.com/releases/v5.12.1/css/all.css'>

  <!-- Handlebars -->
  <script src="https://cdn.jsdelivr.net/npm/handlebars@latest/dist/handlebars.js"></script>

  <!-- Flatpickr -->
  <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/flatpickr@4.6.3/dist/flatpickr.min.css">
  <script src="https://cdn.jsdelivr.net/npm/flatpickr@4.6.3/dist/flatpickr.min.js" integrity="sha256-/irFIZmSo2CKXJ4rxHWfrI+yGJuI16Z005X/bENdpTY=" crossorigin="anonymous"></script>
  
  <!-- JSON-Editor -->
  <script src="https://cdn.jsdelivr.net/npm/@json-editor/json-editor@latest/dist/jsoneditor.min.js"></script>

</head>
<body style="
    margin-left: 150px;
    max-width: 50%;
    margin-top: 50px;
    margin-bottom: 50px;
">
    <!-- Container for the editor -->
    <div id="editor_holder"></div>
    <!-- Save button to submit updated JSON -->
    <button width="100%" id="save_button">Save</button>
    <script>
        var schema = <?php echo json_encode($schemaObj); ?>;
        var jsonData = <?php echo json_encode($dataObj); ?>;
        
        // Create the JSON Editor.
        var editor = new JSONEditor(document.getElementById('editor_holder'), {
            schema: schema,
            startval: jsonData,
            theme: "bootstrap5",
            disable_edit_json: true,
            //disable_properties: true,
            enable_array_copy: true
        });
        
        // When the save button is clicked, post the updated JSON (and the schema) back to this file.
        document.getElementById('save_button').addEventListener('click', function(){
            var updatedData = editor.getValue();
            var formData = new FormData();
            formData.append('token', '<?php echo $token; ?>');
            formData.append('json_data', JSON.stringify(updatedData));
            // Sending the original schema (could be modified if desired)
            formData.append('json_schema', JSON.stringify(schema));
            
            fetch('<?php echo $_SERVER["PHP_SELF"]; ?>', {
                method: 'POST',
                body: formData
            })
            .then(function(response) {
                return response.text();
            })
            .then(function(text) {
                // After saving, automatically close the window.
		window.close();
                document.write("Saved. You can now close this tab. <i>For example by pressing CTRL + W</i>")
            })
            .catch(function(error) {
                console.error('Error saving data:', error);
            });
        });
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
