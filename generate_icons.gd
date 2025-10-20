extends Node

func _ready():
	var IconGen = load("res://scripts/utils/item_icon_generator.gd")
	IconGen.generate_all_icons()
	print("Icons generated! Check assets/icons/items/ folder")
	get_tree().quit()
