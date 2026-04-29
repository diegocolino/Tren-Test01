extends CanvasLayer

@onready var fps_label: Label = $DebugInfoPanel/FPSLabel
@onready var kive_label: Label = $DebugInfoPanel/KiveStateLabel
@onready var agent_label: Label = $DebugInfoPanel/AgentStateLabel
@onready var distance_label: Label = $DebugInfoPanel/DistanceLabel
@onready var timeline_label: Label = $DebugInfoPanel/TimelineLabel

var god_mode_label: Label


func _ready() -> void:
	god_mode_label = Label.new()
	god_mode_label.name = "GodModeLabel"
	god_mode_label.text = "GOD MODE"
	god_mode_label.add_theme_font_size_override("font_size", 24)
	god_mode_label.add_theme_color_override("font_color", Color(1, 0.2, 0.2))
	god_mode_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	god_mode_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	god_mode_label.offset_top = 10
	god_mode_label.visible = false
	add_child(god_mode_label)


func _process(_delta: float) -> void:
	god_mode_label.visible = DebugOverlay.god_mode

	if not DebugOverlay.show_debug_text:
		$DebugInfoPanel.visible = false
		return
	$DebugInfoPanel.visible = true

	fps_label.text = "FPS: %d" % Engine.get_frames_per_second()

	var kive: Node = GameManager.kive_ref if GameManager.kive_ref else null

	if kive:
		var info: String = "KIVE\n"
		info += "  state=%s\n" % str(kive.state_machine.current_state_name)
		info += "  crouch=%s hide=%s\n" % [str(kive.is_crouched), str(kive.is_hidden)]
		info += "  jump=%s dive=%s\n" % [kive.jump_state, str(kive.is_diving)]
		info += "  atk=%s hit=%s chain=%d\n" % [str(kive.is_attacking), kive.current_hit_type, kive.w_chain_step]
		if kive.has_method("is_parry_window_active"):
			info += "  parry_window=%s\n" % str(kive.is_parry_window_active())
		if kive.has_node("AnimatedSprite2D"):
			info += "  anim=%s frame=%d\n" % [kive.sprite.animation, kive.sprite.frame]
		info += "FLAI: kill %d | ko %d | alarm %d" % [FlaiAlarm.kill_count, FlaiAlarm.ko_count, FlaiAlarm.current_alarm_level]
		kive_label.text = info
	else:
		kive_label.text = "KIVE: no ref"

	var agents: Array = get_tree().get_nodes_in_group("agent")
	if agents.size() > 0:
		var agent: Node = agents[0]
		var info: String = "AGENT\n"
		info += "  state=%s t=%.2f\n" % [agent.AgentState.keys()[agent.state], agent.state_timer]
		info += "  last_hit=%s\n" % agent.last_hit_quality
		info += "  lit=%s visible=%s heard=%s\n" % [str(agent.player_in_light), str(agent.player_visible), str(agent.player_heard)]
		info += "  vision=%s facing=%s\n" % [str(agent.player_in_vision), "R" if agent.facing_right else "L"]
		info += "  turn_cd=%.2f\n" % agent._turn_cooldown
		if agent.has_method("get_position_tier_of") and kive:
			info += "  pos_tier=%s\n" % agent.get_position_tier_of(kive)
		if agent.has_node("AnimatedSprite2D"):
			info += "  anim=%s frame=%d\n" % [agent.sprite.animation, agent.sprite.frame]

		# Combat info
		if kive and agent.has_method("get_position_tier_of"):
			info += "\nCOMBAT INFO\n"
			var pos_tier: String = agent.get_position_tier_of(kive)
			var agent_state: String = agent.AgentState.keys()[agent.state]
			info += "  pos=%s state=%s\n" % [pos_tier, agent_state]
			info += "  W: hit | W charged+guard: stunt\n"
			info += "  W charged+vuln: golpe_bueno\n"
			info += "  W max+vuln: maestro\n"
			info += "  Q frente+guard: block\n"
			info += "  Q detras/patrol/stunt: ko"

		agent_label.text = info

		if kive:
			var dist_h: float = abs(kive.global_position.x - agent.global_position.x)
			var dist_total: float = kive.global_position.distance_to(agent.global_position)
			distance_label.text = "Dist: %.0f px (horiz: %.0f px)" % [dist_total, dist_h]
	else:
		agent_label.text = "AGENT: no instances"
		distance_label.text = ""
