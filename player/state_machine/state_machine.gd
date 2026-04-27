class_name StateMachine extends Node

signal state_changed(old_state: StringName, new_state: StringName)

@export var initial_state: NodePath

var owner_node: Node
var current_state: State
var current_state_name: StringName = &""
var states: Dictionary = {}  # StringName -> State


func _ready() -> void:
	var parent_node: Node = get_parent()

	for child: Node in get_children():
		if child is State:
			child.owner_node = parent_node
			child.sm = self
			states[StringName(child.name)] = child

	# Esperar al siguiente frame para que el parent tenga sus @onready listos
	await get_tree().process_frame

	if initial_state and not initial_state.is_empty():
		var start: Node = get_node(initial_state)
		if start and start is State:
			current_state = start
			current_state_name = StringName(start.name)
			start.enter(&"", {})


func _physics_process(delta: float) -> void:
	if current_state == null:
		return

	var next: StringName = current_state.physics_update(delta)
	if next != &"":
		transition_to(next)


func transition_to(target: StringName, msg: Dictionary = {}) -> void:
	if not states.has(target):
		push_error("[StateMachine] Estado inexistente: %s" % target)
		return

	var old_name: StringName = current_state_name
	if current_state:
		current_state.exit()

	current_state = states[target]
	current_state_name = target
	current_state.enter(old_name, msg)
	state_changed.emit(old_name, target)


func is_in_state(state_name: StringName) -> bool:
	return current_state_name == state_name
