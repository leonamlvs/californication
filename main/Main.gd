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
var failure: FailureCoordinator
var camera_rig: GameplayCameraRig


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	generator.set_suspended(true)
	runner.set_movement_suspended(true)
	ScenarioManager.set_scenario_root(scenario_root)
	for definition: ScenarioDefinition in [BOULEVARD, SIERRA, BAY, SEQUOIA, FILMING_SETS, GOLDEN_GATE, HOLLYWOOD, GRASS, EARTHQUAKE]:
		ScenarioManager.register_scenario(definition)
	character_presenter = CharacterPresenter.new()
	add_child(character_presenter)
	character_presenter.bind_runner(runner)
	failure = FailureCoordinator.new()
	add_child(failure)
	failure.configure_services(runner, generator, coordinator)
	camera_rig = GameplayCameraRig.new()
	add_child(camera_rig)
	camera_rig.bind(gameplay_camera, runner)
	var pickup_feedback := PickupFeedback.new()
	pickup_feedback.runner = runner
	world.add_child(pickup_feedback)
	runner.pickup_response.connect(pickup_feedback.burst)
	ScenarioManager.scenario_loaded.connect(_bind_scenario)
	runner.lane_started.connect(func(_lane: int): AudioManager.play_cue(&"lane"))
	runner.action_started.connect(AudioManager.play_cue)
	runner.pickup_response.connect(func(): AudioManager.play_cue(&"pickup"))
	runner.failure_impact.connect(func(): AudioManager.play_cue(&"impact"))
	coordinator.handoff_completed.connect(func(_definition: ScenarioDefinition): AudioManager.play_cue(&"handoff"))
	hud.bind_run_stats(generator.run_stats)
	run_intro.configure_services(runner, generator, scenario_root, gameplay_camera, logo_frontend, cinematic_fx, character_presenter, hud, coordinator)
	run_intro.camera_rig = camera_rig
	coordinator.gameplay_camera = gameplay_camera
	coordinator.camera_rig = camera_rig
	coordinator.character_presenter = character_presenter
	coordinator.cinematic_fx = cinematic_fx
	GameFlow.selected_character_changed.connect(func(_id: StringName, index: int):
		if GameFlow.current_state == GameFlow.PAUSED:
			character_presenter.replace_paused_cosmetic(RunIntroController.CHARACTERS[index])
	)
	GameFlow.begin_session()


func _bind_scenario(definition: ScenarioDefinition) -> void:
	failure.begin_scenario(definition)
	camera_rig.apply_profile(definition.camera_profile as CameraProfile, true)
	AudioManager.set_ambience(definition.ambience_profile)
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = definition.sky_color
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = definition.sky_color.lightened(0.5)
	environment.ambient_light_energy = 0.65
	environment.fog_enabled = true
	environment.fog_light_color = definition.sky_color
	environment.fog_density = 0.003
	gameplay_camera.environment = environment
