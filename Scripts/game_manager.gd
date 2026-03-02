extends Node
class_name GameManager

@export var player_stock_size := 25
@export var player_hand_size := 5

var deck : Deck
var player : Player
var cpu : Player
var build_piles = [[],[],[],[]]
var completed = []

var selected_card = null
var current_turn = "human"
var turn_phase = "draw"

signal game_started
signal player_hand_changed
signal cpu_hand_changed
signal deck_count_changed(count:int)
signal player_stock_changed(count:int)
signal cpu_stock_changed(count:int)
signal turn_changed(whose_turn:String, phase:String)
signal game_over(winner:String)
signal card_moved(card_value:String, source:String, source_index:int, dest:String, dest_index:int, whose:String)
signal build_completed(pile:Array, build_index:int)
signal animation_done  # emitted by main.gd after each animation finishes

func _ready():
	deck = Deck.new()
	player = Player.new()
	cpu = Player.new()

func start_game():
	deck.build()
	player.stock.clear()
	cpu.stock.clear()
	player.hand.clear()
	cpu.hand.clear()
	build_piles = [[],[],[],[]]
	completed = []
	selected_card = null

	for i in range(player_stock_size):
		player.stock.append(deck.draw())
		cpu.stock.append(deck.draw())

	determine_first_player()
	emit_signal("game_started")
	emit_signal("deck_count_changed", deck.cards.size())
	emit_signal("player_stock_changed", player.stock.size())
	emit_signal("cpu_stock_changed", cpu.stock.size())
	emit_signal("turn_changed", current_turn, turn_phase)

func determine_first_player():
	var player_top = card_to_value(player.stock.back())
	var cpu_top = card_to_value(cpu.stock.back())
	if player_top == 0: player_top = 1
	if cpu_top == 0: cpu_top = 1
	current_turn = "cpu" if cpu_top < player_top else "human"
	turn_phase = "draw"

## ─── DRAWING ────────────────────────────────────────────────────────────────

func player_draw():
	if current_turn != "human" or turn_phase != "draw":
		return
	if player.hand.size() >= player_hand_size:
		turn_phase = "play"
		emit_signal("turn_changed", current_turn, turn_phase)
		return
	if deck.cards.is_empty():
		refill_deck()

	var card = deck.draw()
	var hand_index = player.hand.size()
	player.hand.append(card)

	emit_signal("card_moved", card, "deck", -1, "player_hand", hand_index, "human")
	emit_signal("deck_count_changed", deck.cards.size())

	if player.hand.size() >= player_hand_size:
		turn_phase = "play"
		emit_signal("turn_changed", current_turn, turn_phase)

func refill_deck():
	if completed.is_empty():
		deck.build()
	else:
		deck.rebuild_from_completed(completed)
		completed.clear()
	emit_signal("deck_count_changed", deck.cards.size())

## ─── SELECTION ──────────────────────────────────────────────────────────────

func select_card_from_hand(index):
	if current_turn != "human" or turn_phase != "play":
		return
	selected_card = {"value": player.hand[index], "player": "human", "source": "hand", "index": index}

func select_card_from_discard(index):
	if current_turn != "human" or turn_phase != "play":
		return
	if player.discards[index].is_empty():
		return
	selected_card = {"value": player.discards[index].back(), "player": "human", "source": "discard", "index": index}

func select_card_from_stock():
	if current_turn != "human" or turn_phase != "play":
		return
	if player.stock.is_empty():
		return
	selected_card = {"value": player.stock.back(), "player": "human", "source": "stock"}

## ─── PLAYING TO BUILD ───────────────────────────────────────────────────────

func try_play_to_build(build_index):
	if selected_card == null:
		return
	if current_turn != "human" or turn_phase != "play":
		return

	var card_value = card_to_value(selected_card.value)
	var effective_top = build_piles[build_index].size()

	if card_value != effective_top + 1 and card_value != 0:
		print("Illegal move:", selected_card.value, "onto pile", build_index)
		return

	var src = selected_card.source
	var src_index = selected_card.get("index", -1)
	var card_val = selected_card.value

	move_card_to_build(build_index)

	if build_piles[build_index].size() == 13:
		var pile_copy = build_piles[build_index].duplicate()
		completed += build_piles[build_index]
		build_piles[build_index].clear()
		emit_signal("build_completed", pile_copy, build_index)
	else:
		emit_signal("card_moved", card_val, src, src_index, "build", build_index, "human")

	selected_card = null
	check_win()

	if player.hand.is_empty() and turn_phase == "play":
		turn_phase = "draw"
		emit_signal("turn_changed", current_turn, turn_phase)

func move_card_to_build(build_index):
	var player_obj = player if selected_card.player == "human" else cpu
	var src = selected_card.source
	var card = ""

	if src == "hand":
		card = player_obj.hand.pop_at(selected_card.index)
	elif src == "stock":
		card = player_obj.stock.pop_back()
		emit_signal("player_stock_changed", player.stock.size())
	elif src == "discard":
		card = player_obj.discards[selected_card.index].pop_back()

	build_piles[build_index].append(card)

## ─── DISCARD ────────────────────────────────────────────────────────────────

func try_play_to_discard(discard_index):
	if selected_card == null:
		return
	if current_turn != "human" or turn_phase != "play":
		return
	if selected_card.source != "hand":
		print("Can only discard from hand")
		return

	var src_index = selected_card.index
	var card = player.hand[src_index]
	player.hand.remove_at(src_index)
	player.discards[discard_index].append(card)

	emit_signal("card_moved", card, "hand", src_index, "player_discard", discard_index, "human")
	selected_card = null
	end_human_turn()

