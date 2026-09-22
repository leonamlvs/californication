extends Node

## The only authority allowed to change global frontend/run state.
signal state_changed(previous_state: StringName, next_state: StringName)
signal transition_rejected(from_state: StringName, requested_state: StringName, reason: String)
signal selected_character_changed(character_id: StringName, selection_index: int)
signal run_reset_requested(target_scenario: StringName)
signal input_consumed(intent: StringName, state: StringName)

const BOOT: StringName = &"BOOT"
const LOADING: StringName = &"LOADING"
const ISLAND_INTRO: StringName = &"ISLAND_INTRO"
const ISLAND_ATTRACT: StringName = &"ISLAND_ATTRACT"
const LOGO_REVEAL: StringName = &"LOGO_REVEAL"
const CHARACTER_SELECT_ENTER: StringName = &"CHARACTER_SELECT_ENTER"
const CHARACTER_SELECT_ACTIVE: StringName = &"CHARACTER_SELECT_ACTIVE"
const CHARACTER_CONFIRMED: StringName = &"CHARACTER_CONFIRMED"
const RUN_INTRO: StringName = &"RUN_INTRO"
const RUNNING: StringName = &"RUNNING"
const PAUSED: StringName = &"PAUSED"
const FAILURE_TRANSITION: StringName = &"FAILURE_TRANSITION"
const LAVA_GAME_OVER: StringName = &"LAVA_GAME_OVER"
const TRY_AGAIN: StringName = &"TRY_AGAIN"

const TRANSITION_READY: StringName = &"TRANSITION_READY"
const TOKEN_COLLECTED: StringName = &"TOKEN_COLLECTED"
const SCENARIO_TRANSITION: StringName = &"SCENARIO_TRANSITION"
const NEXT_SCENARIO: StringName = &"NEXT_SCENARIO"

const PLACEHOLDER_CHARACTER_IDS: Array[StringName] = [&"placeholder_01", &"placeholder_02", &"placeholder_03", &"placeholder_04"]
const BOULEVARD_ID: StringName = &"boulevard"

const ALLOWED_TRANSITIONS: Dictionary[StringName, Array] = {
	BOOT: [LOADING],
	LOADING: [ISLAND_INTRO],
	ISLAND_INTRO: [ISLAND_ATTRACT],
	ISLAND_ATTRACT: [LOGO_REVEAL],
	LOGO_REVEAL: [CHARACTER_SELECT_ENTER],
	CHARACTER_SELECT_ENTER: [CHARACTER_SELECT_ACTIVE],
	CHARACTER_SELECT_ACTIVE: [CHARACTER_CONFIRMED],
	CHARACTER_CONFIRMED: [RUN_INTRO],
	RUN_INTRO: [RUNNING],
	RUNNING: [PAUSED, FAILURE_TRANSITION, TRANSITION_READY],
	TRANSITION_READY: [PAUSED, FAILURE_TRANSITION, TOKEN_COLLECTED],
	TOKEN_COLLECTED: [SCENARIO_TRANSITION],
	SCENARIO_TRANSITION: [NEXT_SCENARIO],
	NEXT_SCENARIO: [RUNNING],
	PAUSED: [RUNNING, TRANSITION_READY, ISLAND_ATTRACT],
	FAILURE_TRANSITION: [LAVA_GAME_OVER],
	LAVA_GAME_OVER: [TRY_AGAIN],
	TRY_AGAIN: [RUN_INTRO, ISLAND_ATTRACT],
}

var current_state: StringName = BOOT
var selected_character_id: StringName = PLACEHOLDER_CHARACTER_IDS[0]
var selected_character_index := 0
var intro_seen := false
var prepared_run_target: StringName = &""
var gameplay_input_enabled := false
var run_timer_enabled := false
var _entry_input_locked := false
var _paused_from_state: StringName = RUNNING


func _ready() -> void:
	call_deferred("_connect_input_router")


func _connect_input_router() -> void:
	if not InputRouter.intent_requested.is_connected(handle_intent):
		InputRouter.intent_requested.connect(handle_intent)


