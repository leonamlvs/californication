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
var _cache: Dictionary = {}
var _voices: Array[AudioStreamPlayer] = []
var _beds: Array[AudioStreamPlayer] = []
var _voice_index := 0
var _bed_index := 0
var active_ambience: StringName = &""
var _crossfade: Tween


func _ready() -> void:
	_ensure_bus(MUSIC_BUS)
	_ensure_bus(SFX_BUS)
	_apply_bus_step(MUSIC_BUS, music_step)
	_apply_bus_step(SFX_BUS, sfx_step)
	for index: int in range(8):
		var voice := AudioStreamPlayer.new()
		voice.bus = SFX_BUS
		add_child(voice)
		_voices.append(voice)
	for index: int in range(2):
		var bed := AudioStreamPlayer.new()
		bed.bus = MUSIC_BUS
		add_child(bed)
		_beds.append(bed)
	GameFlow.selected_character_changed.connect(func(_id: StringName, _index: int): play_cue(&"navigation"))
	GameFlow.state_changed.connect(func(_previous: StringName, next_state: StringName):
		if next_state in [GameFlow.LOGO_REVEAL, GameFlow.CHARACTER_CONFIRMED, GameFlow.PAUSED]:
			play_cue(&"confirm")
		if next_state in [GameFlow.LOADING, GameFlow.ISLAND_ATTRACT]:
			var island := AmbienceProfile.new()
			island.id = &"island"
			island.frequency = 110.0
			island.noise = 0.94
			set_ambience(island)
	)


func play_cue(id: StringName) -> void:
	if _voices.is_empty():
		return
	var key := "cue:" + String(id)
	if not _cache.has(key):
		var cue := AudioCue.new()
		var tuning: Dictionary = {
			&"lane": [280.0, 420.0, 0.055, 0.15], &"jump": [260.0, 760.0, 0.18, 0.0],
			&"slide": [420.0, 110.0, 0.20, 0.4], &"rise": [220.0, 850.0, 0.22, 0.1],
			&"dive": [660.0, 160.0, 0.22, 0.1], &"pickup": [880.0, 1320.0, 0.09, 0.0],
			&"token": [440.0, 1760.0, 0.3, 0.0], &"impact": [95.0, 35.0, 0.32, 0.7],
			&"bonus": [660.0, 1320.0, 0.38, 0.0], &"handoff": [180.0, 720.0, 0.3, 0.25],
			&"navigation": [420.0, 480.0, 0.045, 0.0], &"confirm": [520.0, 1040.0, 0.14, 0.0],
		}
		var values: Array = tuning.get(id, tuning[&"navigation"])
		cue.frequency = values[0]
		cue.end_frequency = values[1]
		cue.duration = values[2]
		cue.noise = values[3]
		_cache[key] = _synthesize(cue.frequency, cue.end_frequency, cue.duration, cue.noise, cue.gain, false)
	var voice := _voices[_voice_index]
	_voice_index = (_voice_index + 1) % _voices.size()
	voice.stream = _cache[key]
	voice.play()


func set_ambience(profile: AmbienceProfile) -> void:
	if profile == null or profile.id == active_ambience or _beds.is_empty():
		return
	active_ambience = profile.id
	var key := "ambience:" + String(profile.id)
	if not _cache.has(key):
		_cache[key] = _synthesize(profile.frequency, profile.frequency, 4.0, profile.noise, profile.gain, true)
	if _crossfade != null:
		_crossfade.kill()
	var old := _beds[_bed_index]
	_bed_index = 1 - _bed_index
	var next := _beds[_bed_index]
	next.stream = _cache[key]
	next.volume_db = -60.0
	next.play()
	_crossfade = create_tween().set_parallel(true)
	_crossfade.tween_property(old, "volume_db", -60.0, 0.7)
	_crossfade.tween_property(next, "volume_db", 0.0, 0.7)


func _synthesize(frequency: float, end_frequency: float, duration: float, noise: float, gain: float, loop: bool) -> AudioStreamWAV:
	const RATE := 22050
	var frames := int(duration * RATE)
	var bytes := PackedByteArray()
	bytes.resize(frames * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(frequency * 100.0)
	var phase := 0.0
	var filtered_noise := 0.0
	for index: int in range(frames):
		var progress := float(index) / frames
		phase += TAU * lerpf(frequency, end_frequency, progress) / RATE
		filtered_noise = lerpf(filtered_noise, rng.randf_range(-1.0, 1.0), 0.08 if loop else 0.65)
		var envelope := sin(PI * progress) if loop else minf(progress * 25.0, 1.0) * pow(1.0 - progress, 2.0)
		var sample := (sin(phase) * (1.0 - noise) + filtered_noise * noise) * gain * envelope
		bytes.encode_s16(index * 2, int(clampf(sample, -1.0, 1.0) * 32767.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = RATE
	stream.data = bytes
	if loop:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_end = frames
	return stream


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
	play_cue(&"navigation")


func adjust_sfx(delta: int) -> void:
	set_effects_volume(float(clampi(sfx_step + delta, 0, STEP_COUNT)) / STEP_COUNT)
	play_cue(&"navigation")


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
