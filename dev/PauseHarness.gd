extends Control

const PREVIEW_SIZES := {
	"desktop": Vector2(960, 720),
	"landscape": Vector2(844, 390),
	"narrow": Vector2(360, 640),
}

@onready var preview_frame: Control = %PreviewFrame
@onready var hud: RunnerHUD = %HUD


func _ready() -> void:
	var stats := RunStats.new()
	add_child(stats)
	stats.reset_for_fresh_run()
	stats.award_normal_pickup()
	stats.step_simulation(125.0, 42.0, true)
	hud.bind_run_stats(stats)
	GameFlow.development_jump_to_state(GameFlow.RUNNING)
	GameFlow.pause_run()
	var preview_name := "desktop"
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--preview="):
			preview_name = argument.trim_prefix("--preview=")
	set_preview(preview_name)


func set_preview(preview_name: String) -> void:
	var preview_size: Vector2 = PREVIEW_SIZES.get(preview_name, PREVIEW_SIZES.desktop)
	preview_frame.position = (Vector2(960, 720) - preview_size) * 0.5
	preview_frame.size = preview_size
	hud.apply_available_size(preview_size)
