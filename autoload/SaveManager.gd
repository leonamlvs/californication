extends Node

## Reserved persistence boundary. The MVP currently keeps no saved game state.


func load_session() -> Dictionary:
	return {}


func save_session(_session_data: Dictionary) -> void:
	pass
