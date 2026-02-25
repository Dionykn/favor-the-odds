extends Node
class_name Deck

@export var jokers := 20
@export var numb_of_decks := 3

var suits = ["Hearts","Diamonds","Clubs","Spades"]
var ranks = ["Ace","2","3","4","5","6","7","8","9","10","Jack","Queen","King"]

var cards = []

func build():
	cards.clear()
	for n in range(numb_of_decks):
		for s in suits:
			for r in ranks:
				cards.append(r + " of " + s)
	for j in range(jokers):
		cards.append("Joker")
	shuffle(cards)

func shuffle(array):
	array.shuffle()

func draw() -> String:
	return cards.pop_back()

func rebuild_from_completed(completed_cards:Array):
	cards.clear()
	cards = completed_cards.duplicate()
	shuffle(cards)
