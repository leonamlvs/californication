extends Node

const ISLAND_FRONTEND_SCENE := preload("res://frontend/island/IslandFrontend.tscn")
const LOGO_REVEAL_SCENE := preload("res://frontend/logo_reveal/LogoPresentationRig.tscn")

var failures: Array[String] = []


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	GameFlow.development_jump_to_state(GameFlow.ISLAND_ATTRACT)
	var island := ISLAND_FRONTEND_SCENE.instantiate() as IslandFrontendController
	add_child(island)
	var reveal := LOGO_REVEAL_SCENE.instantiate() as LogoRevealController
	add_child(reveal)
	await get_tree().process_frame
	island.set_process(false)
	reveal.set_process(false)

	_assert(_backgrounds_match(island, reveal), "Island and logo groups do not share the blue handoff color.")
	var selection_before := GameFlow.selected_character_index
	_assert(GameFlow.handle_intent(InputRouter.INTENT_CONFIRM), "Island confirmation did not enter Logo Reveal.")
	_assert(GameFlow.current_state == GameFlow.LOGO_REVEAL, "Logo Reveal state was not entered.")
	_assert(reveal.blue_handoff_plane.visible and not reveal.logo_assembly.visible, "Logo group did not begin behind the solid blue handoff.")
	_assert(island.blue_handoff_is_ready and island.active_group_count() == 0, "Island group did not provide its matching hidden-swap frame.")
	_assert(not GameFlow.handle_intent(InputRouter.INTENT_CONFIRM) and GameFlow.selected_character_index == selection_before, "Initiating confirm leaked into selection behavior.")

	var original_logo_id := reveal.logo_assembly.get_instance_id()
	_assert(original_logo_id == reveal.logo_instance_id, "Logo identity was not captured from the mounted assembly.")
	_assert(reveal.logo_extrusion.depth >= 0.6, "Logo placeholder is not genuinely extruded.")
	_assert(reveal.panel_anchor_count() == 4 and _anchors_are_quarter_turns(reveal), "Logo does not expose four equal indexed panel anchors.")
	_assert(_letters_are_extruded_geometry(reveal), "CALIFORNICATION ring is not individual extruded 3D text geometry.")

	reveal.advance_for_test(reveal.reveal_duration * 0.25)
	_assert(reveal.reveal_stage_index == 1 and reveal.logo_assembly.visible and reveal.letter_ring.visible, "Logo and circular lettering did not emerge after the blue handoff.")
	if OS.get_cmdline_user_args().has("--capture"):
		await RenderingServer.frame_post_draw
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build"))
		get_viewport().get_texture().get_image().save_png("res://build/task24_logo_only.png")
	reveal.advance_for_test(reveal.reveal_duration * 0.11)
	_assert(reveal.reveal_stage_index == 2 and reveal.alicorn.visible, "Alicorn did not approach from the authored distance.")
	var approach_distance := reveal.alicorn.position.distance_to(reveal.logo_camera.position)
	reveal.advance_for_test(reveal.reveal_duration * 0.18)
	_assert(reveal.alicorn.scale.x > 0.8 and reveal.alicorn.position.distance_to(reveal.logo_camera.position) < approach_distance, "Alicorn did not grow to fill and approach the camera.")
	if OS.get_cmdline_user_args().has("--capture"):
		await RenderingServer.frame_post_draw
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build"))
		get_viewport().get_texture().get_image().save_png("res://build/task24_logo_reveal.png")
	reveal.advance_for_test(reveal.reveal_duration * 0.22)
	_assert(reveal.alicorn_passed_camera, "Alicorn route did not pass the camera before departure.")
	reveal.advance_for_test(reveal.reveal_duration)
	_assert(GameFlow.current_state == GameFlow.CHARACTER_SELECT_ENTER, "Reveal did not end in Character Select Entry.")
	_assert(reveal.parked_at_first_detent and is_equal_approx(reveal.logo_assembly.rotation.y, reveal.ENTRY_DETENT_RADIANS), "Logo did not park exactly at the first carousel detent.")
	_assert(reveal.logo_assembly.get_instance_id() == original_logo_id, "Reveal logo was swapped for a separate selector object.")
	_assert(not reveal.alicorn.visible and reveal.logo_assembly.visible and reveal.letter_ring.visible, "Alicorn departure did not leave the same logo visible.")
	if OS.get_cmdline_user_args().has("--capture"):
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://build/task24_select_entry.png")

	for viewport_size: Vector2 in [Vector2(960, 720), Vector2(844, 390), Vector2(360, 640)]:
		var snapshot := reveal.composition_snapshot(viewport_size)
		_assert(snapshot.letters_inside_safe_region and snapshot.alicorn_inside_safe_region and snapshot.panel_anchors_readable, "Logo reveal leaves the safe composition at %s." % viewport_size)
	_assert(reveal.composition_snapshot(Vector2(360, 640)).distance_scale > 1.0, "Narrow composition did not pull the logo camera back.")

	reveal.development_enter_reveal()
	_assert(GameFlow.current_state == GameFlow.LOGO_REVEAL and reveal.reveal_stage_index == 0, "DevHarness direct Logo Reveal entry failed.")
	reveal.development_skip_reveal()
	_assert(GameFlow.current_state == GameFlow.CHARACTER_SELECT_ENTER and reveal.parked_at_first_detent, "DevHarness completion did not reach the stable detent.")

	island.queue_free()
	reveal.queue_free()
	if failures.is_empty():
		print("TASK24_PASS")
		get_tree().quit(0)
	else:
		for failure_message: String in failures:
			push_error(failure_message)
		get_tree().quit(1)


func _backgrounds_match(island: IslandFrontendController, reveal: LogoRevealController) -> bool:
	var island_color := island.blue_environment.environment.background_color
	var reveal_color := reveal.handoff_blue_color()
	return Vector4(island_color.r, island_color.g, island_color.b, island_color.a).distance_to(\
		Vector4(reveal_color.r, reveal_color.g, reveal_color.b, reveal_color.a)\
	) < 0.04


func _anchors_are_quarter_turns(reveal: LogoRevealController) -> bool:
	for index: int in reveal.panel_anchor_count():
		var next_index := (index + 1) % reveal.panel_anchor_count()
		var difference := fposmod(reveal.panel_anchor_detent(next_index) - reveal.panel_anchor_detent(index), TAU)
		if not is_equal_approx(difference, reveal.DETENT_STEP_RADIANS):
			return false
	return true


func _letters_are_extruded_geometry(reveal: LogoRevealController) -> bool:
	if reveal.letter_ring.get_child_count() != reveal.LETTER_TEXT.length():
		return false
	for child: Node in reveal.letter_ring.get_children():
		if not child is MeshInstance3D:
			return false
		var mesh := (child as MeshInstance3D).mesh
		if not mesh is TextMesh or (mesh as TextMesh).depth <= 0.0:
			return false
	return true


func _assert(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
