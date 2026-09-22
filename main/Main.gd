extends Node

## Composition root only. Gameplay, UI behavior, and flow are added in later tasks.
@onready var presentation_root: PresentationRoot = $PresentationRoot
@onready var world: Node3D = $PresentationRoot/GameFrame/WorldContainer/GameViewport/World
@onready var frontend_layer: Control = $PresentationRoot/GameFrame/FrontendLayer
@onready var overlay_layer: Control = $PresentationRoot/GameFrame/OverlayLayer


func _ready() -> void:
	# Keeping this root intentionally passive makes future systems explicit owners.
	process_mode = Node.PROCESS_MODE_ALWAYS
