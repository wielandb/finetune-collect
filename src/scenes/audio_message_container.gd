extends VBoxContainer

func _process(delta: float) -> void:
	if $AudioStreamPlayer.playing:
		$AudioMediaPlayerContainer/PlayHeadSlider.min_value = 0
		$AudioMediaPlayerContainer/PlayHeadSlider.max_value = $AudioStreamPlayer.stream.get_length()
		$AudioMediaPlayerContainer/PlayHeadSlider.value = $AudioStreamPlayer.get_playback_position()
