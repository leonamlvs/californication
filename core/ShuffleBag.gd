class_name ShuffleBag
extends RefCounted

var _source: Array[StringName] = []
var _remaining: Array[StringName] = []
var _rng := RandomNumberGenerator.new()


func configure(entries: Array[StringName], seed_value: int) -> void:
	_source = entries.duplicate()
	_remaining.clear()
	_rng.seed = seed_value


func reset(seed_value: int) -> void:
	_remaining.clear()
	_rng.seed = seed_value


func draw(current: StringName = &"") -> StringName:
	if _source.is_empty():
		return &""
	if _remaining.is_empty():
		_refill(current)
	return _remaining.pop_back()


func remaining_count() -> int:
	return _remaining.size()


func _refill(current: StringName) -> void:
	_remaining = _source.duplicate()
	for index: int in range(_remaining.size() - 1, 0, -1):
		var swap_index: int = _rng.randi_range(0, index)
		var value: StringName = _remaining[index]
		_remaining[index] = _remaining[swap_index]
		_remaining[swap_index] = value
	if _remaining.size() > 1 and _remaining.back() == current:
		var swap_index: int = _rng.randi_range(0, _remaining.size() - 2)
		var value: StringName = _remaining.back()
		_remaining[_remaining.size() - 1] = _remaining[swap_index]
		_remaining[swap_index] = value
