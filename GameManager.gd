extends Node

signal collectable_added(item_name: String)

const SAVE_PATH = "user://data.save"

var unlocked_levels = {
	1: true, 2: false, 3: false, 4: false, 5: false,
	6: false, 7: false, 8: false, 9: false, 10: false,
	11: false, 12: false, 13: false, 14: false, 15: false,
	16: false, 17: false, 18: false, 19: false, 20: false,
	21: false, 22: false, 23: false, 24: false, 25: false,
	26: false, 27: false, 28: false,
}

var collected_items = []

# Default settings values (0.0 to 1.0 for volume & intensity, 0 to 2 for mode)
var settings_data = {
	"colorblind_mode": 0,
	"colorblind_intensity": 1.0,
	"volume_master": 1.0,
	"volume_SFX": 1.0,
	"volume_Enviroment": 1.0,
	"volume_Player": 1.0,
	"volume_Music": 1.0
}

func _ready() -> void:
	load_game()

func save_game() -> void:
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		print("Failed to save game. Error code: ", FileAccess.get_open_error())
		return

	var data = {
		"unlocked_levels": unlocked_levels,
		"collected_items": collected_items,
		"settings": settings_data
	}
	
	file.store_line(JSON.stringify(data))
	file.close()
	print("Game saved successfully.")

func load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		apply_all_audio_busses()
		return

	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		print("Failed to load game. Error code: ", FileAccess.get_open_error())
		return

	var json_string = file.get_line()
	file.close()

	var json = JSON.new()
	var error = json.parse(json_string)
	if error == OK:
		var data = json.data
		if data.has("unlocked_levels"):
			for key in data["unlocked_levels"].keys():
				unlocked_levels[int(key)] = data["unlocked_levels"][key]
		if data.has("collected_items"):
			collected_items = data["collected_items"]
		if data.has("settings"):
			# Merge saved settings with defaults in case new settings were added later
			for key in data["settings"].keys():
				settings_data[key] = data["settings"][key]
		
		apply_all_audio_busses()
		print("Game loaded successfully.")

func apply_all_audio_busses() -> void:
	_apply_bus_volume("master", settings_data["volume_master"])
	_apply_bus_volume("SFX", settings_data["volume_SFX"])
	_apply_bus_volume("Enviroment", settings_data["volume_Enviroment"])
	_apply_bus_volume("Player", settings_data["volume_Player"])
	_apply_bus_volume("Music", settings_data["volume_Music"])

func _apply_bus_volume(bus_name: String, linear_val: float) -> void:
	var idx = AudioServer.get_bus_index(bus_name)
	if idx != -1:
		AudioServer.set_bus_volume_db(idx, linear_to_db(linear_val))
		AudioServer.set_bus_mute(idx, linear_val <= 0.001)

func unlock_level(level_number):
	if unlocked_levels.has(level_number):
		unlocked_levels[level_number] = true
		if unlocked_levels.has(level_number - 1):
			unlocked_levels[level_number - 1] = true
		print("Unlocked level " + str(level_number))
		save_game()

func is_level_unlocked(level_number):
	if unlocked_levels.has(level_number):
		return unlocked_levels[level_number]
	return false

func add_collectable(item_name):
	if not item_name in collected_items:
		collected_items.append(item_name)
		print("Collected: " + item_name)
		collectable_added.emit(item_name)
		save_game()

func has_collectable(item_name: String) -> bool:
	return item_name in collected_items

func has_any_collectable() -> bool:
	return collected_items.size() > 0

func has_level_collectable(level_number: int) -> bool:
	return has_collectable("collectable in level_%d" % level_number)
