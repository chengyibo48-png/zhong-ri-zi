extends RefCounted
## Normalize only economy-owned fields; preserve existing stock and receipts.
static func normalize(economy: Dictionary, day: int, reset_daily: bool) -> Dictionary:
	var defaults := {"version": 1, "locked": [], "pinned": [], "rep": 0, "nextId": 1, "receipts": [], "jobs": [], "claimed": [], "daily": {"day": day, "bought": {}}, "ledger": []}
	for key in defaults:
		if not economy.has(key):
			var fallback: Variant = defaults[key]
			economy[key] = fallback.duplicate(true) if fallback is Array or fallback is Dictionary else fallback
	if not economy.get("daily", {}) is Dictionary: economy.daily = {"day": day, "bought": {}}
	for key in ["locked", "pinned", "receipts", "jobs", "claimed", "ledger"]:
		if not economy.get(key, []) is Array: economy[key] = []
	var daily: Dictionary = economy.get("daily", {})
	if reset_daily and int(daily.get("day", -1)) != day:
		daily = {"day": day, "bought": {}}
	if not daily.get("bought", {}) is Dictionary:
		daily["bought"] = {}
	economy.daily = daily
	return economy
