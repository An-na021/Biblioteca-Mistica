extends RefCounted
## Client-owned volumes never enter or consume the shop's inventory.
const Diagnosis = preload("res://scripts/restoration_diagnosis.gd")
const ACTIVE := ["offered", "accepted", "ready", "scheduled"]
var entries: Array[Dictionary] = []
var last_offer_day := -1

func get_job(id: String) -> Dictionary:
	for job in entries:
		if str(job.id) == id:
			return job.duplicate(true)
	return {}

func pending() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for job in entries:
		if str(job.status) in ACTIVE:
			result.append(job.duplicate(true))
	return result

func offer(profile: Dictionary, book: Dictionary, day: int, cost: int, condition: String) -> Dictionary:
	if day < 2 or last_offer_day == day or pending().size() >= 3 or cost < 0 or str(profile.get("id", "")).is_empty() or book.is_empty() or condition not in ["usado", "novo", "raro"]:
		return {}
	for job in pending():
		if str(job.customer_id) == str(profile.id):
			return {}
	var job := {"id": "%d_%s" % [day, str(profile.id)], "customer_id": str(profile.id), "customer_name": str(profile.get("name", "Leitor")), "book_id": str(book.id),
		"condition": condition, "cost": cost, "reward": cost + 6 + (4 if condition == "raro" else 2 if condition == "novo" else 0),
		"reputation": 2 if condition == "raro" else 1, "created_day": day, "due_day": day + 3,
		"diagnosis": str(Diagnosis.for_book(str(book.id), day).id), "status": "offered"}
	entries.append(job)
	last_offer_day = day
	# Keep recent history, preserving all live requests.
	while entries.size() > 16:
		var removed := false
		for index in range(entries.size()):
			if str(entries[index].status) not in ACTIVE:
				entries.remove_at(index)
				removed = true
				break
		if not removed:
			break
	return job.duplicate(true)

func expire(day: int) -> int:
	var count := 0
	for job in entries:
		if str(job.status) in ACTIVE and day > int(job.due_day):
			job.status = "expired"
			count += 1
	return count

func accept(id: String, day: int) -> bool:
	var active := 0
	for job in entries:
		if str(job.status) in ["accepted", "ready", "scheduled"]:
			active += 1
	if active >= 2:
		return false
	return _transition(id, "offered", "accepted", day)

func decline(id: String, day: int) -> bool:
	return _transition(id, "offered", "declined", day)

func can_work(id: String, day: int) -> bool:
	var job := get_job(id)
	return not job.is_empty() and str(job.status) == "accepted" and day >= int(job.created_day) and day <= int(job.due_day) and not BookCatalog.get_book(str(job.book_id)).is_empty()

func finish(id: String, day: int, funds: int, quote: int) -> int:
	var job := get_job(id)
	if not can_work(id, day) or quote != int(job.cost) or funds < int(job.cost):
		return -1
	return int(job.cost) if _transition(id, "accepted", "ready", day) else -1

func schedule_pickup(id: String, day: int, pickup_day: int) -> bool:
	var job := get_job(id)
	if job.is_empty() or str(job.status) not in ["ready", "scheduled"] or day < int(job.created_day) or pickup_day < day or pickup_day > int(job.due_day):
		return false
	for entry in entries:
		if str(entry.id) == id:
			entry.status = "scheduled"
			entry["pickup_day"] = pickup_day
			entry["pickup_visit_day"] = -1
			return true
	return false

func pickups_for_day(day: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for job in entries:
		if str(job.status) == "scheduled" and int(job.get("pickup_day", day + 1)) <= day and day <= int(job.due_day) and int(job.get("pickup_visit_day", -1)) != day:
			result.append(job.duplicate(true))
	return result

func pickup_for_customer(customer_id: String, day: int) -> Dictionary:
	for job in entries:
		if str(job.status) == "scheduled" and str(job.customer_id) == customer_id and int(job.get("pickup_day", day + 1)) <= day and day <= int(job.due_day):
			return job.duplicate(true)
	return {}

func mark_pickup_visit(id: String, day: int) -> void:
	for job in entries:
		if str(job.id) == id and str(job.status) == "scheduled":
			job["pickup_visit_day"] = day

func collect(id: String, day: int, present_customer_id := "") -> Dictionary:
	var job := get_job(id)
	if job.is_empty() or present_customer_id.is_empty() or str(job.customer_id) != present_customer_id or int(job.get("pickup_day", day + 1)) > day or not _transition(id, "scheduled", "delivered", day):
		return {}
	return {"money": int(job.reward), "reputation": int(job.reputation), "customer_name": str(job.customer_name), "book_id": str(job.book_id)}

func _transition(id: String, before: String, after: String, day: int) -> bool:
	for job in entries:
		if str(job.id) == id and str(job.status) == before and day >= int(job.created_day) and day <= int(job.due_day):
			job.status = after
			return true
	return false

func serialize() -> Dictionary:
	return {"entries": entries.duplicate(true), "last_offer_day": last_offer_day}

func restore(data: Dictionary) -> void:
	entries.clear()
	var last: Variant = data.get("last_offer_day", -1)
	last_offer_day = int(last) if (last is int or last is float) and is_finite(float(last)) else -1
	var saved: Variant = data.get("entries", [])
	if not saved is Array:
		return
	var ids := {}
	for entry in saved:
		if not entry is Dictionary or not entry.has_all(["id", "customer_id", "customer_name", "book_id", "condition", "cost", "reward", "reputation", "created_day", "due_day", "status"]):
			continue
		var valid := true
		for field in ["id", "customer_id", "customer_name", "book_id", "condition", "status"]:
			if not entry[field] is String or str(entry[field]).is_empty():
				valid = false
		for field in ["cost", "reward", "reputation", "created_day", "due_day"]:
			var value: Variant = entry[field]
			if not (value is int or value is float) or not is_finite(float(value)):
				valid = false
		if not valid:
			continue
		if ids.has(str(entry.id)) or str(entry.condition) not in ["usado", "novo", "raro"] or str(entry.status) not in ACTIVE + ["delivered", "expired", "declined"] or int(entry.cost) < 0 or int(entry.reward) < 0 or int(entry.reputation) < 0 or int(entry.created_day) < 1 or int(entry.due_day) < int(entry.created_day):
			continue
		var job: Dictionary = entry.duplicate(true)
		if str(job.status) == "scheduled":
			var pickup: Variant = job.get("pickup_day")
			var visit: Variant = job.get("pickup_visit_day", -1)
			if not (pickup is int or pickup is float) or not is_finite(float(pickup)) or int(pickup) < int(job.created_day) or int(pickup) > int(job.due_day):
				continue
			job["pickup_day"] = int(pickup)
			job["pickup_visit_day"] = int(visit) if (visit is int or visit is float) and is_finite(float(visit)) else -1
		job["diagnosis"] = str(Diagnosis.profile(str(job.get("diagnosis", "complete"))).id)
		entries.append(job)
		ids[str(job.id)] = true
