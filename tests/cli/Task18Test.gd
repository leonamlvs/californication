extends Node
const B:=preload("res://data/scenarios/boulevard.tres")
const S:=preload("res://data/scenarios/sierra_nevada.tres")
const Y:=preload("res://data/scenarios/san_francisco_bay.tres")
const Q:=preload("res://data/scenarios/sequoia.tres")
const F:=preload("res://data/scenarios/filming_sets.tres")
const G:=preload("res://data/scenarios/golden_gate.tres")
const H:=preload("res://data/scenarios/hollywood.tres")
const R:=preload("res://data/scenarios/grass.tres")
const E:=preload("res://data/scenarios/earthquake.tres")
func _ready()->void:
	ScenarioManager.reset_for_tests(); var root:=Node3D.new(); add_child(root); ScenarioManager.set_scenario_root(root)
	for d in [B,S,Y,Q,F,G,H,R,E]: ScenarioManager.register_scenario(d)
	var ok:=ScenarioManager.production_scenario_ids().size()==9 and ScenarioManager.begin_production_run(18) and ScenarioManager.active_scenario_id==&"boulevard"
	print("Task 18 runtime hardening test passed.") if ok else printerr("runtime hardening failed"); get_tree().quit(0 if ok else 1)
