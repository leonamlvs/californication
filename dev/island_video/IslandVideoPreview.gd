extends Control

const Playback = preload("res://frontend/island/video/IslandVideoPlayback.gd")
const MEDIA := "res://dev/island_video/media/"
var player: IslandVideoPlayback
var status: Label
var _callback: JavaScriptObject
var _interface: JavaScriptObject


func _ready() -> void:
	var background := ColorRect.new()
	background.color = Color.BLACK
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	player = Playback.new()
	player.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(player)
	status = Label.new()
	status.position = Vector2(12, 12)
	status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(status)
	resized.connect(_layout)
	_layout()
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.islandPreview = { state: {}, command: null };", true)
		_interface = JavaScriptBridge.get_interface("islandPreview")
		_callback = JavaScriptBridge.create_callback(_web_command)
		_interface.command = _callback
		player.prepare("index.island-intro.mp4", "", "index.poster.png")
		JavaScriptBridge.eval("""
		(() => {
		 const bar = document.createElement('div');
		 bar.id = 'island-preview-controls';
		 Object.assign(bar.style, {position:'fixed',bottom:'8px',left:'8px',zIndex:30,display:'flex',gap:'6px',flexWrap:'wrap'});
		 for (const [label, command] of [['Play','play'],['Pause','pause'],['Replay','restart'],['Release','release']]) {
		   const button = document.createElement('button'); button.textContent = label;
		   button.onclick = event => {event.stopPropagation(); window.islandPreview.command(command);};
		   bar.append(button);
		 }
		 const fullscreen = document.createElement('button'); fullscreen.textContent = 'Fullscreen';
		 fullscreen.onclick = () => document.fullscreenElement ? document.exitFullscreen() : document.documentElement.requestFullscreen();
		 bar.append(fullscreen); document.body.append(bar);
		})();
		""", true)
	else:
		var toolbar := HBoxContainer.new()
		toolbar.position = Vector2(12, 48)
		add_child(toolbar)
		for command: String in ["play", "pause", "restart", "release"]:
			var button := Button.new()
			button.text = command.capitalize()
			button.pressed.connect(_command.bind(command))
			toolbar.add_child(button)
		player.prepare("", MEDIA + "intro.ogv", MEDIA + "poster.png", MEDIA + "last.png")
	player.play()


func _layout() -> void:
	if player != null:
		player.set_picture_rect(Playback.fit_picture(Rect2(Vector2.ZERO, size)))


func _process(_delta: float) -> void:
	if player == null:
		return
	var snapshot := player.snapshot()
	status.text = "Island video preview: %s  %.3f / %.3f" % [snapshot.state, snapshot.media_time, snapshot.duration]
	if _interface != null:
		_interface.state = JSON.stringify(snapshot)


func _web_command(arguments: Array) -> void:
	if not arguments.is_empty():
		_command(str(arguments[0]))


func _exit_tree() -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.eval("document.getElementById('island-preview-controls')?.remove(); delete window.islandPreview;", true)
	_interface = null
	_callback = null


func _command(command: String) -> void:
	match command:
		"play": player.play()
		"pause": player.pause()
		"restart": player.restart()
		"release": player.release()
		"focus_out": player.set_focus_active(false)
		"focus_in": player.set_focus_active(true)
		"opacity_half": player.set_opacity(0.5)
		"opacity_full": player.set_opacity(1.0)
		"missing": player.prepare("missing.mp4", MEDIA + "missing.ogv", "index.poster.png" if OS.has_feature("web") else MEDIA + "poster.png")
		"restore":
			player.prepare("index.island-intro.mp4", MEDIA + "intro.ogv", "index.poster.png" if OS.has_feature("web") else MEDIA + "poster.png", MEDIA + "last.png")
			player.play()
