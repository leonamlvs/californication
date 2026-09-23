extends Node

const LOGO_SCENE := preload("res://frontend/logo_reveal/LogoPresentationRig.tscn")
const GAMEPLAY_DEPENDENCY_ROOTS: Array[String] = [
	"res://gameplay/runner", "res://gameplay/obstacles", "res://gameplay/track",
	"res://gameplay/scoring", "res://gameplay/transitions",
]

var failures: Array[String] = []


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	GameFlow.development_jump_to_state(GameFlow.BOOT)
	var reveal := LOGO_SCENE.instantiate() as LogoRevealController
	add_child(reveal)
	await get_tree().process_frame
	reveal.set_process(false)
	var carousel := reveal.carousel_controller
	var presenter := reveal.player_select_presenter
	carousel.set_process(false)
	presenter.set_process(false)
	var original_logo_id := reveal.logo_assembly.get_instance_id()

	GameFlow.development_jump_to_state(GameFlow.CHARACTER_SELECT_ENTER)
	await get_tree().process_frame
	_assert(GameFlow.current_state == GameFlow.CHARACTER_SELECT_ACTIVE, "Character Select Entry did not complete into active selection.")
	_assert(GameFlow.frontend_selection_controller_active, "Mounted carousel did not take ownership of selection intents.")
	_assert(reveal.logo_assembly.get_instance_id() == original_logo_id, "Task 25 replaced the Task 24 logo assembly.")
	_assert(carousel.character_visuals.size() == 4 and _visuals_are_anchor_bound(carousel), "Four identity-matched presentation models are not attached to the four logo anchors.")
	_assert(carousel.current_index == 0 and _only_visual_is_visible(carousel, 0), "Initial carousel focus is not the stable first detent.")
	_assert(presenter.current_definition == carousel.CHARACTER_DEFINITIONS[0], "Initial name/category/model binding is inconsistent.")
	_assert(presenter.VALUE_KEYS.size() == 6 and presenter.values_are_at_zero(), "Initial focus did not reset all six decorative values to 0.0.")

	presenter.advance_for_test(presenter.stat_animation_duration * 0.5)
	_assert(presenter.displayed_value(presenter.CATEGORY_KEY) > 0.0 and presenter.displayed_value(&"RHYTHM") > 0.0, "Decorative values did not visibly count/grow.")
	presenter.advance_for_test(presenter.stat_animation_duration)
	_assert(presenter.values_reached_targets(), "Decorative values did not reach CharacterDefinition targets.")

	var first_id := GameFlow.selected_character_id
	InputRouter.request_intent(InputRouter.INTENT_RIGHT)
	_assert(carousel.is_rotating and carousel.current_index == 0, "Right intent did not begin exactly one detent rotation.")
	carousel.advance_for_test(carousel.rotation_duration * 0.5)
	_assert(presenter.current_definition == carousel.CHARACTER_DEFINITIONS[0] and GameFlow.selected_character_id == first_id, "Identity updated before the new panel became front-facing.")
	_assert(_only_visual_is_visible(carousel, 0), "Presentation model changed before detent settlement.")
	carousel.advance_for_test(carousel.rotation_duration)
	_assert(carousel.current_index == 1 and not carousel.is_rotating, "Right intent did not settle at the next character.")
	_assert(GameFlow.selected_character_id == carousel.CHARACTER_DEFINITIONS[1].id and presenter.current_definition == carousel.CHARACTER_DEFINITIONS[1], "Settled detent did not atomically update identity data.")
	_assert(presenter.values_are_at_zero() and _only_visual_is_visible(carousel, 1), "New focus did not reset stats/model at settlement.")
	_assert(_is_exact_detent(carousel, 1), "Right rotation stopped between indexed detents.")

	# One in-flight request plus at most one queued request is accepted.
	_assert(carousel.request_rotation(1), "Rapid rotation fixture could not start.")
	_assert(carousel.request_rotation(-1) and carousel.queued_step_count() == 1, "One bounded opposing request was not queued.")
	_assert(not carousel.request_rotation(1) and carousel.queued_step_count() == 1, "Carousel accepted more than one queued request.")
	carousel.advance_for_test(carousel.rotation_duration)
	_assert(carousel.current_index == 2 and carousel.is_rotating, "First rapid request did not settle before the queued request began.")
	_assert(_is_exact_detent(carousel, 2), "First queued sequence detent accumulated rotation drift.")
	carousel.advance_for_test(carousel.rotation_duration)
	_assert(carousel.current_index == 1 and not carousel.is_rotating and _is_exact_detent(carousel, 1), "Queued opposing request did not settle exactly once.")

	# The visible arrow follows the same request path, then left wraparound reaches 3.
	presenter.right_arrow.pressed.emit()
	carousel.advance_for_test(carousel.rotation_duration)
	_assert(carousel.current_index == 2, "Visible arrow did not use carousel rotation behavior.")
	_assert(carousel.request_rotation(-1), "Could not return from arrow fixture.")
	carousel.advance_for_test(carousel.rotation_duration)
	_assert(carousel.request_rotation(-1), "Could not reach first detent for wrap fixture.")
	carousel.advance_for_test(carousel.rotation_duration)
	_assert(carousel.current_index == 0, "Carousel did not return to first detent.")
	_assert(carousel.request_rotation(-1), "Left wrap request was rejected.")
	carousel.advance_for_test(carousel.rotation_duration)
	_assert(carousel.current_index == 3 and _is_exact_detent(carousel, 3), "Left navigation did not wrap to the fourth exact detent.")

	var index_before_panel_click := carousel.current_index
	_assert(not carousel.request_panel_selection(1) and carousel.current_index == index_before_panel_click, "Side panel acted as a clickable character choice.")
	_assert(presenter.left_arrow.custom_minimum_size.x >= 56.0 and presenter.right_arrow.custom_minimum_size.y >= 56.0, "Arrow touch targets are smaller than 56 logical pixels.")
	_assert(presenter.left_arrow.get_script().resource_path.ends_with("GestureBlockingButton.gd"), "Arrow controls do not cancel InputRouter touch gestures.")

	presenter.advance_for_test(presenter.stat_animation_duration)
	_assert(presenter.values_reached_targets(), "Fourth-character stats did not reach their targets.")
	_assert(presenter.replay_stats() and presenter.values_are_at_zero(), "Dev stat replay did not reset all six values.")
	presenter.advance_for_test(presenter.stat_animation_duration)
	_assert(presenter.values_reached_targets(), "Replayed stats did not return to configured targets.")

	for viewport_size: Vector2 in [Vector2(960, 720), Vector2(844, 390), Vector2(360, 640)]:
		var snapshot := presenter.layout_snapshot(viewport_size)
		_assert(snapshot.mandatory_inside, "Player Select controls leave the safe composition at %s." % viewport_size)
	_assert(presenter.layout_snapshot(Vector2(360, 640)).narrow, "Narrow phone did not select the stacked Player Select layout.")
	_validate_stats_are_presentation_only()

	if OS.get_cmdline_user_args().has("--capture-narrow"):
		reveal.apply_composition_size(Vector2(360, 640))
		await RenderingServer.frame_post_draw
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build"))
		get_viewport().get_texture().get_image().save_png("res://build/task25_player_select_narrow.png")
	elif OS.get_cmdline_user_args().has("--capture"):
		await RenderingServer.frame_post_draw
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build"))
		get_viewport().get_texture().get_image().save_png("res://build/task25_player_select.png")

	var selected_before_confirm := GameFlow.selected_character_id
	InputRouter.request_intent(InputRouter.INTENT_CONFIRM)
	_assert(GameFlow.current_state == GameFlow.CHARACTER_CONFIRMED and carousel.confirmation_accepted, "Confirm did not enter CHARACTER_CONFIRMED exactly once.")
	_assert(GameFlow.selected_character_id == selected_before_confirm, "Confirm changed the centered stable identity.")
	_assert(not carousel.confirm_selection() and not carousel.request_rotation(1), "Confirmed selection accepted additional input.")
	_assert(reveal.logo_assembly.get_instance_id() == original_logo_id, "Confirmation replaced the continuous logo object.")

	reveal.queue_free()
	if failures.is_empty():
		print("TASK25_PASS")
		get_tree().quit(0)
	else:
		for failure_message: String in failures:
			push_error(failure_message)
		get_tree().quit(1)


