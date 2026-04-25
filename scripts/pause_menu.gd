extends Node

## Pause menu (ESC). 3-column layout: empty | settings | info panel.
## Persists settings to user://settings.cfg.

var hold_to_crouch: bool = false
var hold_to_walk: bool = false

var _visible: bool = false
var _waiting_for_key: bool = false
var _remap_action: String = ""
var _remap_button: Button = null

var _canvas_layer: CanvasLayer
var _overlay: ColorRect
var _center_col: VBoxContainer
var _right_col: VBoxContainer
var _crouch_mode_button: Button
var _walk_mode_button: Button
var _god_mode_button: Button
var _god_info_button: Button
var _volume_slider: HSlider
var _volume_label: Label

const actions: Array[Array] = [
	["Move Left", "move_left"],
	["Move Right", "move_right"],
	["Jump", "jump"],
	["Crouch", "crouch"],
	["Walk (hold)", "run"],
	["Dive", "dive"],
	["Punch (hold=charged)", "attack_punch"],
	["Kick", "attack_kick"],
]

const DEFAULT_VOLUME: float = 0.44

var _action_buttons: Dictionary = {}
var _config: ConfigFile
var _saved_volume: float = DEFAULT_VOLUME


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_config = ConfigFile.new()
	_load_settings()
	_build_ui()
	_volume_slider.value = _saved_volume
	_volume_label.text = "%d%%" % int(_saved_volume * 100)
	_apply_volume(_saved_volume)
	_canvas_layer.visible = false


func _input(event: InputEvent) -> void:
	if _waiting_for_key:
		if event is InputEventKey and event.pressed:
			get_viewport().set_input_as_handled()
			if event.keycode == KEY_ESCAPE:
				_remap_button.text = _get_key_name_for_action(_remap_action)
				_waiting_for_key = false
				_remap_button = null
				_remap_action = ""
				return
			_apply_remap(_remap_action, event)
			_remap_button.text = _get_key_name_for_action(_remap_action)
			_waiting_for_key = false
			_remap_button = null
			_remap_action = ""
			_save_settings()
		return

	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		if _visible:
			_close_menu()
		else:
			_open_menu()


func _open_menu() -> void:
	_visible = true
	_canvas_layer.visible = true
	get_tree().paused = true
	for action_name: String in _action_buttons:
		_action_buttons[action_name].text = _get_key_name_for_action(action_name)
	_crouch_mode_button.text = "Hold" if hold_to_crouch else "Toggle"
	_walk_mode_button.text = "Hold" if hold_to_walk else "Toggle"
	_god_mode_button.text = "ON" if DebugOverlay.god_mode else "OFF"
	_right_col.visible = DebugOverlay.god_mode


func _close_menu() -> void:
	_visible = false
	_canvas_layer.visible = false
	get_tree().paused = false


func _build_ui() -> void:
	_canvas_layer = CanvasLayer.new()
	_canvas_layer.layer = 100
	add_child(_canvas_layer)

	_overlay = ColorRect.new()
	_overlay.color = Color(0, 0, 0, 0.7)
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_canvas_layer.add_child(_overlay)

	# 3-column HBox centered in screen
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(center)

	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 40)
	center.add_child(columns)

	# Col 1: spacer (matches col 3 width so col 2 stays centered)
	var left_spacer := Control.new()
	left_spacer.custom_minimum_size.x = 280
	columns.add_child(left_spacer)

	# Col 2: main settings
	_center_col = VBoxContainer.new()
	_center_col.add_theme_constant_override("separation", 6)
	columns.add_child(_center_col)

	# Col 3: info panel (god mode controls)
	_right_col = VBoxContainer.new()
	_right_col.add_theme_constant_override("separation", 6)
	_right_col.custom_minimum_size.x = 280
	_right_col.visible = false
	columns.add_child(_right_col)

	_build_center_column()
	_build_right_column()


