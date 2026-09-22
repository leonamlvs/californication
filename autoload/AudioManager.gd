extends Node

## Runtime mixer boundary used by the pause HUD. Player-facing controls expose
## Music and SFX only; Master remains an internal API.
signal levels_changed(sfx_step: int, music_step: int)

const STEP_COUNT := 10
const MUSIC_BUS := &"Music"
const SFX_BUS := &"SFX"
const SILENCE_DB := -80.0

var sfx_step := STEP_COUNT
var music_step := STEP_COUNT


func _ready() -> void:
	_ensure_bus(MUSIC_BUS)
	_ensure_bus(SFX_BUS)
	_apply_bus_step(MUSIC_BUS, music_step)
	_apply_bus_step(SFX_BUS, sfx_step)


func set_master_volume(linear_volume: float) -> void:
	var master_index := AudioServer.get_bus_index(&"Master")
	if master_index >= 0:
		var clamped := clampf(linear_volume, 0.0, 1.0)
		AudioServer.set_bus_mute(master_index, is_zero_approx(clamped))
		AudioServer.set_bus_volume_db(master_index, SILENCE_DB if is_zero_approx(clamped) else linear_to_db(clamped))


func set_music_volume(linear_volume: float) -> void:
	music_step = clampi(roundi(linear_volume * STEP_COUNT), 0, STEP_COUNT)
	_apply_bus_step(MUSIC_BUS, music_step)
	levels_changed.emit(sfx_step, music_step)


func set_effects_volume(linear_volume: float) -> void:
	sfx_step = clampi(roundi(linear_volume * STEP_COUNT), 0, STEP_COUNT)
	_apply_bus_step(SFX_BUS, sfx_step)
	levels_changed.emit(sfx_step, music_step)


func adjust_music(delta: int) -> void:
	set_music_volume(float(clampi(music_step + delta, 0, STEP_COUNT)) / STEP_COUNT)


func adjust_sfx(delta: int) -> void:
	set_effects_volume(float(clampi(sfx_step + delta, 0, STEP_COUNT)) / STEP_COUNT)


func _ensure_bus(bus_name: StringName) -> void:
	if AudioServer.get_bus_index(bus_name) >= 0:
		return
	AudioServer.add_bus()
	AudioServer.set_bus_name(AudioServer.bus_count - 1, bus_name)


func _apply_bus_step(bus_name: StringName, step: int) -> void:
	var bus_index := AudioServer.get_bus_index(bus_name)
	if bus_index < 0:
		return
	var linear_volume := float(clampi(step, 0, STEP_COUNT)) / STEP_COUNT
	AudioServer.set_bus_mute(bus_index, is_zero_approx(linear_volume))
	AudioServer.set_bus_volume_db(bus_index, SILENCE_DB if is_zero_approx(linear_volume) else linear_to_db(linear_volume))
