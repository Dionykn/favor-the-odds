extends Control

@onready var player = $Player

@export var jokers = 20
@export var numb_of_decks = 3
@export var player_deck_size = 25
@export var player_hand_size = 5

var suits = ["Hearts","Diamonds","Clubs","Spades"]
var ranks = ["Ace","2","3","4","5","6","7","8","9","10","Jack","Queen","King"]

var deck = []
var pile1 = []
var pile2 = []
var pile3 = []
var pile4 = []
var discard_pile = []

var cpu_deck = []
var cpu_hand = []
var cpu_discard1 = []
var cpu_discard2 = []
var cpu_discard3 = []
var cpu_discard4 = []
@onready var cpu_hand_slots = [
	$Cpu/Hand1,
	$Cpu/Hand2,
	$Cpu/Hand3,
	$Cpu/Hand4,
	$Cpu/Hand5
]

var player_deck = []
var player_hand = []
var player_discard1 = []
var player_discard2 = []
var player_discard3 = []
var player_discard4 = []
@onready var player_hand_slots = [
	$Player/Hand1,
	$Player/Hand2,
	$Player/Hand3,
	$Player/Hand4,
	$Player/Hand5
]

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# Setup board
	$draw_card.visible = false
	# Clear hands
	for i in range(player_hand_slots.size()):
		player_hand_slots[i].visible = i < player_hand.size()	
	for i in range(cpu_hand_slots.size()):
		cpu_hand_slots[i].visible = i < player_hand.size()	
	


	## Deal cards
	#for i in range(player_deck_size):
		#var drawn_card = deck.pop_back()
		#player_deck.append(drawn_card)
		#drawn_card = deck.pop_back()
		#cpu_deck.append(drawn_card)
		#print("Dealt each "+ str(i+1) +" cards", player_deck, cpu_deck)
		
	# Update board
	$"<CARDS LEFT>".text = str(deck.size()) + " cards left"
	$"<CARD DRAWN>".text = "No card drawn"
	
	
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func create_deck():
	var new_deck = []
	for n in range(numb_of_decks):
		for s in suits:
			for r in ranks:
				var new_card = str(r+" of "+s)
				new_deck.append(new_card)
	for j in range(jokers):
		var new_card = str("Joker")
		new_deck.append(new_card)
	new_deck.shuffle()
	deck = new_deck
	print(deck)
	
func update_hand(drawn_card: String):
	var index = player_hand.size() - 1
	var file = card_to_file(drawn_card)
	player_hand_slots[index].texture_normal = load("res://Sprites/Cards/" + file)
	player_hand_slots[index].visible = true
	for i in range(player_hand_slots.size()):
		player_hand_slots[i].visible = i < player_hand.size()


func card_to_file(drawn_card: String) -> String:
	var file = ""
	if drawn_card == "Joker":
		file = drawn_card.to_lower()+".jpg"
	else:
		var sub = drawn_card.to_lower()
		file = sub.replace(" of ","_")+".jpg"
	return file
			
func _on_draw_card_pressed() -> void:
	if deck.size() == 0:
		create_deck()
	if player_hand.size() < player_hand_size:
		var drawn_card = deck.pop_back()
		player_hand.append(drawn_card)
		update_hand(drawn_card)
		$"<CARD DRAWN>".text = str(drawn_card)
	if player_hand.size() >= player_hand_size:
		$draw_card.visible = false
	$"<CARDS LEFT>".text = str(deck.size()) + " cards left"

func _on_start_game_pressed() -> void:
	# Setup deck
	create_deck()
	$Board/Deck.texture_normal = load("res://Sprites/Cards/back.jpg")
	# Deal cards
	for i in range(player_deck_size):
		var drawn_card = deck.pop_back()
		player_deck.append(drawn_card)
		drawn_card = deck.pop_back()
		cpu_deck.append(drawn_card)
		print("Dealt each "+ str(i+1) +" cards", player_deck, cpu_deck)
	$Player/PlayerDeck.texture_normal = load("res://Sprites/Cards/back.jpg")
	$Cpu/CpuDeck.texture_normal = load("res://Sprites/Cards/" + card_to_file(cpu_deck.back()))
	$"<CARDS LEFT>".text = str(deck.size()) + " cards left"
	$start_game.visible = false
	$draw_card.visible = true


func _on_player_deck_pressed() -> void:
	if $Player/PlayerDeck.texture_normal == load("res://Sprites/Cards/back.jpg"):
		$Player/PlayerDeck.texture_normal = load("res://Sprites/Cards/" + card_to_file(player_deck.back()))
