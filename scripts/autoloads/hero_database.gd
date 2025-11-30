extends Node

## HeroDatabase - Autoload Singleton
## Loads and manages all HeroData resources from the game
## Provides fast lookup by hero_id

signal heroes_loaded

var heroes: Dictionary = {} ## {hero_id: HeroData}
var heroes_by_class: Dictionary = {} ## {HeroClass: Array[HeroData]}
var heroes_loaded_flag: bool = false

const HEROES_PATH = "res://resources/heroes/"


func _ready():
	load_all_heroes()


## Load all HeroData resources from the heroes directory
func load_all_heroes():
	heroes.clear()
	heroes_by_class.clear()

	# Initialize class dictionaries
	for hero_class in HeroData.HeroClass.values():
		var class_array: Array[HeroData] = []
		heroes_by_class[hero_class] = class_array

	# Load all heroes from subdirectories
	_load_heroes_from_directory(HEROES_PATH)

	heroes_loaded_flag = true
	print("[HeroDatabase] Loaded %d heroes" % heroes.size())
	heroes_loaded.emit()


## Recursively load heroes from a directory
func _load_heroes_from_directory(path: String):
	var dir = DirAccess.open(path)
	if dir == null:
		print("[HeroDatabase] Warning: Could not open directory: ", path)
		return

	dir.list_dir_begin()
	var file_name = dir.get_next()

	while file_name != "":
		var full_path = path + file_name

		if dir.current_is_dir():
			# Recursively load from subdirectories
			if file_name != "." and file_name != "..":
				_load_heroes_from_directory(full_path + "/")
		elif file_name.ends_with(".tres") or file_name.ends_with(".res"):
			# Load the resource
			var hero_data = load(full_path) as HeroData
			if hero_data != null:
				print("[HeroDatabase] Loaded hero: %s | Portrait Path: %s" % [hero_data.hero_id, hero_data.portrait.resource_path if hero_data.portrait else "NULL"])
				_register_hero(hero_data)
			else:
				print("[HeroDatabase] Warning: Failed to load hero from: ", full_path)

		file_name = dir.get_next()

	dir.list_dir_end()


## Register a hero in the database
func _register_hero(hero_data: HeroData):
	if hero_data.hero_id == "":
		print("[HeroDatabase] Error: Hero has empty hero_id: ", hero_data.hero_name)
		return

	if heroes.has(hero_data.hero_id):
		print("[HeroDatabase] Warning: Duplicate hero_id: ", hero_data.hero_id)
		return

	heroes[hero_data.hero_id] = hero_data
	heroes_by_class[hero_data.hero_class].append(hero_data)


## Get a hero by their ID
func get_hero(hero_id: String) -> HeroData:
	if heroes.has(hero_id):
		return heroes[hero_id]

	print("[HeroDatabase] Warning: Hero not found: ", hero_id)
	return null


## Get all heroes
func get_all_heroes() -> Array[HeroData]:
	var result: Array[HeroData] = []
	for hero in heroes.values():
		result.append(hero)
	return result


## Get all heroes of a specific class
func get_heroes_by_class(hero_class: HeroData.HeroClass) -> Array[HeroData]:
	if heroes_by_class.has(hero_class):
		return heroes_by_class[hero_class]
	var empty: Array[HeroData] = []
	return empty


## Get all unlocked heroes (either free or purchased)
func get_unlocked_heroes() -> Array[HeroData]:
	var result: Array[HeroData] = []

	for hero in heroes.values():
		if is_hero_unlocked(hero.hero_id):
			result.append(hero)

	return result


## Check if a hero is unlocked
func is_hero_unlocked(hero_id: String) -> bool:
	var hero = get_hero(hero_id)
	if not hero:
		return false

	# Free heroes (unlock_cost == 0) are always unlocked
	if hero.is_free_hero():
		return true

	# Check if player has purchased this hero
	if SaveManager.has_current_profile():
		var unlocked_heroes = SaveManager.current_profile.get("unlocked_heroes", [])
		return unlocked_heroes.has(hero_id)

	return false


## Unlock a hero (purchase with currency)
func unlock_hero(hero_id: String) -> bool:
	var hero = get_hero(hero_id)
	if not hero:
		print("[HeroDatabase] Error: Hero not found: ", hero_id)
		return false

	# Already unlocked
	if is_hero_unlocked(hero_id):
		print("[HeroDatabase] Hero already unlocked: ", hero_id)
		return false

	# Check if player can afford
	var cost = hero.unlock_cost
	if SaveManager.get_gems() < cost:
		print("[HeroDatabase] Not enough gems to unlock hero. Need: ", cost)
		return false

	# Deduct gems and unlock
	SaveManager.add_gems(-cost)
	SaveManager.unlock_hero(hero_id)

	print("[HeroDatabase] ✅ Unlocked hero: ", hero.hero_name, " for ", cost, " gems")
	return true


## Get all locked heroes (not yet purchased)
func get_locked_heroes() -> Array[HeroData]:
	var result: Array[HeroData] = []

	for hero in heroes.values():
		if not is_hero_unlocked(hero.hero_id):
			result.append(hero)

	return result


## Check if a hero exists
func has_hero(hero_id: String) -> bool:
	return heroes.has(hero_id)


## Get all hero IDs
func get_all_hero_ids() -> Array:
	return heroes.keys()


## Reload all heroes (useful for development/hot-reload)
func reload_heroes():
	load_all_heroes()
