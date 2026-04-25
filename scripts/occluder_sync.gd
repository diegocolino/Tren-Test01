extends LightOccluder2D

## Genera OccluderPolygon2D automaticamente desde el alpha de cada frame
## del AnimatedSprite2D hermano. Pre-cachea todo en _ready() y swapea en runtime.

@export var alpha_threshold: float = 0.5
@export var polygon_epsilon: float = 2.0

var _cache: Dictionary = {}
var _last_flip: bool = false
var _parent: CharacterBody2D

@onready var sprite: AnimatedSprite2D = get_parent().get_node("AnimatedSprite2D")


func _ready() -> void:
	_parent = get_parent()
	_precache_all_polygons()
	sprite.frame_changed.connect(_on_frame_changed)
	sprite.animation_changed.connect(_on_frame_changed)
	_on_frame_changed()


func _process(_delta: float) -> void:
	if "is_hidden" in _parent:
		var should_show: bool = not _parent.is_hidden
		if visible != should_show:
			visible = should_show

	if sprite.flip_h != _last_flip:
		_last_flip = sprite.flip_h
		scale.x = -1.0 if _last_flip else 1.0


func _precache_all_polygons() -> void:
	var frames: SpriteFrames = sprite.sprite_frames
	for anim_name: String in frames.get_animation_names():
		for i: int in range(frames.get_frame_count(anim_name)):
			var key: String = "%s_%d" % [anim_name, i]
			var tex: Texture2D = frames.get_frame_texture(anim_name, i)
			if tex:
				var poly: OccluderPolygon2D = _generate_polygon(tex)
				if poly:
					_cache[key] = poly


func _generate_polygon(tex: Texture2D) -> OccluderPolygon2D:
	var image: Image = tex.get_image()
	if not image:
		return null

	var w: int = image.get_width()
	var h: int = image.get_height()

	var bitmap := BitMap.new()
	bitmap.create_from_image_alpha(image, alpha_threshold)

	var polygons: Array = bitmap.opaque_to_polygons(Rect2(0, 0, w, h), polygon_epsilon)
	if polygons.is_empty():
		return null

	# Usar el poligono mas grande (silueta principal)
	var largest: PackedVector2Array = polygons[0]
	for idx: int in range(1, polygons.size()):
		if polygons[idx].size() > largest.size():
			largest = polygons[idx]

	# Centrar (AnimatedSprite2D centra por defecto)
	var offset := Vector2(-w / 2.0, -h / 2.0)
	var centered := PackedVector2Array()
	centered.resize(largest.size())
	for i: int in range(largest.size()):
		centered[i] = largest[i] + offset

	var occ := OccluderPolygon2D.new()
	occ.polygon = centered
	return occ


func _on_frame_changed() -> void:
	var key: String = "%s_%d" % [sprite.animation, sprite.frame]
	if _cache.has(key):
		occluder = _cache[key]