func _build_center_column() -> void:
	var c: VBoxContainer = _center_col

	# Title
	var title := Label.new()
	title.text = "SETTINGS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 32)
	c.add_child(title)

	c.add_child(HSeparator.new())

	# === GOD MODE (top, below title) ===
	var god_row := HBoxContainer.new()
	god_row.add_theme_constant_override("separation", 8)

	var god_label := Label.new()
	god_label.text = "God Mode"
	god_label.custom_minimum_size.x = 200
	god_label.add_theme_font_size_override("font_size", 20)
	god_label.add_theme_color_override("font_color", Color(1, 0.3, 0.3))
	god_row.add_child(god_label)

	_god_mode_button = Button.new()
	_god_mode_button.text = "OFF"
	_god_mode_button.custom_minimum_size.x = 120
	_god_mode_button.add_theme_font_size_override("font_size", 20)
	_god_mode_button.pressed.connect(_on_god_mode_pressed)
	god_row.add_child(_god_mode_button)

	_god_info_button = Button.new()
	_god_info_button.text = "?"
	_god_info_button.custom_minimum_size = Vector2(32, 32)
	_god_info_button.add_theme_font_size_override("font_size", 18)
	_god_info_button.pressed.connect(_on_god_info_pressed)
	god_row.add_child(_god_info_button)

	c.add_child(god_row)

	c.add_child(HSeparator.new())

	# === VOLUME ===
	var vol_row := HBoxContainer.new()
	vol_row.add_theme_constant_override("separation", 16)
	var vol_label := Label.new()
	vol_label.text = "Volume"
	vol_label.custom_minimum_size.x = 200
	vol_label.add_theme_font_size_override("font_size", 20)
	vol_row.add_child(vol_label)

	_volume_slider = HSlider.new()
	_volume_slider.min_value = 0.0
	_volume_slider.max_value = 1.0
	_volume_slider.step = 0.01
	_volume_slider.value = DEFAULT_VOLUME
	_volume_slider.custom_minimum_size.x = 120
	_volume_slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_volume_slider.value_changed.connect(_on_volume_changed)
	vol_row.add_child(_volume_slider)

	_volume_label = Label.new()
	_volume_label.text = "%d%%" % int(DEFAULT_VOLUME * 100)
	_volume_label.custom_minimum_size.x = 40
	_volume_label.add_theme_font_size_override("font_size", 20)
	vol_row.add_child(_volume_label)

	c.add_child(vol_row)

	c.add_child(HSeparator.new())

	# === CONTROLS ===
	var controls_title := Label.new()
	controls_title.text = "CONTROLS"
	controls_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	controls_title.add_theme_font_size_override("font_size", 24)
	c.add_child(controls_title)

	for entry: Array in actions:
		_add_action_row(entry[0], entry[1])

	c.add_child(HSeparator.new())

	# === MODES ===
	_add_mode_row("Crouch Mode", hold_to_crouch, func() -> void: _on_crouch_mode_pressed())
	_crouch_mode_button = c.get_child(c.get_child_count() - 1).get_child(1) as Button

	_add_mode_row("Walk Mode", hold_to_walk, func() -> void: _on_walk_mode_pressed())
	_walk_mode_button = c.get_child(c.get_child_count() - 1).get_child(1) as Button

	c.add_child(HSeparator.new())

	# Footer
	var footer := Label.new()
	footer.text = "ESC to close"
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	footer.add_theme_font_size_override("font_size", 16)
	footer.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	c.add_child(footer)


func _build_right_column() -> void:
	var r: VBoxContainer = _right_col

	var info_title := Label.new()
	info_title.text = "GOD MODE"
	info_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info_title.add_theme_font_size_override("font_size", 24)
	info_title.add_theme_color_override("font_color", Color(1, 0.3, 0.3))
	r.add_child(info_title)

	r.add_child(HSeparator.new())

	var god_controls: Array[Array] = [
		["F1", "Toggle god mode"],
		["F2", "Show hitboxes"],
		["F3", "Debug text"],
		["F4", "Slow motion (x0.25)"],
		["F", "Freeze (pause)"],
		["Scroll", "Zoom to cursor"],
		["Mid-click drag", "Pan camera"],
	]
	for entry: Array in god_controls:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)

		var key_label := Label.new()
		key_label.text = entry[0]
		key_label.custom_minimum_size.x = 100
		key_label.add_theme_font_size_override("font_size", 16)
		key_label.add_theme_color_override("font_color", Color(1.0, 0.6, 0.6))
		row.add_child(key_label)

		var desc_label := Label.new()
		desc_label.text = entry[1]
		desc_label.add_theme_font_size_override("font_size", 16)
		desc_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
		row.add_child(desc_label)

		r.add_child(row)


func _add_action_row(display_name: String, action_name: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)

	var label := Label.new()
	label.text = display_name
	label.custom_minimum_size.x = 200
	label.add_theme_font_size_override("font_size", 20)
	row.add_child(label)

	var button := Button.new()
	button.text = _get_key_name_for_action(action_name)
	button.custom_minimum_size.x = 160
	button.add_theme_font_size_override("font_size", 20)
	button.pressed.connect(_on_remap_pressed.bind(action_name, button))
	row.add_child(button)

	_action_buttons[action_name] = button
	_center_col.add_child(row)


