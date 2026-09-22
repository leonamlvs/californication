extends Node
const G:=preload("res://data/scenarios/grass.tres")
const P:=preload("res://data/track/grass_readability.tres")
func _ready()->void:
	var ok:=G.is_valid_definition() and P.allows_dense_dressing(30,10) and not P.allows_dense_dressing(10,10)
	print("Task 16 Grass test passed.") if ok else printerr("Grass readability failed")
	get_tree().quit(0 if ok else 1)
