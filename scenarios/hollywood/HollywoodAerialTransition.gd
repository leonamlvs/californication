class_name HollywoodAerialTransition
extends ScenarioTransitionController
enum Stage { BOARD_CRAFT, SCREW_CLIMB, DESCENT }
@onready var proxy: MeshInstance3D=%Proxy
@onready var craft: MeshInstance3D=%Craft
var current_stage:Stage=Stage.BOARD_CRAFT
var stage_history:Array[Stage]=[]
func start(c:Dictionary)->void: super.start(c); current_stage=Stage.BOARD_CRAFT; stage_history=[current_stage]; proxy.position=Vector3(0,.9,2)
func _process(d:float)->void: if is_running: _route(); super._process(d)
func _route()->void:
	var p:=clampf(_elapsed/duration,0,1)
	if p<.3: _stage(Stage.BOARD_CRAFT); proxy.position=Vector3(0,.9,lerpf(2,-2,p/.3))
	elif p<.7: _stage(Stage.SCREW_CLIMB); craft.position=Vector3(0,lerpf(1,6,(p-.3)/.4),lerpf(-2,-8,(p-.3)/.4)); proxy.position=craft.position
	else: _stage(Stage.DESCENT); proxy.position=Vector3(lerpf(0,2,(p-.7)/.3),lerpf(6,-1,(p-.7)/.3),lerpf(-8,-13,(p-.7)/.3))
func _stage(s:Stage)->void: if current_stage!=s: current_stage=s; stage_history.append(s)
