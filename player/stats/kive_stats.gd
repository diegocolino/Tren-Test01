class_name KiveStats extends Resource

# ============ MOVEMENT ============
@export_group("Movement")
@export_subgroup("Horizontal")
@export var walk_speed: float = 400.0
@export var run_speed: float = 800.0
@export var crouch_walk_speed: float = 200.0
@export_range(0.0, 1.0, 0.05) var air_control_factor: float = 0.8

@export_subgroup("Physics")
@export var gravity: float = 2400.0

@export_subgroup("Crouch")
@export_range(0.1, 1.0, 0.05) var crouch_height_multiplier: float = 0.7

# ============ JUMP ============
@export_group("Jump")
@export_subgroup("Standard")
@export var jump_velocity_min: float = -800.0
@export var jump_velocity_max: float = -1200.0
@export var jump_charge_time: float = 0.4

@export_subgroup("Air")
@export_range(0, 5) var max_air_jumps: int = 1
@export var air_jump_velocity: float = -800.0

# ============ DIVE ============
@export_group("Dive")
@export var dive_speed: float = 1200.0
@export var dive_max_duration: float = 1.2
@export var dive_friction: float = 800.0

# ============ COMBAT ============
@export_group("Combat")
@export_subgroup("Charge")
@export var attack_charge_time: float = 0.4
@export var attack_charge_time_max: float = 2.4

@export_subgroup("Punch Timings")
@export var punch_anticipation: float = 0.08
@export var punch_release: float = 0.15
@export var punch_recovery: float = 0.25

@export_subgroup("Kick Timings")
@export var kick_anticipation: float = 0.05
@export var kick_release: float = 0.10
@export var kick_recovery: float = 0.15

@export_subgroup("Charged Punch Lunge")
@export var charged_lunge_speed_x: float = 2400.0
@export var charged_lunge_speed_y: float = -1200.0

@export_subgroup("Parry")
@export_range(1, 120) var parry_window_frames: int = 40
