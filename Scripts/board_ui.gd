extends Control

@onready var deck = $Deck
@onready var build_piles = [
	$Build1, $Build2, $Build3, $Build4
]
@onready var build_joker_layers = [
	$Build1/JokerLayer, $Build2/JokerLayer, $Build3/JokerLayer, $Build4/JokerLayer
]
@onready var completed = $Discard

signal deck_clicked
signal build_clicked

func _ready() -> void:
	for i in range(build_piles.size()):
		build_piles[i].pressed.connect(_on_build_pressed.bind(i))
	for layer in build_joker_layers:
		layer.visible = false
		#layer.pivot_offset = layer.size / 2
		layer.rotation_degrees = 10.0
		layer.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _on_deck_pressed() -> void:
	emit_signal("deck_clicked")

func _on_build_pressed(index):
	emit_signal("build_clicked", index)

func card_to_texture(card:String) -> Texture2D:
	var file := ""
	if card == "Joker":
		file = "joker.png"
	else:
		file = card.to_lower().replace(" of ","_") + ".png"
	return load("res://Sprites/Cards/" + file)

func show_deck(size:int):
	if size > 0:
		deck.texture_normal = preload("res://Sprites/Cards/back.png")
	else:
		deck.texture_normal = null

func show_builds(builds:Array):
	for i in range(build_piles.size()):
		var pile = builds[i]
		var joker_layer = build_joker_layers[i]

		if pile.is_empty():
			build_piles[i].texture_normal = null
			joker_layer.visible = false
			continue

		var top_card = pile.back()

		if top_card == "Joker":
			if pile.size() > 1:
				build_piles[i].texture_normal = card_to_texture(pile[pile.size() - 2])
			else:
				build_piles[i].texture_normal = null
			joker_layer.texture = card_to_texture("Joker")
			joker_layer.pivot_offset = joker_layer.size / 2
			joker_layer.visible = true
		else:
			build_piles[i].texture_normal = card_to_texture(top_card)
			joker_layer.visible = false

## Returns the rotation the top card is visually at for a given build pile.
## Used by animation manager to tween rotation correctly on arrival.
func get_build_rotation(index: int, builds: Array) -> float:
	if builds[index].is_empty():
		return 0.0
	if builds[index].back() == "Joker":
		return 15.0
	return 0.0

func show_completed(compl:Array):
	if compl.size() > 0:
		completed.visible = true
	else:
		completed.visible = false
