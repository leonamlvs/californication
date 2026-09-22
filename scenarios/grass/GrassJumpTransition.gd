class_name GrassJumpTransition
extends ScenarioTransitionController
@onready var proxy:MeshInstance3D=%Proxy
func start(c:Dictionary)->void: super.start(c); proxy.position=Vector3(0,.9,2)
func _process(d:float)->void:
	if is_running:
		var p:=clampf(_elapsed/duration,0,1); proxy.position=Vector3(lerpf(0,2,p),.9+7*sin(p*PI),lerpf(2,-13,p))
	super._process(d)
