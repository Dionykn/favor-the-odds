extends Control

@onready var menu = $Menu
@onready var game : GameManager = $GameManager
@onready var board_ui = $BoardUI
@onready var player_ui : PlayerUI = $PlayerUI
@onready var cpu_ui : PlayerUI = $CpuUI
@onready var anim : AnimationManager = $AnimationManager
@onready var cards_left_label = $DeckLabel
@onready var player_stock_label = $PlayerStockLabel
@onready var cpu_stock_label = $CpuStockLabel
@onready var start_button = $Menu/StartButton
@onready var turn_label = $TurnLabel
@onready var drag_card : TextureRect = $DragCard

# Animation lock
var is_animating : bool = false

# Drag state
var drag_pos : Vector2 = Vector2.ZERO
var prev_mouse_pos : Vector2 = Vector2.ZERO
var mouse_velocity : Vector2 = Vector2.ZERO

# Captured when human releases a card
var human_play_origin : Vector2 = Vector2.ZERO
var human_play_rotation : float = 0.0

func _ready():
	game.game_started.connect(_on_game_started)
	game.deck_count_changed.connect(_on_deck_count_changed)
	game.turn_changed.connect(_on_turn_changed)
	game.player_stock_changed.connect(_on_player_stock_changed)
	game.cpu_stock_changed.connect(_on_cpu_stock_changed)
	game.game_over.connect(_on_game_over)
	game.card_moved.connect(_on_card_moved)
	game.build_completed.connect(_on_build_completed)
	board_ui.deck_clicked.connect(_on_deck_clicked)
	board_ui.build_clicked.connect(_on_build_clicked)
	player_ui.stock_clicked.connect(_on_player_stock_clicked)
	player_ui.hand_clicked.connect(_on_player_hand_clicked)
	player_ui.discard_clicked.connect(_on_player_discard_clicked)

	drag_card.visible = false
	drag_card.z_index = 10

	refresh_ui()

func _input(event):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			if game.selected_card != null:
				game.selected_card = null
				stop_drag()
				refresh_ui()

func _process(delta: float) -> void:
	if game.selected_card == null:
		drag_card.visible = false
		return

	var mouse = get_global_mouse_position()
	var target = mouse - drag_card.size * 0.25

	mouse_velocity = (mouse - prev_mouse_pos) / delta
	prev_mouse_pos = mouse

	drag_pos = drag_pos.lerp(target, delta * 15.0)
	drag_card.global_position = drag_pos
	drag_card.pivot_offset = drag_card.size / 2

	var tilt = clamp(mouse_velocity.x * 0.005, -15.0, 15.0)
	drag_card.rotation_degrees = lerpf(drag_card.rotation_degrees, tilt, delta * 10.0)
	drag_card.visible = true

## ─── SLOT NODE HELPERS ──────────────────────────────────────────────────────

func get_deck_node() -> Control:
	return board_ui.deck

func get_build_node(index: int) -> Control:
	return board_ui.build_piles[index]

func get_completed_node() -> Control:
	return board_ui.completed

func get_player_hand_node(index: int) -> Control:
	return player_ui.hand_slots[clamp(index, 0, player_ui.hand_slots.size() - 1)]

func get_cpu_hand_node(index: int) -> Control:
	return cpu_ui.hand_slots[clamp(index, 0, cpu_ui.hand_slots.size() - 1)]

func get_player_discard_node(index: int) -> Control:
	return player_ui.discard_piles[index]

func get_cpu_discard_node(index: int) -> Control:
	return cpu_ui.discard_piles[index]

func get_player_stock_node() -> Control:
	return player_ui.stock_slot

func get_cpu_stock_node() -> Control:
	return cpu_ui.stock_slot

func get_dest_rotation(dest: String, dest_index: int) -> float:
	if dest == "build":
		return board_ui.get_build_rotation(dest_index, game.build_piles)
	return 0.0

func get_src_rotation(source: String, source_index: int) -> float:
	if source == "build":
		return board_ui.get_build_rotation(source_index, game.build_piles)
	return 0.0

## ─── ANIMATION HANDLER ──────────────────────────────────────────────────────

