extends Node

## Reserved audio boundary. Mixer behavior is added with its owning UI task.


var sfx_step := 10
var music_step := 10

func set_master_volume(_linear_volume: float) -> void:
	pass


func set_music_volume(linear_volume: float) -> void:
	music_step = clampi(roundi(linear_volume * 10.0), 0, 10)


func set_effects_volume(linear_volume: float) -> void:
	sfx_step = clampi(roundi(linear_volume * 10.0), 0, 10)

func adjust_music(delta: int) -> void:
	music_step = clampi(music_step + delta, 0, 10)

func adjust_sfx(delta: int) -> void:
	sfx_step = clampi(sfx_step + delta, 0, 10)
