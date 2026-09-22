class_name FrontendSafeComposition
extends Control

## Guide-only layout contract for later island/logo/carousel/run-intro cameras.
const HORIZONTAL_MARGIN_RATIO := 0.06
const VERTICAL_MARGIN_RATIO := 0.08

@onready var safe_region: Control = %SafeRegion


func _ready() -> void:
	resized.connect(_layout_guides)
	_layout_guides()


func get_safe_rect() -> Rect2:
	return Rect2(safe_region.position, safe_region.size)


func mandatory_guides_fit() -> bool:
	var safe_rect := get_safe_rect()
	for guide_name in [&"IslandGuide", &"LogoGuide", &"CharacterGuide", &"StatsGuide", &"TitleGuide", &"LeftArrowGuide", &"RightArrowGuide"]:
		var guide := get_node_or_null(NodePath("SafeRegion/%s" % guide_name)) as Control
		if guide == null or not safe_rect.encloses(Rect2(safe_region.position + guide.position, guide.size)):
			return false
	return true


func _layout_guides() -> void:
	var margin := Vector2(size.x * HORIZONTAL_MARGIN_RATIO, size.y * VERTICAL_MARGIN_RATIO)
	safe_region.position = margin
	safe_region.size = (size - margin * 2.0).max(Vector2.ONE)
	_place(%IslandGuide, Rect2(0.18, 0.16, 0.64, 0.56))
	_place(%LogoGuide, Rect2(0.17, 0.12, 0.66, 0.34))
	_place(%CharacterGuide, Rect2(0.34, 0.25, 0.32, 0.60))
	_place(%StatsGuide, Rect2(0.68, 0.46, 0.27, 0.34))
	_place(%TitleGuide, Rect2(0.24, 0.05, 0.52, 0.12))
	_place(%LeftArrowGuide, Rect2(0.03, 0.47, 0.12, 0.16), Vector2(56.0, 56.0))
	_place(%RightArrowGuide, Rect2(0.85, 0.47, 0.12, 0.16), Vector2(56.0, 56.0))


func _place(guide: Control, normalized_rect: Rect2, minimum_size := Vector2.ZERO) -> void:
	guide.position = safe_region.size * normalized_rect.position
	guide.size = (safe_region.size * normalized_rect.size).max(minimum_size)
	guide.position.x = minf(guide.position.x, safe_region.size.x - guide.size.x)
	guide.position.y = minf(guide.position.y, safe_region.size.y - guide.size.y)
