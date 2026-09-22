extends Node
const E:=preload("res://data/scenarios/earthquake.tres")
const T:=preload("res://scenarios/earthquake/EarthquakeTransition.tscn")
func _ready()->void:
	var c:=T.instantiate() as ScenarioTransitionController; add_child(c); c.start({}); c._process(.6); c._process(.6); c._process(.6); c._process(.6); c._process(.3); var ok:bool=E.is_valid_definition() and E.movement_mode==&"RUN" and c.get("stage_history").size()>=5
	print("Task 17 Earthquake test passed.") if ok else printerr("Earthquake failed"); get_tree().quit(0 if ok else 1)
