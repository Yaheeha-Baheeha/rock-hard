extends Node

var unlocked_levels = {
	1: true,
	2: false,
	3: false,
	4: false,
	5: false,
	6: false
}

var collected_items = []

func unlock_level(level_number):
	if unlocked_levels.has(level_number):
		unlocked_levels[level_number] = true
		print("Unlocked level " + str(level_number))

func is_level_unlocked(level_number):
	if unlocked_levels.has(level_number):
		return unlocked_levels[level_number]
	return false

func add_collectable(item_name):
	if not item_name in collected_items:
		collected_items.append(item_name)
		print("Collected: " + item_name)

