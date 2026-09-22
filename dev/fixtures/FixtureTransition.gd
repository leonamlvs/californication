extends ScenarioTransitionController

@onready var marker: MeshInstance3D = %Marker


func start(transition_context: Dictionary) -> void:
	super.start(transition_context)
	marker.rotation = Vector3.ZERO


func _process(delta: float) -> void:
	if is_running:
		marker.rotation.y += delta * 2.0
	super._process(delta)