func end_human_turn():
	current_turn = "cpu"
	turn_phase = "draw"
	selected_card = null
	emit_signal("turn_changed", current_turn, turn_phase)

## ─── CPU AI ─────────────────────────────────────────────────────────────────

func cpu_take_turn():
	# Draw phase — one card at a time, wait for each animation
	while cpu.hand.size() < player_hand_size:
		if deck.cards.is_empty():
			refill_deck()
		var card = deck.draw()
		var hand_index = cpu.hand.size()
		cpu.hand.append(card)
		emit_signal("card_moved", card, "deck", -1, "cpu_hand", hand_index, "cpu")
		await get_tree().process_frame
		await animation_done

	emit_signal("cpu_hand_changed")
	emit_signal("deck_count_changed", deck.cards.size())
	emit_signal("turn_changed", current_turn, "play")
	await get_tree().create_timer(0.3).timeout

	# Play phase — one move at a time, wait for each animation
	var moved = true
	while moved:
		moved = false

		# Stock first
		if not cpu.stock.is_empty():
			for i in range(build_piles.size()):
				var card = cpu.stock.back()
				var val = card_to_value(card)
				if val == build_piles[i].size() + 1 or val == 0:
					selected_card = {"value": card, "player": "cpu", "source": "stock"}
					move_card_to_build(i)
					if build_piles[i].size() == 13:
						var pile_copy = build_piles[i].duplicate()
						completed += build_piles[i]
						build_piles[i].clear()
						emit_signal("build_completed", pile_copy, i)
					else:
						emit_signal("card_moved", card, "cpu_stock", -1, "build", i, "cpu")
					selected_card = null
					await get_tree().process_frame
					await animation_done
					moved = true
					emit_signal("cpu_stock_changed", cpu.stock.size())
					check_win()
					break

		# Hand second
		if not moved:
			for h in range(cpu.hand.size()):
				for i in range(build_piles.size()):
					var card = cpu.hand[h]
					var val = card_to_value(card)
					if val == build_piles[i].size() + 1 or val == 0:
						selected_card = {"value": card, "player": "cpu", "source": "hand", "index": h}
						move_card_to_build(i)
						if build_piles[i].size() == 13:
							var pile_copy = build_piles[i].duplicate()
							completed += build_piles[i]
							build_piles[i].clear()
							emit_signal("build_completed", pile_copy, i)
						else:
							emit_signal("card_moved", card, "cpu_hand", h, "build", i, "cpu")
						selected_card = null
						await get_tree().process_frame
						await animation_done
						moved = true
						check_win()
						break
				if moved:
					break

		# Discard third
		if not moved:
			for d in range(cpu.discards.size()):
				if cpu.discards[d].is_empty():
					continue
				for i in range(build_piles.size()):
					var card = cpu.discards[d].back()
					var val = card_to_value(card)
					if val == build_piles[i].size() + 1 or val == 0:
						selected_card = {"value": card, "player": "cpu", "source": "discard", "index": d}
						move_card_to_build(i)
						if build_piles[i].size() == 13:
							var pile_copy = build_piles[i].duplicate()
							completed += build_piles[i]
							build_piles[i].clear()
							emit_signal("build_completed", pile_copy, i)
						else:
							emit_signal("card_moved", card, "cpu_discard", d, "build", i, "cpu")
						selected_card = null
						await get_tree().process_frame
						await animation_done
						moved = true
						check_win()
						break
				if moved:
					break

		# Refill hand if empty mid-play
		if cpu.hand.is_empty():
			while cpu.hand.size() < player_hand_size:
				if deck.cards.is_empty():
					refill_deck()
				var card = deck.draw()
				var hand_index = cpu.hand.size()
				cpu.hand.append(card)
				emit_signal("card_moved", card, "deck", -1, "cpu_hand", hand_index, "cpu")
				await get_tree().process_frame
				await animation_done
			emit_signal("cpu_hand_changed")
			emit_signal("deck_count_changed", deck.cards.size())

	# Discard to end turn
	if not cpu.hand.is_empty():
		var card = cpu.hand[0]
		cpu.discards[0].append(cpu.hand.pop_at(0))
		emit_signal("card_moved", card, "cpu_hand", 0, "cpu_discard", 0, "cpu")
		await get_tree().process_frame
		await animation_done
		emit_signal("cpu_hand_changed")
		emit_signal("turn_changed", current_turn, "discard")
		await get_tree().create_timer(0.3).timeout

	current_turn = "human"
	turn_phase = "draw"
	emit_signal("turn_changed", "human", "draw")

## ─── WIN CHECK ──────────────────────────────────────────────────────────────

func check_win():
	if player.stock.is_empty():
		emit_signal("game_over", "human")
	elif cpu.stock.is_empty():
		emit_signal("game_over", "cpu")

## ─── HELPERS ────────────────────────────────────────────────────────────────

func card_to_value(card:String) -> int:
	if card == "Joker":
		return 0
	var rank = card.split(" ")[0]
	match rank:
		"Ace": return 1
		"2": return 2
		"3": return 3
		"4": return 4
		"5": return 5
		"6": return 6
		"7": return 7
		"8": return 8
		"9": return 9
		"10": return 10
		"Jack": return 11
		"Queen": return 12
		"King": return 13
		_: return 0
