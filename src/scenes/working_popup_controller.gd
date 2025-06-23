extends Node

var popup_scene: PackedScene = preload("res://scenes/popup.tscn")
var popup: Popup

func _ready() -> void:
    popup = popup_scene.instantiate()
    popup.hide()
    get_tree().get_root().add_child(popup)

func show_popup() -> void:
    if popup:
        popup.popup_centered()

func hide_popup() -> void:
    if popup:
        popup.hide()
