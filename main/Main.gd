extends Node

const BOULEVARD := preload("res://data/scenarios/boulevard.tres")
const SIERRA := preload("res://data/scenarios/sierra_nevada.tres")
const BAY := preload("res://data/scenarios/san_francisco_bay.tres")
const SEQUOIA := preload("res://data/scenarios/sequoia.tres")
const FILMING_SETS := preload("res://data/scenarios/filming_sets.tres")
const GOLDEN_GATE := preload("res://data/scenarios/golden_gate.tres")
const HOLLYWOOD := preload("res://data/scenarios/hollywood.tres")
const GRASS := preload("res://data/scenarios/grass.tres")
const EARTHQUAKE := preload("res://data/scenarios/earthquake.tres")

@onready var presentation_root: PresentationRoot = $PresentationRoot
@onready var world: Node3D = $PresentationRoot/GameFrame/WorldContainer/GameViewport/World
@onready var frontend_layer: Control = $PresentationRoot/GameFrame/FrontendLayer
@onready var overlay_layer: Control = $PresentationRoot/GameFrame/OverlayLayer
@onready var runner: RunnerController = $PresentationRoot/GameFrame/WorldContainer/GameViewport/World/Runner
@onready var generator: TrackGenerator = $PresentationRoot/GameFrame/WorldContainer/GameViewport/World/TrackGenerator
@onready var scenario_root: Node3D = $PresentationRoot/GameFrame/WorldContainer/GameViewport/World/ScenarioRoot
@onready var gameplay_camera: Camera3D = $PresentationRoot/GameFrame/WorldContainer/GameViewport/World/Camera3D
@onready var logo_frontend: LogoRevealController = $PresentationRoot/GameFrame/WorldContainer/GameViewport/World/LogoPresentationRig
@onready var cinematic_fx: CinematicTransitionFX = $PresentationRoot/GameFrame/WorldContainer/GameViewport/World/CinematicTransitionFX
@onready var run_intro: RunIntroController = $PresentationRoot/GameFrame/WorldContainer/GameViewport/World/RunIntroController
@onready var coordinator: TransitionCoordinator = $PresentationRoot/GameFrame/WorldContainer/GameViewport/World/TransitionCoordinator
@onready var hud: RunnerHUD = $PresentationRoot/GameFrame/HUD

var character_presenter: CharacterPresenter


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	ScenarioManager.set_scenario_root(scenario_root)
	for definition: ScenarioDefinition in [BOULEVARD, SIERRA, BAY, SEQUOIA, FILMING_SETS, GOLDEN_GATE, HOLLYWOOD, GRASS, EARTHQUAKE]:
		ScenarioManager.register_scenario(definition)
	character_presenter = CharacterPresenter.new()
	add_child(character_presenter)
	character_presenter.bind_runner(runner)
	hud.bind_run_stats(generator.run_stats)
	run_intro.configure_services(runner, generator, scenario_root, gameplay_camera, logo_frontend, cinematic_fx, character_presenter, hud, coordinator)
