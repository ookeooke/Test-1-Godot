extends Node

func _ready():
	print("=== Starting HeroMetaManager Verification ===")
	
	# 1. Test Attribute Spending
	print("\n--- Testing Attribute Spending ---")
	var hero_id = "test_hero"
	
	# Setup test data
	if not SaveManager.current_profile.has("hero_meta_progression"):
		SaveManager.current_profile["hero_meta_progression"] = {}
	
	SaveManager.current_profile["hero_meta_progression"][hero_id] = {
		"meta_level": 5, # Should have 10 + 4 = 14 points
		"meta_xp": 0,
		"attributes": {
			"might": 0,
			"agility": 0,
			"vitality": 0,
			"wisdom": 0
		},
		"branch_choice": ""
	}
	
	var initial_unspent = HeroMetaManager.get_unspent_attribute_points(hero_id)
	print("Initial unspent points: ", initial_unspent)
	
	if HeroMetaManager.spend_attribute_point(hero_id, "might"):
		print("✅ Spent point on Might")
	else:
		print("❌ Failed to spend point")
		
	var new_unspent = HeroMetaManager.get_unspent_attribute_points(hero_id)
	print("New unspent points: ", new_unspent)
	
	if new_unspent == initial_unspent - 1:
		print("✅ Points deducted correctly")
	else:
		print("❌ Points NOT deducted correctly")
		
	# 2. Test Respec (Free)
	print("\n--- Testing Respec (Free) ---")
	var gems_before = SaveManager.get_gems()
	if HeroMetaManager.respec_attributes(hero_id):
		print("✅ Respec successful")
		var might = HeroMetaManager.get_hero_attributes(hero_id)["might"]
		if might == 0:
			print("✅ Might reset to 0")
		else:
			print("❌ Might NOT reset")
			
		if SaveManager.get_gems() == gems_before:
			print("✅ Gems not deducted (Free respec)")
		else:
			print("❌ Gems deducted unexpectedly")
			
	# 3. Test Milestones
	print("\n--- Testing Milestones ---")
	# Add 10 might
	SaveManager.current_profile["hero_meta_progression"][hero_id]["attributes"]["might"] = 10
	var milestones = HeroMetaManager.get_active_milestones(hero_id)
	print("Active milestones: ", milestones)
	
	var found_might_10 = false
	for m in milestones:
		if m.id == "might_10":
			found_might_10 = true
			break
			
	if found_might_10:
		print("✅ Might 10 milestone active")
	else:
		print("❌ Might 10 milestone MISSING")
			
	# 4. Test Skill Unlock
	print("\n--- Testing Skill Unlock ---")
	var skill = HeroSkillData.new()
	skill.skill_id = "test_skill"
	skill.unlock_cost = 100
	skill.required_hero_level = 1
	
	if HeroMetaManager.unlock_hero_skill(hero_id, skill):
		print("✅ Skill unlocked")
		if SaveManager.has_hero_skill(hero_id, "test_skill"):
			print("✅ Skill found in SaveManager")
		else:
			print("❌ Skill NOT found in SaveManager")
	else:
		print("❌ Failed to unlock skill")
		
	print("\n=== Verification Complete ===")
	get_tree().quit()
