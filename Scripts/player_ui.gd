extends Control
class_name PlayerUI

#@export var face_up := true

signal stock_clicked
signal hand_clicked
signal discard_clicked

@onready var hand_slots = [
	$Hand1, $Hand2, $Hand3, $Hand4, $Hand5
]
@onready var stock_slot = $Stock
@onready var discard_piles = [
	$Discard1, $Discard2, $Discard3, $Discard4
]

func _ready():
	for i in range(hand_slots.size()):
		hand_slots[i].pressed.connect(_on_hand_pressed.bind(i))
	for i in range(discard_piles.size()):
		discard_piles[i].pressed.connect(_on_discard_pressed.bind(i))

func _on_hand_pressed(index):
	emit_signal("hand_clicked", index)	

func _on_discard_pressed(index):
	emit_signal("discard_clicked", index)

func _on_stock_pressed():
	emit_signal("stock_clicked")

func card_to_texture(card:String) -> Texture2D:
	var file := ""
	if card == "Joker":
		file = "joker.png"
	else:
		file = card.to_lower().replace(" of ","_") + ".png"
	return load("res://Sprites/Cards/" + file)

func show_hand(cards:Array, face_up:bool):
	for i in range(hand_slots.size()):
		if i < cards.size():
			var tex = card_to_texture(cards[i]) if face_up else load("res://Sprites/Cards/back.png")
			hand_slots[i].texture_normal = tex
			hand_slots[i].visible = true
		else:
			hand_slots[i].visible = false

func show_stock(card, face_up:bool):
	if card == null:
		stock_slot.texture_normal = null
		return
	stock_slot.texture_normal = card_to_texture(card) if face_up else load("res://Sprites/Cards/back.png")

func show_discards(discards:Array):
	for i in range(discard_piles.size()):
		if discards[i].size() > 0:
			discard_piles[i].texture_normal = card_to_texture(discards[i].back())
		else:
			discard_piles[i].texture_normal = null