func begin_session() -> bool:
	return request_transition(LOADING)


func request_transition(next_state: StringName) -> bool:
	if next_state == current_state:
		_reject(next_state, "State is already active.")
		return false
	if not ALLOWED_TRANSITIONS.has(current_state) or not ALLOWED_TRANSITIONS[current_state].has(next_state):
		_reject(next_state, "Transition is not allowed by the state graph.")
		return false
	_set_state(next_state)
	return true


## Handles at most one state-approved intent. Device normalization remains InputRouter's job.
func handle_intent(intent: StringName) -> bool:
	if _entry_input_locked:
		return false
	var handled := false
	match current_state:
		ISLAND_ATTRACT:
			if intent == InputRouter.INTENT_CONFIRM:
				handled = request_transition(LOGO_REVEAL)
		CHARACTER_SELECT_ENTER:
			if intent == InputRouter.INTENT_CONFIRM:
				handled = request_transition(CHARACTER_SELECT_ACTIVE)
		CHARACTER_SELECT_ACTIVE:
			if intent == InputRouter.INTENT_LEFT:
				handled = select_character_offset(-1)
			elif intent == InputRouter.INTENT_RIGHT:
				handled = select_character_offset(1)
			elif intent == InputRouter.INTENT_CONFIRM:
				handled = request_transition(CHARACTER_CONFIRMED)
		RUNNING, TRANSITION_READY:
			if intent == InputRouter.INTENT_PAUSE:
				handled = pause_run()
		PAUSED:
			if intent == InputRouter.INTENT_PAUSE or intent == InputRouter.INTENT_BACK:
				handled = resume_run()
		LAVA_GAME_OVER:
			if intent == InputRouter.INTENT_CONFIRM:
				handled = choose_game_over(true)
			elif intent == InputRouter.INTENT_BACK:
				handled = choose_game_over(false)
	if handled:
		input_consumed.emit(intent, current_state)
		_lock_entry_input()
	return handled


## UI placeholder stages use this to traverse only their state-approved edge.
func advance_placeholder() -> bool:
	match current_state:
		LOADING:
			return request_transition(ISLAND_INTRO)
		ISLAND_INTRO:
			intro_seen = true
			return request_transition(ISLAND_ATTRACT)
		ISLAND_ATTRACT:
			return request_transition(LOGO_REVEAL)
		LOGO_REVEAL:
			return request_transition(CHARACTER_SELECT_ENTER)
		CHARACTER_SELECT_ENTER:
			return request_transition(CHARACTER_SELECT_ACTIVE)
		CHARACTER_SELECT_ACTIVE:
			return request_transition(CHARACTER_CONFIRMED)
		CHARACTER_CONFIRMED:
			return start_new_run()
		FAILURE_TRANSITION:
			return request_transition(LAVA_GAME_OVER)
		LAVA_GAME_OVER:
			return request_transition(TRY_AGAIN)
	return false


func select_character_offset(offset: int) -> bool:
	if current_state != CHARACTER_SELECT_ACTIVE or offset == 0:
		return false
	selected_character_index = posmod(selected_character_index + offset, PLACEHOLDER_CHARACTER_IDS.size())
	selected_character_id = PLACEHOLDER_CHARACTER_IDS[selected_character_index]
	selected_character_changed.emit(selected_character_id, selected_character_index)
	return true


func set_selected_character(character_id: StringName) -> bool:
	if current_state != CHARACTER_SELECT_ACTIVE or character_id.is_empty():
		return false
	selected_character_id = character_id
	var known_index := PLACEHOLDER_CHARACTER_IDS.find(character_id)
	if known_index >= 0:
		selected_character_index = known_index
	selected_character_changed.emit(selected_character_id, selected_character_index)
	return true


## Pause is allowed to change cosmetics without re-entering frontend selection.
func set_paused_character(character_id: StringName, selection_index: int) -> bool:
	if current_state != PAUSED or character_id.is_empty():
		return false
	selected_character_id = character_id
	selected_character_index = clampi(selection_index, 0, PLACEHOLDER_CHARACTER_IDS.size() - 1)
	selected_character_changed.emit(selected_character_id, selected_character_index)
	return true


