extends Node

const FX = preload("res://presentation/cinematic_fx/CinematicTransitionFX.tscn")
var failures: Array[String] = []


func check(condition: bool, message: String) -> void:
	if not condition: failures.append(message)


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var clock := IslandPresentationClock.new()
	var profile: IslandHandoffProfile = load("res://dev/island_transition/handoff.tres")
	var end := profile.camera_profile.video_end
	clock.advance({"state":"playing","media_time":3.3366667},0.1)
	check(is_equal_approx(clock.time,3.3366667),"Video clock must use presented timestamp")
	for state: String in ["buffering","paused","error","gesture_required"]:
		clock.advance({"state":state,"media_time":3.45},1.0)
		check(is_equal_approx(clock.time,3.3366667),"Interrupted playback advanced live clock")
	clock.advance({"state":"playing","media_time":3.4},1.0,false)
	check(is_equal_approx(clock.time,3.3366667),"Focus loss advanced timeline")
	clock.advance({"state":"ended","duration":end},0.9)
	check(clock.live_tail and is_equal_approx(clock.time,end),"Endpoint added a duplicate delta")
	clock.advance({},0.01)
	check(is_equal_approx(clock.time,end+0.01),"Live tail failed to continue")
	clock.advance({},10.0,false)
	clock.advance({},10.0,true)
	check(is_equal_approx(clock.time,end+0.01),"Resume included hidden time")
	clock.advance({},0.1)
	check(is_equal_approx(clock.time,end+0.11),"Live tail did not resume")
	clock.reset()
	clock.advance({"state":"playing","media_time":3.4},0.1)
	clock.advance({"state":"playing","media_time":0.033},0.1)
	check(is_equal_approx(clock.time,0.033),"Retry between host frames failed to restart")
	var last := 1.0
	for i: int in range(101):
		var t := lerpf(profile.camera_profile.blend_start,end,float(i)/100.0)
		var opacity := profile.video_opacity(t)
		check(opacity <= last+0.000001 and opacity>=0.0 and opacity<=1.0,"Blend opacity not bounded/monotonic")
		last = opacity
	check(profile.video_opacity(0.0)==1.0 and profile.video_opacity(end)==0.0,"Blend endpoints differ")
	check(profile.blur_envelope(profile.camera_profile.settle_end)==0.0,"Blur persists into attract")
	var fx := FX.instantiate() as CinematicTransitionFX
	add_child(fx)
	check(fx.begin_external(profile.blur_profile,CinematicTransitionFX.Quality.DESKTOP,true),"External blur failed")
	check(fx.camera == null and not fx.is_processing(),"External effect claimed camera/clock ownership")
	fx.sample_external(0.5,0.8)
	var strength: float = fx.shader_parameter(&"blur_strength")
	fx.advance_for_test(0.9)
	fx._notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	fx._on_viewport_size_changed()
	check(fx.is_active and is_equal_approx(float(fx.shader_parameter(&"blur_strength")),strength),"External held frame changed on pause/resize/focus")
	fx.sample_external(0.75,0.0)
	check(not fx.blur_rect.visible and fx.back_buffer_copy.copy_mode==BackBufferCopy.COPY_MODE_DISABLED,"Zero envelope still copies screen")
	fx.cancel()
	check(not fx.is_active and not fx.externally_sampled,"External cleanup failed")
	fx.begin_external(profile.blur_profile,CinematicTransitionFX.Quality.MOBILE_LOW,true)
	check(fx.active_sample_count==4,"Mobile blur budget changed")
	fx.cancel()
	var regular := CinematicFXProfile.new()
	regular.id = &"regular_after_external"
	var camera := Camera3D.new()
	camera.fov = 66.0
	add_child(camera)
	fx.play(regular,camera,CinematicTransitionFX.Quality.DESKTOP,false,true)
	check(fx.blur_rect.material.shader.resource_path.ends_with("cinematic_zoom_blur.gdshader"),"External shader leaked into regular consumer")
	fx.advance_for_test(regular.duration*0.5)
	check(is_equal_approx(camera.fov,74.0),"Regular FOV behavior changed")
	fx.cancel()
	check(is_equal_approx(camera.fov,66.0),"Regular cleanup changed after external mode")
	if failures.is_empty():
		print("ISLAND_HANDOFF_PASS simulated_clock, 101 blend samples, external FX ownership/hold/cleanup")
		get_tree().quit(0)
	else:
		for failure in failures: printerr("ISLAND_HANDOFF_FAIL: ",failure)
		get_tree().quit(1)
