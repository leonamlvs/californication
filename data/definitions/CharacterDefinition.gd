class_name CharacterDefinition
extends Resource
@export var id:StringName
@export var display_name:String=""
@export var category_label:String=""
@export var category_value:String=""
@export var decorative_stats:Dictionary={}
@export var gameplay_cosmetic_scene:PackedScene
@export var frontend_presentation_scene:PackedScene
@export var frontend_idle_key:StringName=&"idle"
@export var pause_portrait:Texture2D
func is_valid_definition()->bool:
	return not id.is_empty() and not display_name.is_empty() and gameplay_cosmetic_scene!=null and frontend_presentation_scene!=null
