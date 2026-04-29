extends CanvasLayer

@onready var alarm_label: Label = $HUDContainer/HBox/DataLabels/AlarmLabel
@onready var status_label: Label = $HUDContainer/HBox/DataLabels/StatusLabel
@onready var agents_down_label: Label = $HUDContainer/HBox/DataLabels/AgentsDownLabel


func _process(_delta: float) -> void:
	alarm_label.text = "ALARM: %d" % LenFlai.current_alarm_level
	status_label.text = "STATUS: %s" % LenFlai.current_status
	agents_down_label.text = "AGENTS DOWN: %d" % LenFlai.agents_down
