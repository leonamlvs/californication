extends Control

const PREVIEWS := [
	{"name": "Desktop 960 x 720", "size": Vector2(960, 720), "touch": false, "insets": Vector4.ZERO},
	{"name": "Wide desktop 1600 x 900", "size": Vector2(1600, 900), "touch": false, "insets": Vector4.ZERO},
	{"name": "Tablet 1024 x 768", "size": Vector2(1024, 768), "touch": true, "insets": Vector4.ZERO},
	{"name": "Landscape phone 844 x 390", "size": Vector2(844, 390), "touch": true, "insets": Vector4.ZERO},
	{"name": "Narrow phone 360 x 640", "size": Vector2(360, 640), "touch": true, "insets": Vector4.ZERO},
	{"name": "Safe inset 390 x 844", "size": Vector2(390, 844), "touch": true, "insets": Vector4(20, 30, 20, 30)},
]

@onready var presentation: PresentationRoot = %PresentationPreview
@onready var profile_label: Label = %ProfileLabel
@onready var picker: OptionButton = %PreviewPicker


func _ready() -> void:
	presentation.frontend_safe_guide.visible = true
	for preview: Dictionary in PREVIEWS:
		picker.add_item(preview.name)
	picker.item_selected.connect(_apply_preview)
	_apply_preview(0)


func _apply_preview(index: int) -> void:
	var preview: Dictionary = PREVIEWS[index]
	var snapshot := presentation.preview_layout(preview.size, preview.touch, preview.insets)
	profile_label.text = "%s\nFrame: %s\nProfile: %s" % [preview.name, snapshot.frame_rect.size, _profile_name(snapshot.hud_profile)]


func _profile_name(profile: int) -> String:
	return ["FULL", "MEDIUM", "COMPACT"][profile]
