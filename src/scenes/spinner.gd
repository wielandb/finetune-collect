extends TextureRect

var textures := []
var texture_index := 0
const TEXTURE_DIR := "res://icons/polling"

func _ready() -> void:
	for i in range(1, 36):
		textures.append(load("%s/reload-custom_%d.png" % [TEXTURE_DIR, i]))

func _process(delta: float) -> void:
	if visible:
		texture = textures[texture_index]
		texture_index += 1
		if texture_index >= textures.size():
			texture_index = 0
