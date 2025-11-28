extends SceneTree

func _init():
	print("Debugging Hero Portraits...")
	
	# Load HeroDatabase (it's an autoload, but we can load it manually for this test)
	var hero_db_script = load("res://scripts/autoloads/hero_database.gd")
	var hero_db = hero_db_script.new()
	hero_db._ready()
	
	var warrior = hero_db.get_hero("warrior")
	if warrior:
		print("Warrior ID: ", warrior.hero_id)
		print("Warrior Name: ", warrior.hero_name)
		if warrior.portrait:
			print("Warrior Portrait Path: ", warrior.portrait.resource_path)
		else:
			print("Warrior Portrait is NULL")
	else:
		print("Warrior NOT FOUND")
		
	var ranger = hero_db.get_hero("ranger")
	if ranger:
		print("Ranger ID: ", ranger.hero_id)
		if ranger.portrait:
			print("Ranger Portrait Path: ", ranger.portrait.resource_path)
	
	quit()