func _on_card_moved(card_value: String, source: String, source_index: int, dest: String, dest_index: int, whose: String) -> void:
	is_animating = true
	var face_up := (whose == "human" or dest == "build")
	var dst_rot := get_dest_rotation(dest, dest_index)
	var src_rot : float = 0.0

	# Resolve destination node
	var dst_node : Control
	match dest:
		"build":
			dst_node = get_build_node(dest_index)
		"player_hand":
			dst_node = get_player_hand_node(dest_index)
		"cpu_hand":
			dst_node = get_cpu_hand_node(dest_index)
		"player_discard":
			dst_node = get_player_discard_node(dest_index)
		"cpu_discard":
			dst_node = get_cpu_discard_node(dest_index)
		_:
			refresh_ui()
			game.emit_signal("animation_done")
			return

	# Human plays: animate from cursor position
	if whose == "human" and source in ["hand", "discard", "stock"]:
		src_rot = human_play_rotation
		await anim.animate_card_from_pos(card_value, human_play_origin, dst_node, face_up, src_rot, dst_rot)
		refresh_ui()
		is_animating = false
		game.emit_signal("animation_done")
		return

	# Resolve source node for all other moves
	var src_node : Control
	match source:
		"deck":
			src_node = get_deck_node()
			src_rot = -90.0
			if whose == "human":
				await anim.animate_card_with_flip(card_value, src_node, dst_node, src_rot, dst_rot)
				refresh_ui()
				is_animating = false
				game.emit_signal("animation_done")
				return
			face_up = false
		"player_hand":
			src_node = get_player_hand_node(source_index)
		"cpu_hand":
			src_node = get_cpu_hand_node(source_index)
			if dest == "cpu_discard":
				await anim.animate_card_with_flip(card_value, src_node, dst_node, 180.0, 180.0)
				refresh_ui()
				is_animating = false
				game.emit_signal("animation_done")
				return
			face_up = (dest == "build")
		"stock":
			src_node = get_player_stock_node()
		"cpu_stock":
			src_node = get_cpu_stock_node()
			face_up = (dest == "build")
		"discard":
			src_node = get_player_discard_node(source_index)
		"cpu_discard":
			src_node = get_cpu_discard_node(source_index)
			face_up = true
		"build":
			src_node = get_build_node(source_index)
			src_rot = get_src_rotation("build", source_index)
		_:
			refresh_ui()
			game.emit_signal("animation_done")
			return

	await anim.animate_card(card_value, src_node, dst_node, face_up, src_rot, dst_rot)
	refresh_ui()
	is_animating = false
	game.emit_signal("animation_done")

func _on_build_completed(pile: Array, build_index: int) -> void:
	var build_node = get_build_node(build_index)
	var completed_node = get_completed_node()
	# Hide the joker layer immediately if present
	board_ui.build_joker_layers[build_index].visible = false

	var after_card = func(remaining: Array):
		if remaining.is_empty():
			build_node.texture_normal = null
		else:
			build_node.texture_normal = board_ui.card_to_texture(remaining.back())

	await anim.animate_completion(pile, build_node, completed_node, after_card)
	refresh_ui()
	is_animating = false
	game.emit_signal("animation_done")

## ─── DRAG ───────────────────────────────────────────────────────────────────

func card_to_texture(card: String) -> Texture2D:
	if card == "Joker":
		return load("res://Sprites/Cards/joker.png")
	return load("res://Sprites/Cards/" + card.to_lower().replace(" of ", "_") + ".png")

func start_drag(card_value: String, slot_node: Control):
	drag_card.texture = card_to_texture(card_value)
	var card_size = slot_node.get_global_rect().size  # 210x295, correct
	drag_card.size = card_size
	drag_card.pivot_offset = card_size / 2
	var mouse = get_global_mouse_position()
	drag_pos = mouse - card_size * 0.25
	prev_mouse_pos = mouse
	drag_card.visible = true

func stop_drag():
	human_play_rotation = drag_card.rotation_degrees
	human_play_origin = drag_pos
	drag_card.visible = false
	drag_card.rotation_degrees = 0.0

## ─── REFRESH ────────────────────────────────────────────────────────────────

