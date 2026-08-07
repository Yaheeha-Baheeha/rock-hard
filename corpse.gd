extends RigidBody2D

@export_category("Corpse Settings")
@export var is_static: bool = false
@export var max_durability: float = 100.0

var current_durability: float
var base_color: Color

# Data stored from setup_corpse to be applied once nodes are ready
var _spawn_poly: PackedVector2Array
var _spawn_color: Color

func _ready() -> void:
	current_durability = max_durability
	add_to_group("corpse")
	
	if is_static:
		freeze_mode = RigidBody2D.FREEZE_MODE_STATIC
		freeze = true
	else:
		freeze = false
		
	# Apply the shapes NOW that the child nodes are actually ready
	if has_node("CollisionPolygon2D"):
		$CollisionPolygon2D.polygon = _spawn_poly
	if has_node("Polygon2D"):
		$Polygon2D.polygon = _spawn_poly
		$Polygon2D.color = _spawn_color

func setup_corpse(poly: PackedVector2Array, color: Color, spawn_global_pos: Vector2) -> void:
	global_position = spawn_global_pos
	base_color = color
	
	# Store these for _ready() to use
	_spawn_poly = poly
	_spawn_color = color

func take_lava_damage(amount: float, delta: float) -> void:
	current_durability -= amount * delta
	
	var burn_percent = 1.0 - (current_durability / max_durability)
	if has_node("Polygon2D"):
		$Polygon2D.color = base_color.lerp(Color(0.1, 0.1, 0.1, 1.0), burn_percent)
		
	if current_durability <= 0.0:
		queue_free()
