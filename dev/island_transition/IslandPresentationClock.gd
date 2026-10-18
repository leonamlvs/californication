class_name IslandPresentationClock
extends RefCounted

## Pure state machine, usable with real or simulated playback snapshots.
var time := 0.0
var live_tail := false
var _was_active := true


func reset() -> void:
	time = 0.0
	live_tail = false
	_was_active = true


func advance(snapshot: Dictionary, delta: float, active := true) -> float:
	if not active:
		_was_active = false
		return time
	if not _was_active:
		delta = 0.0
	_was_active = true
	if live_tail:
		time += maxf(delta,0.0)
		return time
	var state: String = str(snapshot.get("state", "idle"))
	if state == "ended":
		time = float(snapshot.duration)
		live_tail = true
	elif state in ["preparing", "ready"]:
		# Retry from retained error state restarts the coordinated presentation.
		time = float(snapshot.get("media_time",0.0))
	elif state == "playing":
		# Adapter timestamps are monotonic within a playback generation. A lower
		# timestamp denotes Retry, including one completed between host frames.
		time = float(snapshot.get("media_time",0.0))
	return time
