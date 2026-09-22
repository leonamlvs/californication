extends Node

## Composition root only. Gameplay, UI behavior, and flow are added in later tasks.
@onready var presentation_root: Node = $PresentationRoot
@onready var world: Node3D = $PresentationRoot/World
@onready var frontend_layer: CanvasLayer = $PresentationRoot/FrontendLayer
@onready var overlay_layer: CanvasLayer = $PresentationRoot/OverlayLayer


func _ready() -> void:
	# Keeping this root intentionally passive makes future systems explicit owners.
	process_mode = Node.PROCESS_MODE_ALWAYS
