extends Node

## Minimal controls menu opened with ESC. Autoload singleton.
## Supports key remapping and toggle/hold crouch mode.
## Persists settings to user://settings.cfg.

var hold_to_crouch: bool = false

var _visible: bool = false
var _waiting_for_key: bool = false
var _remap_action: String = ""
var _remap_button: Button = null

var _canvas_layer: CanvasLayer
var _overlay: ColorRect
var _container: VBoxContainer
var _crouch_mode_button: Button

# Actions that can be remapped: display_name -> action_name
const actions: Array[Array] = [
	["Move Left", "move_left"],
	["Move Right", "move_right"],
	["Jump", "jump"],
	["Crouch", "crouch"],
	["Walk (hold)", "run"],
	["Dive", "dive"],
]

var _action_buttons: Dictionary = {}  # action_name -> Button
var _config: ConfigFile


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_config = ConfigFile.new()
	_load_settings()
	_build_ui()
	_canvas_layer.visible = false


func _input(event: InputEvent) -> void:
	if _waiting_for_key:
		if event is InputEventKey and event.pressed:
			get_viewport().set_input_as_handled()
			if event.keycode == KEY_ESCAPE:
				# Cancel remap
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
	# Refresh button labels
	for action_name: String in _action_buttons:
		_action_buttons[action_name].text = _get_key_name_for_action(action_name)
	_crouch_mode_button.text = "Hold" if hold_to_crouch else "Toggle"


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

	# Center container
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(center)

	_container = VBoxContainer.new()
	_container.add_theme_constant_override("separation", 8)
	center.add_child(_container)

	# Title
	var title := Label.new()
	title.text = "CONTROLS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 32)
	_container.add_child(title)

	_container.add_child(HSeparator.new())

	# Action rows
	for entry: Array in actions:
		var display_name: String = entry[0]
		var action_name: String = entry[1]
		_add_action_row(display_name, action_name)

	_container.add_child(HSeparator.new())

	# Crouch mode row
	var crouch_row := HBoxContainer.new()
	crouch_row.add_theme_constant_override("separation", 16)
	var crouch_label := Label.new()
	crouch_label.text = "Crouch Mode"
	crouch_label.custom_minimum_size.x = 200
	crouch_label.add_theme_font_size_override("font_size", 20)
	crouch_row.add_child(crouch_label)

	_crouch_mode_button = Button.new()
	_crouch_mode_button.text = "Hold" if hold_to_crouch else "Toggle"
	_crouch_mode_button.custom_minimum_size.x = 160
	_crouch_mode_button.add_theme_font_size_override("font_size", 20)
	_crouch_mode_button.pressed.connect(_on_crouch_mode_pressed)
	crouch_row.add_child(_crouch_mode_button)
	_container.add_child(crouch_row)

	_container.add_child(HSeparator.new())

	# Footer
	var footer := Label.new()
	footer.text = "ESC to close"
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	footer.add_theme_font_size_override("font_size", 16)
	footer.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	_container.add_child(footer)


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
	_container.add_child(row)


func _on_remap_pressed(action_name: String, button: Button) -> void:
	_waiting_for_key = true
	_remap_action = action_name
	_remap_button = button
	button.text = "..."


func _on_crouch_mode_pressed() -> void:
	hold_to_crouch = not hold_to_crouch
	_crouch_mode_button.text = "Hold" if hold_to_crouch else "Toggle"
	_save_settings()


func _apply_remap(action_name: String, event: InputEventKey) -> void:
	# Clear existing events and set the new one
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
	_config.save("user://settings.cfg")


func _load_settings() -> void:
	var err := _config.load("user://settings.cfg")
	if err != OK:
		return
	hold_to_crouch = _config.get_value("controls", "hold_to_crouch", false)
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
