class_name RunStats
extends Node

## Owns ordinary run metrics. Transition bonuses are intentionally deferred to Task 08.
signal metrics_changed(score: int, elapsed_seconds: float, active_distance: float)
signal pickup_awarded(amount: int)

@export_range(0, 100, 1, "suffix: pts/m") var points_per_meter := 10
@export_range(0, 1000, 1, "suffix: pts") var pickup_points := 100

var score := 0
var elapsed_seconds := 0.0
var active_distance := 0.0
var pickup_score := 0
var _last_logical_distance := 0.0


func reset_for_fresh_run(start_distance: float = 0.0) -> void:
	score = 0
	elapsed_seconds = 0.0
	active_distance = 0.0
	pickup_score = 0
	_last_logical_distance = start_distance
	_emit_metrics()


func step_simulation(delta: float, logical_distance: float, run_active: bool) -> void:
	var distance_delta := maxf(0.0, logical_distance - _last_logical_distance)
	_last_logical_distance = logical_distance
	if not run_active or delta <= 0.0:
		return
	active_distance += distance_delta
	elapsed_seconds += delta
	_refresh_distance_score()
	_emit_metrics()


func award_normal_pickup() -> void:
	pickup_score += pickup_points
	_refresh_distance_score()
	pickup_awarded.emit(pickup_points)
	_emit_metrics()


func formatted_time() -> String:
	var total_seconds: int = maxi(0, floori(elapsed_seconds))
	var hours: int = total_seconds / 3600
	var minutes: int = (total_seconds % 3600) / 60
	var seconds: int = total_seconds % 60
	return "%02d:%02d:%02d" % [hours, minutes, seconds]


func _refresh_distance_score() -> void:
	score = floori(active_distance * points_per_meter) + pickup_score


func _emit_metrics() -> void:
	metrics_changed.emit(score, elapsed_seconds, active_distance)
