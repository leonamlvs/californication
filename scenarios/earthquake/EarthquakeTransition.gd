class_name EarthquakeTransition
extends ScenarioTransitionController
enum Stage { CAR_ENTRY, HIGH_SPEED, RAMP, DONUT, EJECTION, FALL }
@onready var proxy:MeshInstance3D=%Proxy
@onready var car:MeshInstance3D=%Car
var current_stage:Stage=Stage.CAR_ENTRY
var stage_history:Array[Stage]=[]
func start(c:Dictionary)->void: super.start(c); current_stage=Stage.CAR_ENTRY; stage_history=[current_stage]
func _process(d:float)->void:
	if is_running: _route()
	super._process(d)
func _route()->void:
	var p:=clampf(_elapsed/duration,0,1); var i:=mini(floori(p*6),5) as Stage
	if current_stage!=i: current_stage=i; stage_history.append(i)
	car.visible = p < 0.83
	if p < 0.33:
		car.position = Vector3(0, 0.35, lerpf(2.0, -5.0, p / 0.33))
		proxy.position = car.position + Vector3(0, 0.8, 0)
	elif p < 0.5:
		var ramp := (p - 0.33) / 0.17
		car.position = Vector3(0, lerpf(0.35, 4.4, ramp), lerpf(-5.0, -7.0, ramp))
		proxy.position = car.position + Vector3(0, 0.8, 0)
	elif p < 0.66:
		car.position = Vector3(0, 4.4, lerpf(-7.0, -10.0, (p - 0.5) / 0.16))
		proxy.position = car.position + Vector3(0, 0.8, 0)
	elif p < 0.83:
		var eject := (p - 0.66) / 0.17
		proxy.position = Vector3(eject * 2.0, lerpf(5.2, 7.0, eject), lerpf(-10.0, -12.0, eject))
	else:
		var fall := (p - 0.83) / 0.17
		proxy.position = Vector3(2, lerpf(7.0, -3.0, fall), lerpf(-12.0, -16.0, fall))