func refresh_ui():
	board_ui.show_deck(game.deck.cards.size())
	board_ui.show_builds(game.build_piles)
	board_ui.show_completed(game.completed)
	player_ui.show_hand(game.player.hand, true)
	player_ui.show_stock(game.player.stock.back() if game.player.stock.size() > 0 else null, true)
	player_ui.show_discards(game.player.discards)
	cpu_ui.show_hand(game.cpu.hand, false)
	cpu_ui.show_stock(game.cpu.stock.back() if game.cpu.stock.size() > 0 else null, true)
	cpu_ui.show_discards(game.cpu.discards)

	if game.selected_card != null:
		var sc = game.selected_card
		match sc.source:
			"hand":
				player_ui.hand_slots[sc.index].texture_normal = null
			"stock":
				player_ui.stock_slot.texture_normal = load("res://Sprites/Cards/back.png")
			"discard":
				var pile = game.player.discards[sc.index]
				if pile.size() > 1:
					player_ui.discard_piles[sc.index].texture_normal = card_to_texture(pile[pile.size() - 2])
				else:
					player_ui.discard_piles[sc.index].texture_normal = null

## ─── GAME MANAGER SIGNALS ───────────────────────────────────────────────────

func _on_game_started():
	refresh_ui()

func _on_deck_count_changed(count: int):
	cards_left_label.text = str(count) + " cards left"

func _on_turn_changed(whose_turn: String, phase: String):
	match phase:
		"draw":
			if whose_turn == "human":
				turn_label.text = "Your turn:\nDraw cards"
			else:
				turn_label.text = "CPU is drawing..."
				await get_tree().create_timer(0.5).timeout
				game.cpu_take_turn()
		"play":
			turn_label.text = "Your turn:\nPlay cards or\ndiscard to end turn" if whose_turn == "human" else "CPU is playing..."
		"discard":
			turn_label.text = "CPU is discarding..."

func _on_player_stock_changed(count: int):
	player_stock_label.text = str(count) + " / " + str(game.player_stock_size)

func _on_cpu_stock_changed(count: int):
	cpu_stock_label.text = str(count) + " / " + str(game.player_stock_size)

func _on_game_over(winner: String):
	turn_label.text = "You win!" if winner == "human" else "CPU wins!"
	stop_drag()

## ─── UI SIGNALS ─────────────────────────────────────────────────────────────

func _on_start_button_pressed():
	game.start_game()
	start_button.visible = false
	menu.visible = false
	print("game started")

func _on_deck_clicked():
	if is_animating:
		return
	game.player_draw()

func _on_build_clicked(index):
	if is_animating:
		return
	if game.selected_card != null:
		stop_drag()
		game.try_play_to_build(index)

func _on_player_hand_clicked(index):
	if is_animating:
		return
	if game.selected_card != null:
		stop_drag()
	game.select_card_from_hand(index)
	if game.selected_card != null:
		start_drag(game.selected_card.value, get_player_hand_node(index))
		player_ui.hand_slots[game.selected_card.index].texture_normal = null

func _on_player_discard_clicked(index):
	if is_animating:
		return
	if game.selected_card != null and game.selected_card.source == "hand":
		stop_drag()
		game.try_play_to_discard(index)
	else:
		if game.selected_card != null:
			stop_drag()
		game.select_card_from_discard(index)
		if game.selected_card != null:
			start_drag(game.selected_card.value, get_player_discard_node(index))
			var pile = game.player.discards[index]
			if pile.size() > 1:
				player_ui.discard_piles[index].texture_normal = card_to_texture(pile[pile.size() - 2])
			else:
				player_ui.discard_piles[index].texture_normal = null

func _on_player_stock_clicked():
	if is_animating:
		return
	if game.selected_card != null:
		stop_drag()
	game.select_card_from_stock()
	if game.selected_card != null:
		start_drag(game.selected_card.value, get_player_stock_node())
		player_ui.stock_slot.texture_normal = load("res://Sprites/Cards/back.png")

## MENU UI
func _on_settings_button_pressed() -> void:
	pass # Replace with function body.

func _on_quit_button_pressed() -> void:
	get_tree().quit()
