extends TextureRect


var sprites = [
	"res://icons/polling/reload-custom_1.png",
	"res://icons/polling/reload-custom_2.png",
	"res://icons/polling/reload-custom_3.png",
	"res://icons/polling/reload-custom_4.png",
	"res://icons/polling/reload-custom_5.png",
	"res://icons/polling/reload-custom_6.png",
	"res://icons/polling/reload-custom_7.png",
	"res://icons/polling/reload-custom_8.png",
	"res://icons/polling/reload-custom_9.png",
	"res://icons/polling/reload-custom_10.png",
	"res://icons/polling/reload-custom_11.png",
	"res://icons/polling/reload-custom_12.png",
	"res://icons/polling/reload-custom_13.png",
	"res://icons/polling/reload-custom_14.png",
	"res://icons/polling/reload-custom_15.png",
	"res://icons/polling/reload-custom_16.png",
	"res://icons/polling/reload-custom_17.png",
	"res://icons/polling/reload-custom_18.png",
	"res://icons/polling/reload-custom_19.png",
	"res://icons/polling/reload-custom_20.png",
	"res://icons/polling/reload-custom_21.png",
	"res://icons/polling/reload-custom_22.png",
	"res://icons/polling/reload-custom_23.png",
	"res://icons/polling/reload-custom_24.png",
	"res://icons/polling/reload-custom_25.png",
	"res://icons/polling/reload-custom_26.png",
	"res://icons/polling/reload-custom_27.png",
	"res://icons/polling/reload-custom_28.png",
	"res://icons/polling/reload-custom_29.png",
	"res://icons/polling/reload-custom_30.png",
	"res://icons/polling/reload-custom_31.png",
	"res://icons/polling/reload-custom_32.png",
	"res://icons/polling/reload-custom_33.png",
	"res://icons/polling/reload-custom_34.png",
	"res://icons/polling/reload-custom_35.png"
	]
var textures = []
var textureIndex = 0
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	
	for t in sprites:
		textures.append(load(t))


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	texture = textures[textureIndex]
	textureIndex += 1
	if textureIndex > 34:
		textureIndex = 0
