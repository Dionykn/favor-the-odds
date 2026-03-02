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
## Standalone helper functions for CPU strategy.
## Call cpu_take_turn() to run the CPU's full turn.

## Represents a simulated game state for lookahead
class SimState:
	var build_piles: Array       # Array of Arrays
	var stock: Array             # cpu stock
	var hand: Array              # cpu hand
	var discards: Array          # cpu discards (Array of Arrays)
	var moves: Array             # sequence of moves taken to reach this state

	func _init(bp, st, ha, di, mv):
		build_piles = []
		for p in bp:
			build_piles.append(p.duplicate())
		stock = st.duplicate()
		hand = ha.duplicate()
		discards = []
		for d in di:
			discards.append(d.duplicate())
		moves = mv.duplicate()

	func clone() -> SimState:
		return SimState.new(build_piles, stock, hand, discards, moves)

## Returns true if card can be played onto build pile index in given state
func sim_can_play(card: String, pile_index: int, state: SimState) -> bool:
	var val = card_to_value(card)
	var pile_size = state.build_piles[pile_index].size()
	return val == pile_size + 1 or val == 0

## Apply a move to a SimState, returns new SimState or null if invalid
func sim_apply_move(move: Dictionary, state: SimState) -> SimState:
	var new_state = state.clone()
	var card = move.card
	var pile = move.pile

	if not sim_can_play(card, pile, new_state):
		return null

	match move.source:
		"stock":
			if new_state.stock.is_empty() or new_state.stock.back() != card:
				return null
			new_state.stock.pop_back()
		"hand":
			var idx = new_state.hand.find(card, 0)
			if idx == -1:
				# find by index if provided
				idx = move.get("index", -1)
				if idx == -1 or idx >= new_state.hand.size() or new_state.hand[idx] != card:
					return null
			new_state.hand.remove_at(idx)
		"discard":
			var d = move.get("discard_index", -1)
			if d == -1 or new_state.discards[d].is_empty() or new_state.discards[d].back() != card:
				return null
			new_state.discards[d].pop_back()

	new_state.build_piles[pile].append(card)
	if new_state.build_piles[pile].size() == 13:
		new_state.build_piles[pile].clear()

	new_state.moves.append(move)
	return new_state

## Returns all possible single moves from a SimState (non-joker and joker)
func sim_get_moves(state: SimState) -> Array:
	var moves = []

	# Stock
	if not state.stock.is_empty():
		var card = state.stock.back()
		for i in range(state.build_piles.size()):
			if sim_can_play(card, i, state):
				moves.append({"card": card, "source": "stock", "pile": i})

	# Hand
	for h in range(state.hand.size()):
		var card = state.hand[h]
		for i in range(state.build_piles.size()):
			if sim_can_play(card, i, state):
				moves.append({"card": card, "source": "hand", "index": h, "pile": i})

	# Discard tops
	for d in range(state.discards.size()):
		if state.discards[d].is_empty():
			continue
		var card = state.discards[d].back()
		for i in range(state.build_piles.size()):
			if sim_can_play(card, i, state):
				moves.append({"card": card, "source": "discard", "discard_index": d, "pile": i})

	return moves

## Phase 1: BFS lookahead to find shortest move sequence ending with stock played.
## Returns the move sequence Array or empty if no path found.
func find_path_to_stock(max_depth: int = 10) -> Array:
	if cpu.stock.is_empty():
		return []

	var initial = SimState.new(build_piles, cpu.stock, cpu.hand, cpu.discards, [])
	var queue = [initial]

	while not queue.is_empty():
		var state = queue.pop_front()

		if state.moves.size() >= max_depth:
			continue

		var moves = sim_get_moves(state)
		for move in moves:
			var new_state = sim_apply_move(move, state)
			if new_state == null:
				continue

			# Check if stock was just played
			if move.source == "stock":
				return new_state.moves

			queue.append(new_state)

	return []

## Check if the current board state gives the opponent an opening.
## An opening means: opponent stock card is directly playable, or
## a chain through opponent's visible discard tops leads to their stock card.
func board_has_opening(piles: Array) -> bool:
	if player.stock.is_empty():
		return false

	var stock_val = card_to_value(player.stock.back())
	if stock_val == 0:
		stock_val = 1  # Joker as stock - treat as 1

	# Collect opponent's visible cards (stock top + discard tops), excluding jokers
	var visible = []
	for d in player.discards:
		if not d.is_empty():
			var v = card_to_value(d.back())
			if v != 0:
				visible.append(v)

	# Check each pile
	for pile in piles:
		var pile_size = pile.size()
		# Direct play
		if stock_val == pile_size + 1:
			return true
		# Chain: can visible discard cards fill the gap to stock?
		if stock_val > pile_size + 1:
			var needed = range(pile_size + 1, stock_val)  # values needed to bridge
			var can_fill = true
			for v in needed:
				if not v in visible:
					can_fill = false
					break
			if can_fill:
				return true

	return false

