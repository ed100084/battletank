extends Area2D
class_name Powerup
## 道具系統：Star/Shield/Bomb/Clock/Shovel/ExtraLife

enum Type { STAR, SHIELD, BOMB, CLOCK, SHOVEL, EXTRA_LIFE }

const _COLORS := {
	Type.STAR:       Color(1.00, 0.90, 0.10),
	Type.SHIELD:     Color(0.25, 0.60, 1.00),
	Type.BOMB:       Color(1.00, 0.22, 0.22),
	Type.CLOCK:      Color(0.90, 0.90, 0.90),
	Type.SHOVEL:     Color(0.70, 0.45, 0.18),
	Type.EXTRA_LIFE: Color(0.20, 0.88, 0.28),
}
const _LABELS := {
	Type.STAR:       "★",
	Type.SHIELD:     "盾",
	Type.BOMB:       "炸",
	Type.CLOCK:      "凍",
	Type.SHOVEL:     "鏟",
	Type.EXTRA_LIFE: "命",
}

signal collected(powerup_type: int, picker: Node)

@export var powerup_type: int = Type.STAR

var _lifetime: float = 10.0
var _blink_acc: float = 0.0
var _icon: Polygon2D

func _is_local_authority() -> bool:
	if not multiplayer.has_multiplayer_peer():
		return true
	return is_multiplayer_authority()

func _ready() -> void:
	add_to_group("powerups")
	collision_layer = 8
	collision_mask  = 2
	monitoring      = true
	monitorable     = false

	var cs := CollisionShape2D.new()
	var sh := RectangleShape2D.new()
	sh.size = Vector2(28.0, 28.0)
	cs.shape = sh
	add_child(cs)

	_draw_background()
	_draw_icon()
	_draw_label()
	body_entered.connect(_on_body_entered)

func _draw_background() -> void:
	var bg := Polygon2D.new()
	bg.color = Color(0.0, 0.0, 0.0, 0.65)
	bg.polygon = PackedVector2Array([
		Vector2(-14, -14), Vector2(14, -14),
		Vector2(14,  14),  Vector2(-14, 14),
	])
	add_child(bg)

func _draw_icon() -> void:
	_icon = Polygon2D.new()
	_icon.color = _COLORS[powerup_type]
	match powerup_type:
		Type.STAR:
			_icon.polygon = _star_pts(5, 12.0, 5.5)
		Type.SHIELD:
			_icon.polygon = PackedVector2Array([
				Vector2(-9, -12), Vector2(9, -12), Vector2(12, -4),
				Vector2(12,  4),  Vector2(0,  13), Vector2(-12,  4), Vector2(-12, -4),
			])
		Type.BOMB:
			_icon.polygon = _circle_pts(10, 10.5)
		Type.CLOCK:
			_icon.polygon = _circle_pts(12, 11.0)
		Type.SHOVEL:
			_icon.polygon = PackedVector2Array([
				Vector2(-3, -13), Vector2(3, -13), Vector2(3,  0),
				Vector2(10,  0),  Vector2(10, 6),  Vector2(3,  6),
				Vector2(3,  13),  Vector2(-3, 13), Vector2(-3,  6),
				Vector2(-10, 6),  Vector2(-10, 0), Vector2(-3,  0),
			])
		Type.EXTRA_LIFE:
			_icon.polygon = PackedVector2Array([
				Vector2(-10, -8), Vector2(10, -8), Vector2(10, 4),
				Vector2(6,   4),  Vector2(6,  10), Vector2(-6, 10),
				Vector2(-6,  4),  Vector2(-10, 4),
			])
	add_child(_icon)

func _draw_label() -> void:
	var lbl := Label.new()
	lbl.text = _LABELS[powerup_type]
	lbl.add_theme_font_size_override("font_size", 9)
	lbl.add_theme_color_override("font_color", Color.WHITE)
	lbl.position = Vector2(-5, -4)
	add_child(lbl)

func _star_pts(n: int, r_outer: float, r_inner: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(n * 2):
		var angle := i * PI / n - PI * 0.5
		var r     := r_outer if (i % 2 == 0) else r_inner
		pts.append(Vector2(cos(angle) * r, sin(angle) * r))
	return pts

func _circle_pts(n: int, r: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(n):
		var a := i * TAU / n
		pts.append(Vector2(cos(a) * r, sin(a) * r))
	return pts

func _process(delta: float) -> void:
	_lifetime -= delta
	if _lifetime <= 0.0:
		queue_free()
		return
	_blink_acc += delta
	if _lifetime < 3.0:
		visible = fmod(_blink_acc, 0.30) < 0.15

func _on_body_entered(body: Node) -> void:
	# 多人模式下只 authority 端偵測拾取，避免雙端 race (各算一次)
	if not _is_local_authority():
		return
	if body.is_in_group("player"):
		collected.emit(powerup_type, body)
		queue_free()
