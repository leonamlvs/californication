extends Node
const GATE := preload("res://data/scenarios/golden_gate.tres")
const FIXTURE := preload("res://dev/fixtures/fixture_scenario_a.tres")
const RUNNER := preload("res://gameplay/runner/Runner.tscn")
const GEN := preload("res://gameplay/track/TrackGenerator.tscn")
const COORD := preload("res://gameplay/transitions/TransitionCoordinator.tscn")
const HUD := preload("res://ui/hud/HUD.tscn")
const SCRIPT := preload("res://scenarios/golden_gate/GoldenGateCableTransition.gd")
var bad=false
func _ready()->void:
	_run(); print("Task 14 Golden Gate / CAR test passed.") if not bad else printerr("Task 14 failed."); get_tree().quit(1 if bad else 0)
func _run()->void:
	_ok(GATE.is_valid_definition(),"Gate invalid")
	_ok(GATE.movement_capability_profile.supports_jump and not GATE.movement_capability_profile.supports_low,"CAR capabilities allow crouch")
	var v:=PatternValidator.new()
	for s: SegmentDefinition in GATE.segment_library:
		for p: PatternDefinition in s.eligible_patterns: _ok(v.validate_pattern(p,GATE.movement_capability_profile,GATE.base_speed,GATE.movement_capability_profile.initial_state_mask()).is_valid,"CAR pattern invalid")
	var r:=RUNNER.instantiate() as RunnerController; add_child(r); r.movement_profile=GATE.movement_profile; _ok(r.set_movement_mode(&"CAR"),"CAR install failed"); r.reset_for_run(); _ok(r.request_right(),"CAR lane failed"); r.step_simulation(.25); _ok(r.current_lane_index==2,"CAR lane bounds"); _ok(r.request_up() and r.is_jumping,"CAR ramp failed"); _ok(not r.request_down(),"CAR accepted Down")
	var root:=Node3D.new(); add_child(root); ScenarioManager.reset_for_tests(); ScenarioManager.set_scenario_root(root); _ok(ScenarioManager.register_scenario(GATE),"register gate"); _ok(ScenarioManager.register_scenario(FIXTURE,true),"register fixture"); _ok(ScenarioManager.load_scenario(GATE.id),"load gate")
	var g:=GEN.instantiate() as TrackGenerator; g.auto_start=false; add_child(g); g.set_runner(r); _ok(g.configure_for_scenario(GATE),"gen config"); g.reset_generator(1414,0,r.current_speed)
	var h:=HUD.instantiate() as RunnerHUD; add_child(h); h.bind_run_stats(g.run_stats)
	var c:=COORD.instantiate() as TransitionCoordinator; add_child(c); c.configure_services(r,g,g.run_stats,h); _ok(c.begin_scenario(GATE,true),"coord"); GameFlow.development_jump_to_state(GameFlow.RUNNING); _ok(c.development_force_token_collection(),"token")
	var cine: ScenarioTransitionController=c.active_cinematic; _ok(cine!=null and r.is_invulnerable and r.movement_suspended and not r.request_left(),"cinematic lock"); _ok(cine.find_children("*","RunnerController",true,false).is_empty(),"second runner")
	for d in [.7,.7,.7,.4,.1]: cine._process(d)
	_ok(cine.get("stage_history")==[SCRIPT.Stage.LEAVE_CAR,SCRIPT.Stage.LAND_SNOWBOARD,SCRIPT.Stage.GRIND_CABLE,SCRIPT.Stage.LAUNCH],"stage order")
	_ok(c.development_force_complete_cinematic() and ScenarioManager.active_scenario_id==FIXTURE.id and c.active_cinematic==null,"handoff")
	ScenarioManager.reset_for_tests()
func _ok(x:bool,msg:String)->void:
	if not x: bad=true; printerr(msg)
