extends RefCounted

const SAVE_PATH := "user://biblioteca_save.json"
const PROGRESSION_FIELDS := [
	"daily_sales", "daily_errors", "daily_profit", "weekly_sales", "weekly_profit",
	"weekly_errors", "current_week", "sales_without_error", "total_purchases",
	"suppliers_used", "districts_visited", "unlocked_achievements", "weekly_reward_claimed",
	"daily_customer_target"
]

static func read_save(path: String = SAVE_PATH) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		return {}
	var parsed: Variant = json.data
	if not parsed is Dictionary:
		return {}
	if parsed.get("version") != 1 or not parsed.get("inventory") is Dictionary or not parsed.get("progression") is Dictionary:
		return {}
	if not parsed.get("day") is float and not parsed.get("day") is int:
		return {}
	if int(parsed.day) < 1 or not parsed.get("money") is float and not parsed.get("money") is int:
		return {}
	for field in ["acquisition_costs", "summary", "markets", "stats", "catalog"]:
		if not parsed.get(field, {}) is Dictionary:
			return {}
	# Older checkpoints have no town state; upgrades and memories start empty.
	if not parsed.get("world", {}) is Dictionary:
		return {}
	var world: Dictionary = parsed.get("world", {})
	if not world.get("upgrades", {}) is Dictionary or not world.get("memories", {}) is Dictionary:
		return {}
	if not parsed.get("active_day", {}) is Dictionary:
		return {}
	var active_day: Dictionary = parsed.get("active_day", {})
	if not active_day.is_empty():
		if not active_day.get("customer") is Dictionary or not active_day.get("seen") is Array:
			return {}
		var active_customer: Dictionary = active_day.customer
		if not active_customer.get("id") is String or not active_customer.get("requested_book") is String:
			return {}
		for field in ["clue", "memory", "offer_decisions"]:
			if not active_customer.get(field, {}) is Dictionary:
				return {}
		if not active_customer.get("acceptable_books", []) is Array:
			return {}
	for quantities in parsed.inventory.values():
		if not quantities is Dictionary:
			return {}
		for quantity in quantities.values():
			if not quantity is float and not quantity is int:
				return {}
			if int(quantity) < 0:
				return {}
	for field in PROGRESSION_FIELDS:
		if not parsed.progression.has(field):
			return {}
		var value: Variant = parsed.progression[field]
		if field in ["suppliers_used", "districts_visited", "unlocked_achievements"]:
			if not value is Dictionary:
				return {}
		elif field == "weekly_reward_claimed":
			if not value is bool:
				return {}
		elif not value is float and not value is int:
			return {}
	return parsed

static func write_save(data: Dictionary, path: String = SAVE_PATH) -> Error:
	# Replace only after the complete new checkpoint has reached disk.
	var temporary := path + ".tmp"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(data))
	file.flush()
	var error := file.get_error()
	file.close()
	if error != OK:
		return error
	return DirAccess.rename_absolute(ProjectSettings.globalize_path(temporary), ProjectSettings.globalize_path(path))
