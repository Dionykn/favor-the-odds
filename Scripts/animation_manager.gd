extends CanvasLayer
class_name AnimationManager

const ANIM_DURATION = 0.5
const COMPLETE_STAGGER = 0.08
const POOL_SIZE = 15

var card_pool : Array = []

func _ready():
	for i in range(POOL_SIZE):
		var tr = _make_card_rect()
		add_child(tr)
		card_pool.append(tr)

func _make_card_rect() -> TextureRect:
	var tr = TextureRect.new()
	tr.visible = false
	tr.z_index = 100
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	return tr

func get_card() -> TextureRect:
	for tr in card_pool:
		if not tr.visible:
			return tr
	var tr = _make_card_rect()
	add_child(tr)
	card_pool.append(tr)
	return tr

## Returns the visual top-left of a rotated Control node.
## Godot rotates Controls around their top-left origin, so global_position
## doesn't match the visual position when a node is rotated.
func node_visual_position(node: Control) -> Vector2:
	var rot = node.rotation
	var half = node.size / 2
	var rx = half.x * cos(rot) - half.y * sin(rot)
	var ry = half.x * sin(rot) + half.y * cos(rot)
	var center = node.global_position + Vector2(rx, ry)
	return center - half

func card_to_texture(card: String) -> Texture2D:
	if card == "Joker":
		return load("res://Sprites/Cards/joker.png")
	return load("res://Sprites/Cards/" + card.to_lower().replace(" of ", "_") + ".png")

func animate_card(card_value: String, src_node: Control, dst_node: Control, face_up: bool = true, src_rot: float = 0.0, dst_rot: float = 0.0) -> void:
	var tr = get_card()
	tr.texture = card_to_texture(card_value) if face_up else load("res://Sprites/Cards/back.png")
	var card_size = src_node.get_global_rect().size
	tr.size = card_size
	tr.pivot_offset = card_size / 2
	tr.position = node_visual_position(src_node)
	tr.rotation_degrees = src_rot
	tr.modulate = Color(1, 1, 1, 1)
	tr.visible = true

	var dst_pos = node_visual_position(dst_node)

	var tween = create_tween()
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_parallel(true)
	tween.tween_property(tr, "position", dst_pos, ANIM_DURATION)
	tween.tween_property(tr, "rotation_degrees", dst_rot, ANIM_DURATION)

	await tween.finished
	tr.visible = false

func animate_card_from_pos(card_value: String, src_pos: Vector2, dst_node: Control, face_up: bool = true, src_rot: float = 0.0, dst_rot: float = 0.0) -> void:
	var tr = get_card()
	tr.texture = card_to_texture(card_value) if face_up else load("res://Sprites/Cards/back.png")
	var card_size = dst_node.get_global_rect().size
	tr.size = card_size
	tr.pivot_offset = card_size / 2
	tr.position = src_pos
	tr.rotation_degrees = src_rot
	tr.modulate = Color(1, 1, 1, 1)
	tr.visible = true

	var tween = create_tween()
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_parallel(true)
	tween.tween_property(tr, "position", node_visual_position(dst_node), ANIM_DURATION)
	tween.tween_property(tr, "rotation_degrees", dst_rot, ANIM_DURATION)

	await tween.finished
	tr.visible = false

func animate_card_with_flip(card_value: String, src_node: Control, dst_node: Control, src_rot: float = 0.0, dst_rot: float = 0.0) -> void:
	var tr = get_card()
	tr.texture = load("res://Sprites/Cards/back.png")
	var card_size = src_node.get_global_rect().size
	tr.size = card_size
	tr.pivot_offset = card_size / 2
	tr.position = node_visual_position(src_node)
	tr.rotation_degrees = src_rot
	tr.scale = Vector2(1, 1)
	tr.modulate = Color(1, 1, 1, 1)
	tr.visible = true

	var dst_pos = node_visual_position(dst_node)
	var flip_duration = 0.25

	# Travel face-down, flip starts just before arriving
	var tween1 = create_tween()
	tween1.set_ease(Tween.EASE_IN_OUT)
	tween1.set_trans(Tween.TRANS_CUBIC)
	tween1.set_parallel(true)
	tween1.tween_property(tr, "position", dst_pos, ANIM_DURATION)
	tween1.tween_property(tr, "rotation_degrees", dst_rot, ANIM_DURATION)
	# Squish starts so it finishes exactly as card arrives
	tween1.tween_property(tr, "scale:y", 0.0, flip_duration).set_delay(ANIM_DURATION - flip_duration).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	await tween1.finished

	# Swap texture at midpoint of flip
	tr.texture = card_to_texture(card_value)
	tr.scale.y = 0.0

	# Expand back out
	var tween2 = create_tween()
	tween2.tween_property(tr, "scale:y", 1.0, flip_duration).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	await tween2.finished

	tr.visible = false

func animate_completion(pile: Array, src_node: Control, dst_node: Control) -> void:
	var dst_pos = node_visual_position(dst_node)

	for i in range(pile.size()):
		var tr = get_card()
		tr.texture = card_to_texture(pile[i])
		var card_size = src_node.get_global_rect().size
		tr.size = card_size
		tr.pivot_offset = card_size / 2
		tr.position = node_visual_position(src_node)
		tr.rotation_degrees = 0.0
		tr.modulate = Color(1, 1, 1, 1)
		tr.visible = true

		var tween = create_tween()
		tween.set_ease(Tween.EASE_IN_OUT)
		tween.set_trans(Tween.TRANS_CUBIC)
		tween.tween_interval(i * COMPLETE_STAGGER)
		tween.tween_property(tr, "position", dst_pos, ANIM_DURATION)
		tween.tween_callback(tr.hide)

	await get_tree().create_timer(pile.size() * COMPLETE_STAGGER + ANIM_DURATION).timeout
