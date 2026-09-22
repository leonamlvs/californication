extends Control

@onready var last_intent_label: Label = %LastIntentLabel


func _ready() -> void:
	InputRouter.intent_requested.connect(_on_intent_requested)


func _exit_tree() -> void:
	if InputRouter.intent_requested.is_connected(_on_intent_requested):
		InputRouter.intent_requested.disconnect(_on_intent_requested)


func _on_intent_requested(intent: StringName) -> void:
	last_intent_label.text = "Last intent: %s" % intent
