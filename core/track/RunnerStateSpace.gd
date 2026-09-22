class_name RunnerStateSpace
extends RefCounted

## Compact state layout: each posture owns lane_count consecutive bits.
enum Posture { GROUND, JUMP, LOW }


static func state_bit(lane: int, posture: Posture, lane_count: int = 3) -> int:
	if lane < 0 or lane >= lane_count:
		return 0
	return 1 << (int(posture) * lane_count + lane)


static func lane_from_index(state_index: int, lane_count: int = 3) -> int:
	return state_index % lane_count


static func posture_from_index(state_index: int, lane_count: int = 3) -> Posture:
	return (state_index / lane_count) as Posture


static func all_lanes_for_posture(posture: Posture, lane_count: int = 3) -> int:
	var mask := 0
	for lane: int in lane_count:
		mask |= state_bit(lane, posture, lane_count)
	return mask


static func count_states(mask: int) -> int:
	var count := 0
	var remaining := mask
	while remaining != 0:
		count += remaining & 1
		remaining >>= 1
	return count