func _visuals_are_anchor_bound(carousel: LogoCarouselController) -> bool:
	for index: int in carousel.character_visuals.size():
		var visual := carousel.character_visuals[index]
		if visual.get_parent() != carousel.panel_anchors[index] or not visual.matches_definition(carousel.CHARACTER_DEFINITIONS[index]):
			return false
	return true


func _only_visual_is_visible(carousel: LogoCarouselController, expected_index: int) -> bool:
	for index: int in carousel.character_visuals.size():
		if carousel.character_visuals[index].visible != (index == expected_index):
			return false
	return true


func _is_exact_detent(carousel: LogoCarouselController, index: int) -> bool:
	var expected := fposmod(LogoRevealController.ENTRY_DETENT_RADIANS + float(index) * LogoRevealController.DETENT_STEP_RADIANS, TAU)
	return is_equal_approx(carousel.normalized_detent_angle(), expected)


func _validate_stats_are_presentation_only() -> void:
	for root_path: String in GAMEPLAY_DEPENDENCY_ROOTS:
		_scan_gameplay_source(root_path)


func _scan_gameplay_source(root_path: String) -> void:
	var directory := DirAccess.open(root_path)
	_assert(directory != null, "Could not inspect gameplay dependency root %s." % root_path)
	if directory == null:
		return
	directory.list_dir_begin()
	var entry := directory.get_next()
	while not entry.is_empty():
		var path := root_path.path_join(entry)
		if directory.current_is_dir():
			if not entry.begins_with("."):
				_scan_gameplay_source(path)
		elif entry.get_extension() == "gd":
			var source := FileAccess.get_file_as_string(path)
			_assert(source.find("decorative_stats") == -1 and source.find("decorative_category_value") == -1, "Gameplay code consumes Player Select values: %s" % path)
		entry = directory.get_next()
	directory.list_dir_end()


func _assert(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
