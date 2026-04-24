extends CanvasLayer

@onready var fps_label: Label = $DebugInfoPanel/FPSLabel
@onready var kive_label: Label = $DebugInfoPanel/KiveStateLabel
@onready var agent_label: Label = $DebugInfoPanel/AgentStateLabel
@onready var distance_label: Label = $DebugInfoPanel/DistanceLabel
@onready var timeline_label: Label = $DebugInfoPanel/TimelineLabel


func _process(_delta: float) -> void:
	if not DebugOverlay.debug_enabled:
		visible = false
		return
	visible = true

	fps_label.text = "FPS: %d" % Engine.get_frames_per_second()

	var kive: Node = GameManager.kive_ref if GameManager.kive_ref else null

	if kive:
		var info: String = "KIVE\n"
		info += "  crouch=%s hide=%s\n" % [str(kive.is_crouched), str(kive.is_hidden)]
		info += "  jump=%s dive=%s\n" % [kive.jump_state, str(kive.is_diving)]
		info += "  cast=%s atk=%s\n" % [str(kive.is_casting), str(kive.is_attacking)]
		if kive.is_casting:
			info += "  cast_t=%.2fs (charged=%s)\n" % [kive.cast_timer, str(kive.cast_timer >= kive.attack_charge_time)]
		if kive.has_method("is_parry_window_active"):
			info += "  parry_window=%s\n" % str(kive.is_parry_window_active())
		if DebugOverlay.show_timeline and kive.has_node("AnimatedSprite2D"):
			info += "  anim=%s frame=%d" % [kive.sprite.animation, kive.sprite.frame]
		kive_label.text = info
	else:
		kive_label.text = "KIVE: no ref"

	var agents: Array = get_tree().get_nodes_in_group("agent")
	if agents.size() > 0:
		var agent: Node = agents[0]
		var info: String = "AGENT\n"
		info += "  state=%s t=%.2f\n" % [agent.State.keys()[agent.state], agent.state_timer]
		info += "  last_hit=%s\n" % agent.last_hit_quality
		info += "  lit=%s visible=%s heard=%s\n" % [str(agent.player_in_light), str(agent.player_visible), str(agent.player_heard)]
		if agent.has_method("get_position_tier_of") and kive:
			info += "  pos_tier=%s\n" % agent.get_position_tier_of(kive)
		if DebugOverlay.show_timeline and agent.has_node("AnimatedSprite2D"):
			info += "  anim=%s frame=%d" % [agent.sprite.animation, agent.sprite.frame]
		agent_label.text = info

		if kive:
			var dist: float = kive.global_position.distance_to(agent.global_position)
			distance_label.text = "Distancia: %.0f px" % dist
	else:
		agent_label.text = "AGENT: no instances"
		distance_label.text = ""