## Find a card that closes an opening (advances a dangerous pile past the threat).
## Returns a move dict or null.
func find_blocking_move(from_hand_only: bool = false) -> Dictionary:
	if player.stock.is_empty():
		return {}

	var stock_val = card_to_value(player.stock.back())
	if stock_val == 0:
		stock_val = 1

	# Find which piles are dangerous
	for pile_idx in range(build_piles.size()):
		var pile = build_piles[pile_idx]
		var pile_size = pile.size()
		var is_dangerous = false

		if stock_val == pile_size + 1:
			is_dangerous = true
		elif stock_val > pile_size + 1:
			var visible = []
			for d in player.discards:
				if not d.is_empty():
					var v = card_to_value(d.back())
					if v != 0:
						visible.append(v)
			var needed = range(pile_size + 1, stock_val)
			var can_fill = true
			for v in needed:
				if not v in visible:
					can_fill = false
					break
			if can_fill:
				is_dangerous = true

		if not is_dangerous:
			continue

		# Try to close this pile with a non-joker
		var next_val = pile_size + 1
		# Hand
		for h in range(cpu.hand.size()):
			var card = cpu.hand[h]
			var val = card_to_value(card)
			if val == next_val:
				return {"card": card, "source": "hand", "index": h, "pile": pile_idx}
		# Discard (only if not from_hand_only)
		if not from_hand_only:
			for d in range(cpu.discards.size()):
				if cpu.discards[d].is_empty():
					continue
				var card = cpu.discards[d].back()
				var val = card_to_value(card)
				if val == next_val:
					return {"card": card, "source": "discard", "discard_index": d, "pile": pile_idx}
		# Joker as last resort
		for h in range(cpu.hand.size()):
			if cpu.hand[h] == "Joker":
				return {"card": "Joker", "source": "hand", "index": h, "pile": pile_idx}

	return {}

## Execute a move dict on the real game state and emit signals
## Phase 2: hand clearance with blocking.
## Returns true if any move was made.
func cpu_hand_clearance_step() -> Dictionary:
	# Step 1: find safe non-joker hand plays
	for h in range(cpu.hand.size()):
		var card = cpu.hand[h]
		if card == "Joker":
			continue
		var val = card_to_value(card)
		for i in range(build_piles.size()):
			if val == build_piles[i].size() + 1:
				# Simulate this play and check if board would be safe
				var sim_piles = []
				for p in build_piles:
					sim_piles.append(p.duplicate())
				sim_piles[i].append(card)
				if sim_piles[i].size() == 13:
					sim_piles[i].clear()
				if not board_has_opening(sim_piles):
					return {"card": card, "source": "hand", "index": h, "pile": i}

	# Step 2: close existing openings
	var block = find_blocking_move()
	if not block.is_empty():
		return block

	# Step 3: unsafe hand plays - pick pile furthest from opponent stock
	var best_move = {}
	var best_distance = -1
	if not player.stock.is_empty():
		var stock_val = card_to_value(player.stock.back())
		if stock_val == 0: stock_val = 1
		for h in range(cpu.hand.size()):
			var card = cpu.hand[h]
			if card == "Joker":
				continue
			var val = card_to_value(card)
			for i in range(build_piles.size()):
				if val == build_piles[i].size() + 1:
					var resulting_size = build_piles[i].size() + 1
					var distance = abs(stock_val - (resulting_size + 1))
					if distance > best_distance:
						best_distance = distance
						best_move = {"card": card, "source": "hand", "index": h, "pile": i}

	if not best_move.is_empty():
		return best_move

	# Step 4: joker combos - only if joker unlocks at least one non-joker hand card
	for h in range(cpu.hand.size()):
		if cpu.hand[h] != "Joker":
			continue
		for i in range(build_piles.size()):
			# Simulate joker on pile i
			var sim_piles = []
			for p in build_piles:
				sim_piles.append(p.duplicate())
			sim_piles[i].append("Joker")
			if sim_piles[i].size() == 13:
				sim_piles[i].clear()
				continue
			var next_val = sim_piles[i].size() + 1
			# Check if any non-joker hand card becomes playable
			for hh in range(cpu.hand.size()):
				if hh == h: continue
				var other = cpu.hand[hh]
				if other == "Joker": continue
				if card_to_value(other) == next_val:
					return {"card": "Joker", "source": "hand", "index": h, "pile": i}

	return {}

## Choose discard slot: prefer matching value, then empty, then slot 0
func cpu_choose_discard_slot(card: String) -> int:
	var val = card_to_value(card)
	# Prefer matching value
	for d in range(cpu.discards.size()):
		if not cpu.discards[d].is_empty() and card_to_value(cpu.discards[d].back()) == val:
			return d
	# Empty slot
	for d in range(cpu.discards.size()):
		if cpu.discards[d].is_empty():
			return d
	# Fallback slot 0
	return 0

