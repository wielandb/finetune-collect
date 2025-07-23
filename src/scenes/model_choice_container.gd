extends HBoxContainer

@onready var settingsdict = get_node("/root/FineTune").SETTINGS
var availablemodelslist = []

var model_name: String:
	get:
		# TODO: Diese Funktion muss damit klarkommen, wenn kein oder ein Ungültiges modell ausgewählt ist
		return $ModelOptionButton.get_item_text($ModelOptionButton.selected)
	set(value):
		$ModelOptionButton.select(-1)
		for itemix in range($ModelOptionButton.item_count):
			if $ModelOptionButton.get_item_text(itemix) == value:
				$ModelOptionButton.select(itemix)

func refresh_models():
	$ModelOptionButton.clear()
	for modelname in settingsdict.get("availableModels", []):
		$ModelOptionButton.add_item(modelname)
		
	
func _ready() -> void:
	refresh_models()
