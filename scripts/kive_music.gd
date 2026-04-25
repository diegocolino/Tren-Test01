extends Node

signal intro_finished

const INTRO_DURATION: float = 11.0
const MUTED_DB: float = -80.0
const FULL_DB: float = 0.0

var _current_theme: int = 1
var _intro_emitted: bool = false

@onready var layers: Array[AudioStreamPlayer] = [$Layer1, $Layer2, $Layer3, $Layer4]


func _ready() -> void:
	for layer: AudioStreamPlayer in layers:
		layer.finished.connect(_on_layer_finished.bind(layer))
	GameManager.player_respawn_started.connect(_on_respawn)
	_play_theme(1)


func _process(_delta: float) -> void:
	if not _intro_emitted and _current_theme == 1 and layers[0].playing:
		if layers[0].get_playback_position() >= INTRO_DURATION:
			_intro_emitted = true
			intro_finished.emit()


func _play_theme(index: int) -> void:
	_current_theme = index
	for layer: AudioStreamPlayer in layers:
		layer.stop()
	layers[index - 1].volume_db = FULL_DB
	layers[index - 1].play()


func _on_layer_finished(layer: AudioStreamPlayer) -> void:
	var layer_index: int = layers.find(layer) + 1
	if layer_index != _current_theme:
		return
	match _current_theme:
		1: _play_theme(2)
		2: _play_theme(3)
		3: _play_theme(4)
		4: _play_theme(4)


func _on_respawn() -> void:
	for layer: AudioStreamPlayer in layers:
		layer.stop()
	_intro_emitted = false
	_play_theme(1)
