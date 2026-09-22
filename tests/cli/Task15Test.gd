extends Node
const H:=preload("res://data/scenarios/hollywood.tres")
const R:=preload("res://gameplay/runner/Runner.tscn")
const T:=preload("res://scenarios/hollywood/HollywoodAerialTransition.tscn")
const S:=preload("res://scenarios/hollywood/HollywoodAerialTransition.gd")
var bad=false
func _ready()->void:
	var r:=R.instantiate() as RunnerController; add_child(r); r.movement_profile=H.movement_profile; ok(r.set_movement_mode(&"FLY"),"mode"); r.reset_for_run(); ok(r.request_left() and r.request_up(),"left/up"); r.step_simulation(.1); ok(r.position.x<0 and r.position.y>0,"3d rise"); ok(r.request_right() and r.request_down(),"right/down"); r.step_simulation(.2); ok(r.position.y<0 and r.position.y>=-H.movement_profile.vertical_dive_offset-0.001,"dive bounds"); r.step_simulation(2); ok(is_zero_approx(r.position.y),"neutral"); ok(H.is_valid_definition() and H.movement_capability_profile.supports_rise and H.movement_capability_profile.supports_dive,"definition"); var cine:=T.instantiate() as ScenarioTransitionController; add_child(cine); cine.start({})
	cine._process(.9)
	cine._process(.9)
	cine._process(.4)
	cine._process(.1)
	ok(cine.get("stage_history")==[S.Stage.BOARD_CRAFT,S.Stage.SCREW_CLIMB,S.Stage.DESCENT],"aerial stages"); print("Task 15 Hollywood / FLY test passed.") if not bad else printerr("Task15 failed"); get_tree().quit(1 if bad else 0)
func ok(x:bool,m:String)->void:
	if not x: bad=true; printerr(m)
