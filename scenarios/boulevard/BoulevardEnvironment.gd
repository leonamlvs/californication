class_name BoulevardEnvironment
extends Node3D

## Physical gameplay lanes are centered on the sidewalk; the road is visual-only.
@export_range(0.1, 10.0, 0.1, "suffix:m") var sidewalk_half_width := 2.6
@export_range(0.1, 10.0, 0.1, "suffix:m") var traffic_start_x := 3.2
@export_range(1, 8, 1) var lane_count := 3
@export_range(0.1, 5.0, 0.1, "suffix:m") var lane_spacing := 1.6


func lane_x(lane_index: int) -> float:
	return (float(lane_index) - float(lane_count - 1) * 0.5) * lane_spacing


func is_lane_on_sidewalk(lane_index: int, runner_half_width: float = 0.38) -> bool:
	return lane_index >= 0 and lane_index < lane_count and absf(lane_x(lane_index)) + runner_half_width <= sidewalk_half_width
