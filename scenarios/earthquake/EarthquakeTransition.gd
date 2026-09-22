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
	proxy.position=Vector3(lerpf(0,2,p),0.9+5*sin(p*PI),lerpf(2,-14,p)); car.position=Vector3(0,0,-10*p)