## Choose which hand card to discard: never a joker, pick least useful
func cpu_choose_discard_card() -> int:
	# Never discard a joker - find first non-joker
	for h in range(cpu.hand.size()):
		if cpu.hand[h] != "Joker":
			return h
	# All jokers (shouldn't happen but fallback)
	return 0

func cpu_take_turn():
	# ── Draw phase ──────────────────────────────────────────────────────────
	while cpu.hand.size() < player_hand_size:
		if deck.cards.is_empty():
			refill_deck()
		var card = deck.draw()
		var hand_index = cpu.hand.size()
		cpu.hand.append(card)
		emit_signal("card_moved", card, "deck", -1, "cpu_hand", hand_index, "cpu")
		emit_signal("deck_count_changed", deck.cards.size())
		await get_tree().process_frame
		await animation_done

	emit_signal("cpu_hand_changed")
	emit_signal("turn_changed", current_turn, "play")
	await get_tree().create_timer(0.3).timeout

	# ── Play phase ───────────────────────────────────────────────────────────
	var keep_playing = true
	while keep_playing:
		keep_playing = false

		# Refill hand if empty before deciding next move
		if cpu.hand.is_empty():
			while cpu.hand.size() < player_hand_size:
				if deck.cards.is_empty():
					refill_deck()
				var drawn = deck.draw()
				var hand_index = cpu.hand.size()
				cpu.hand.append(drawn)
				emit_signal("card_moved", drawn, "deck", -1, "cpu_hand", hand_index, "cpu")
				emit_signal("deck_count_changed", deck.cards.size())
				await get_tree().process_frame
				await animation_done
			emit_signal("cpu_hand_changed")

		# Phase 1: find path to stock
		var path = find_path_to_stock()
		if not path.is_empty():
			for move in path:
				await cpu_execute_move_async(move)
				check_win()
			keep_playing = true
			continue

		# Phase 2: hand clearance with blocking
		var move = cpu_hand_clearance_step()
		if not move.is_empty():
			await cpu_execute_move_async(move)
			check_win()
			keep_playing = true
			continue

	# ── Pre-discard: close any opening with a joker if needed ────────────────
	if board_has_opening(build_piles):
		var block = find_blocking_move()
		if not block.is_empty() and block.source == "hand" and cpu.hand[block.index] == "Joker":
			await cpu_execute_move_async(block)

	# ── Discard phase ────────────────────────────────────────────────────────
	if not cpu.hand.is_empty():
		var discard_idx = cpu_choose_discard_card()
		var card = cpu.hand[discard_idx]
		var slot = cpu_choose_discard_slot(card)
		cpu.discards[slot].append(cpu.hand.pop_at(discard_idx))
		emit_signal("card_moved", card, "cpu_hand", discard_idx, "cpu_discard", slot, "cpu")
		await get_tree().process_frame
		await animation_done
		emit_signal("cpu_hand_changed")
		emit_signal("turn_changed", current_turn, "discard")
		await get_tree().create_timer(0.3).timeout

	# ── End turn ─────────────────────────────────────────────────────────────
	current_turn = "human"
	turn_phase = "draw"
	emit_signal("turn_changed", "human", "draw")

## Executes a CPU move: always animates card to pile first, then handles completion
func cpu_execute_move_async(move: Dictionary) -> void:
	var card = move.card
	var pile = move.pile

	selected_card = {"value": card, "player": "cpu", "source": move.source}
	if move.source == "hand":
		selected_card["index"] = move.index
	elif move.source == "discard":
		selected_card["source"] = "discard"
		selected_card["index"] = move.discard_index
	elif move.source == "stock":
		selected_card["source"] = "stock"

	move_card_to_build(pile)
	selected_card = null
	emit_signal("cpu_stock_changed", cpu.stock.size())

	# Resolve source label for animation
	var src_label = move.source
	var src_idx = -1
	if move.source == "hand":
		src_label = "cpu_hand"
		src_idx = move.get("index", -1)
	elif move.source == "discard":
		src_label = "cpu_discard"
		src_idx = move.get("discard_index", -1)
	elif move.source == "stock":
		src_label = "cpu_stock"

	# Always animate the card moving to the pile first
	emit_signal("card_moved", card, src_label, src_idx, "build", pile, "cpu")
	await get_tree().process_frame
	await animation_done

	# Then check if pile completed and animate that separately
	if build_piles[pile].size() == 13:
		var pile_copy = build_piles[pile].duplicate()
		completed += build_piles[pile]
		build_piles[pile].clear()
		emit_signal("build_completed", pile_copy, pile)
		await get_tree().process_frame
		await animation_done

	check_win()


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