func start_new_run() -> bool:
	if current_state != CHARACTER_CONFIRMED and current_state != TRY_AGAIN:
		return false
	prepared_run_target = BOULEVARD_ID
	gameplay_input_enabled = false
	run_timer_enabled = false
	run_reset_requested.emit(prepared_run_target)
	return request_transition(RUN_INTRO)


## Future RunIntroController must call this only after both handoff barriers are true.
func report_run_intro_ready(camera_settled: bool, gameplay_ready: bool) -> bool:
	if current_state != RUN_INTRO or not camera_settled or not gameplay_ready:
		return false
	return request_transition(RUNNING)


func pause_run() -> bool:
	if current_state != RUNNING and current_state != TRANSITION_READY:
		return false
	_paused_from_state = current_state
	return request_transition(PAUSED)


func resume_run() -> bool:
	if current_state != PAUSED:
		return false
	var resume_target := _paused_from_state
	if resume_target != RUNNING and resume_target != TRANSITION_READY:
		resume_target = RUNNING
	return request_transition(resume_target)


func fail_run() -> bool:
	if current_state != RUNNING and current_state != TRANSITION_READY:
		return false
	return request_transition(FAILURE_TRANSITION)


func mark_transition_ready() -> bool:
	return current_state == RUNNING and request_transition(TRANSITION_READY)


func report_transition_token_collected() -> bool:
	return current_state == TRANSITION_READY and request_transition(TOKEN_COLLECTED)


func begin_scenario_transition() -> bool:
	return current_state == TOKEN_COLLECTED and request_transition(SCENARIO_TRANSITION)


func begin_next_scenario() -> bool:
	return current_state == SCENARIO_TRANSITION and request_transition(NEXT_SCENARIO)


func complete_scenario_handoff() -> bool:
	return current_state == NEXT_SCENARIO and request_transition(RUNNING)


## Development harness entry point. Production systems must use the legal graph.
func development_jump_to_state(state: StringName) -> bool:
	if not _all_states().has(state):
		_reject(state, "Unknown development state.")
		return false
	if state == current_state:
		return true
	_set_state(state)
	return true


func choose_try_again(yes: bool) -> bool:
	if current_state != TRY_AGAIN:
		return false
	if yes:
		return start_new_run()
	return request_transition(ISLAND_ATTRACT)


func choose_game_over(yes: bool) -> bool:
	if current_state != LAVA_GAME_OVER or not request_transition(TRY_AGAIN):
		return false
	return choose_try_again(yes)


func exit_run() -> bool:
	if current_state != PAUSED:
		return false
	_paused_from_state = RUNNING
	return request_transition(ISLAND_ATTRACT)


func _set_state(next_state: StringName) -> void:
	var previous_state := current_state
	current_state = next_state
	gameplay_input_enabled = current_state == RUNNING or current_state == TRANSITION_READY
	run_timer_enabled = current_state == RUNNING or current_state == TRANSITION_READY
	state_changed.emit(previous_state, current_state)


func _all_states() -> Array[StringName]:
	return [
		BOOT, LOADING, ISLAND_INTRO, ISLAND_ATTRACT, LOGO_REVEAL,
		CHARACTER_SELECT_ENTER, CHARACTER_SELECT_ACTIVE, CHARACTER_CONFIRMED,
		RUN_INTRO, RUNNING, TRANSITION_READY, TOKEN_COLLECTED,
		SCENARIO_TRANSITION, NEXT_SCENARIO, PAUSED, FAILURE_TRANSITION,
		LAVA_GAME_OVER, TRY_AGAIN,
	]


func _lock_entry_input() -> void:
	_entry_input_locked = true
	call_deferred("_unlock_entry_input")


func _unlock_entry_input() -> void:
	_entry_input_locked = false


func _reject(requested_state: StringName, reason: String) -> void:
	transition_rejected.emit(current_state, requested_state, reason)
