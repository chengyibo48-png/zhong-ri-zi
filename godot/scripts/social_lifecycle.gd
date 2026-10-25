extends RefCounted
## Optional neighbor invitations retain the original repeat and completion rules.
static func ensure_events(neighbors: Dictionary, npc_catalog: Array, day: int) -> void:
	if int(neighbors.get("day", -1)) == day:
		return
	neighbors.day = day
	if day < 2 or npc_catalog.is_empty():
		return
	for offset in range(2):
		var person_index := posmod((day - 2) * 2 + offset, npc_catalog.size())
		var npc_id := str(npc_catalog[person_index].get("id", ""))
		var resident: Dictionary = neighbors.people.get(npc_id, {})
		var event: Dictionary = resident.get("event", {})
		if event.is_empty() or str(event.get("status", "")) == "done" and day - int(event.get("completed", day)) >= 28:
			resident.event = {"day": day, "status": "offered", "method": null, "completed": null}
			neighbors.people[npc_id] = resident
