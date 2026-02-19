extends Node
class_name Deck

var cards = []

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func build():
	pass
	
func shuffle():
	cards.shuffle()

func draw() -> String:
	return cards.pop_back()
