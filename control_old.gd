extends Control

@onready var player = $Player

@export var jokers = 4
@export var numb_of_decks = 1
@export var player_deck_size = 25

var suits = ["Hearts","Diamonds","Clubs","Spades"]
var ranks = ["Ace","2","3","4","5","6","7","8","9","10","Jack","Queen","King"]

var deck = []
var pile1 = []
var pile2 = []
var pile3 = []
var pile4 = []
var discart_deck = []

var cpu_deck = []
var cpu_hand = []
var enemy_discart1 = []
var enemy_discart2 = []
var enemy_discart3 = []
var enemy_discart4 = []

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	var deck_size = (suits.size()*ranks.size()+jokers)*numb_of_decks
	print(deck_size)
	create_deck()
	
	$"<CARDS LEFT>".text = str(deck.size()) + " cards left"
	$"<CARD DRAWN>".text = "No card drawn"

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func create_deck():
	var new_deck = []
	for s in suits:
		for r in ranks:
			var new_card = str(r+" of "+s)
			new_deck.append(new_card)
	for j in range(jokers):
		var new_card = str("Joker")
		new_deck.append(new_card)
	new_deck.shuffle()
	deck.append_array(new_deck)
	print(deck)
			
func _on_draw_card_pressed() -> void:
	if deck.size() == 0:
		create_deck()
	var drawn_card = deck.pop_back()
	$"<CARD DRAWN>".text = str(drawn_card)
	$"<CARDS LEFT>".text = str(deck.size()) + " cards left"
	player.player_hand.append(drawn_card)
