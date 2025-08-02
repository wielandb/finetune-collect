extends VBoxContainer

# TODO: Prompt missing
func to_var():
	var me = {}
	me["type"] = "score_model"
	me["name"] = $NameContainer.grader_name
	me["model"] = $ModelContainer.model_name
	me["range"] = [float($RangeContainer/RangeFromEdit.text), float($RangeContainer/RangeToEdit.text)]
	me["sampling_params"] = {
		"temperature": float($SamplingParametersContainer/TemperatureEdit.text),
		"top_p": float($SamplingParametersContainer/TopPEdit.text),
		"seed": int($SamplingParametersContainer/SeedEdit.text)
	}
	return me
	
func from_var(grader_data):
	$NameContainer.grader_name = grader_data.get("name", "")
	$ModelContainer.model_name = grader_data.get("model", "")
	$RangeContainer/RangeFromEdit.text = str(grader_data.get("range", [0,1])[0])
	$RangeContainer/RangeToEdit.text = str(grader_data.get("range", [0,1])[1])
	$SamplingParametersContainer/TemperatureEdit.text = str(grader_data.get("sampling_params", {}).get("temperature", 1))
	$SamplingParametersContainer/TopPEdit.text = str(grader_data.get("sampling_params", {}).get("top_p", 1))
	$SamplingParametersContainer/SeedEdit.text = str(grader_data.get("sampling_params", {}).get("seed", 42))
	
