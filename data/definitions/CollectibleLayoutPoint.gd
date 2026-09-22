class_name CollectibleLayoutPoint
extends Resource

@export_range(0, 2, 1) var lane := 1
@export_range(0.0, 1000.0, 0.05, "suffix:m") var forward_offset := 0.0
## Required runner-origin height; zero is a normal ground-path pickup.
@export_range(0.0, 4.0, 0.05, "suffix:m") var runner_height := 0.0


func is_valid(layout_length: float, lane_count: int = 3) -> bool:
	return lane >= 0 and lane < lane_count and forward_offset >= 0.0 and forward_offset <= layout_length