func _add_mode_row(display_name: String, current_hold: bool, callback: Callable) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)

	var label := Label.new()
	label.text = display_name
	label.custom_minimum_size.x = 200
	label.add_theme_font_size_override("font_size", 20)
	row.add_child(label)

	var button := Button.new()
	button.text = "Hold" if current_hold else "Toggle"
	button.custom_minimum_size.x = 160
	button.add_theme_font_size_override("font_size", 20)
	button.pressed.connect(callback)
	row.add_child(button)

	_center_col.add_child(row)


func _on_remap_pressed(action_name: String, button: Button) -> void:
	_waiting_for_key = true
	_remap_action = action_name
	_remap_button = button
	button.text = "..."


func _on_crouch_mode_pressed() -> void:
	hold_to_crouch = not hold_to_crouch
	_crouch_mode_button.text = "Hold" if hold_to_crouch else "Toggle"
	_save_settings()


func _on_walk_mode_pressed() -> void:
	hold_to_walk = not hold_to_walk
	_walk_mode_button.text = "Hold" if hold_to_walk else "Toggle"
	_save_settings()


func _on_god_mode_pressed() -> void:
	DebugOverlay.god_mode = not DebugOverlay.god_mode
	_god_mode_button.text = "ON" if DebugOverlay.god_mode else "OFF"
	_right_col.visible = DebugOverlay.god_mode


func _on_god_info_pressed() -> void:
	_right_col.visible = not _right_col.visible


func _on_volume_changed(value: float) -> void:
	_apply_volume(value)
	_volume_label.text = "%d%%" % int(value * 100)
	_save_settings()


func _apply_volume(value: float) -> void:
	var db: float = linear_to_db(value) if value > 0.0 else -80.0
	AudioServer.set_bus_volume_db(0, db)


func _apply_remap(action_name: String, event: InputEventKey) -> void:
	InputMap.action_erase_events(action_name)
	var new_event := InputEventKey.new()
	new_event.keycode = event.keycode
	new_event.physical_keycode = event.physical_keycode
	new_event.unicode = event.unicode
	InputMap.action_add_event(action_name, new_event)


func _get_key_name_for_action(action_name: String) -> String:
	var events := InputMap.action_get_events(action_name)
	if events.is_empty():
		return "---"
	var ev: InputEvent = events[0]
	if ev is InputEventKey:
		var k: InputEventKey = ev as InputEventKey
		return OS.get_keycode_string(k.keycode) if k.keycode != 0 else OS.get_keycode_string(k.physical_keycode)
	return "?"


func _save_settings() -> void:
	for entry: Array in actions:
		var action_name: String = entry[1]
		var events := InputMap.action_get_events(action_name)
		if not events.is_empty() and events[0] is InputEventKey:
			var k: InputEventKey = events[0] as InputEventKey
			_config.set_value("controls", action_name + "_keycode", k.keycode)
			_config.set_value("controls", action_name + "_physical", k.physical_keycode)
			_config.set_value("controls", action_name + "_unicode", k.unicode)
	_config.set_value("controls", "hold_to_crouch", hold_to_crouch)
	_config.set_value("controls", "hold_to_walk", hold_to_walk)
	_config.set_value("audio", "volume", _volume_slider.value)
	_config.save("user://settings.cfg")


func _load_settings() -> void:
	var err := _config.load("user://settings.cfg")
	if err != OK:
		return
	hold_to_crouch = _config.get_value("controls", "hold_to_crouch", false)
	hold_to_walk = _config.get_value("controls", "hold_to_walk", false)
	_saved_volume = _config.get_value("audio", "volume", DEFAULT_VOLUME)
	for entry: Array in actions:
		var action_name: String = entry[1]
		if _config.has_section_key("controls", action_name + "_keycode"):
			var keycode: int = _config.get_value("controls", action_name + "_keycode", 0)
			var physical: int = _config.get_value("controls", action_name + "_physical", 0)
			var unicode: int = _config.get_value("controls", action_name + "_unicode", 0)
			InputMap.action_erase_events(action_name)
			var ev := InputEventKey.new()
			ev.keycode = keycode
			ev.physical_keycode = physical
			ev.unicode = unicode
			InputMap.action_add_event(action_name, ev)
