class_name GoldenGateCableTransition
extends ScenarioTransitionController
enum Stage { LEAVE_CAR, LAND_SNOWBOARD, GRIND_CABLE, LAUNCH }
@onready var proxy: MeshInstance3D = %Proxy
@onready var car: MeshInstance3D = %Car
@onready var snowboard: MeshInstance3D = %Snowboard
@onready var cable: MeshInstance3D = %Cable
var current_stage: Stage = Stage.LEAVE_CAR
var stage_history: Array[Stage] = []
func start(c: Dictionary) -> void:
	super.start(c); current_stage = Stage.LEAVE_CAR; stage_history=[current_stage]; proxy.position=Vector3(0,0.9,2); car.visible=true; snowboard.visible=false; cable.visible=false
func _process(delta: float) -> void:
	if is_running: _route()
	super._process(delta)
func _route() -> void:
	var p:=clampf(_elapsed/duration,0,1)
	if p < .22:
		_stage(Stage.LEAVE_CAR); proxy.position=Vector3(0,.9,lerpf(2,-1,p/.22))
	elif p < .42:
		_stage(Stage.LAND_SNOWBOARD); car.visible=false; snowboard.visible=true; proxy.position=Vector3(0,.9,-3)
	elif p < .78:
		_stage(Stage.GRIND_CABLE); cable.visible=true; snowboard.visible=true; proxy.position=Vector3(0,lerpf(.9,4,(p-.42)/.36),lerpf(-3,-9,(p-.42)/.36))
	else:
		_stage(Stage.LAUNCH); cable.visible=false; proxy.position=Vector3(lerpf(0,2,(p-.78)/.22),4+2*sin((p-.78)/.22*PI),lerpf(-9,-13,(p-.78)/.22))
func _stage(s: Stage)->void:
	if current_stage != s: current_stage=s; stage_history.append(s)
