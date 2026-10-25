extends RefCounted
## Pure story, partner and marriage normalization shared by old and current saves.
static func normalize(saved_stories: Variant, saved_partners: Variant, saved_marriage: Variant, current_day: int, npc_catalog: Array, content: Dictionary) -> Dictionary:
	var npc_stories: Dictionary = {}
	var partners: Dictionary = {}
	var marriage: Dictionary = {}
	var arcs: Dictionary = content.get("arcs", {})
	var saved_story_map: Dictionary = saved_stories if saved_stories is Dictionary else {}
	var normalized_stories: Dictionary = {}
	for person in npc_catalog:
		var npc_id := str(person.get("id", ""))
		var arc: Array = arcs.get(npc_id, [])
		var row: Variant = saved_story_map.get(npc_id, {})
		var state: Dictionary = row if row is Dictionary else {}
		var step := int(state.get("step", 0))
		var choices_value: Variant = state.get("choices", [])
		var choices: Array = choices_value if choices_value is Array else []
		var last_day := int(state.get("lastDay", -1))
		var valid := step >= 0 and step <= arc.size() and choices.size() == step and last_day >= -1 and last_day <= current_day
		for choice in choices:
			var numeric_choice := int(choice) if choice is int or choice is float else -1
			var whole_choice := choice is int or choice is float and is_equal_approx(float(choice), roundf(float(choice)))
			if not whole_choice or numeric_choice not in [0, 1]:
				valid = false
				break
		if not valid:
			step = 0
			choices = []
			last_day = -1
		var clean_choices: Array[int] = []
		for choice in choices:
			clean_choices.append(int(choice))
		normalized_stories[npc_id] = {"step": step, "choices": clean_choices, "lastDay": last_day}
	npc_stories = normalized_stories
	var saved_partner_map: Dictionary = saved_partners if saved_partners is Dictionary else {}
	partners = {}
	for npc_id in saved_partner_map:
		var person: Dictionary = {}
		for candidate in npc_catalog:
			if str(candidate.get("id", "")) == str(npc_id):
				person = candidate
				break
		if str(person.get("tier", "")) == "romance" and int(person.get("age", 0)) >= 18 and str(saved_partner_map[npc_id]) in ["friend", "dating"]:
			partners[str(npc_id)] = str(saved_partner_map[npc_id])
	var marriage_data: Dictionary = saved_marriage if saved_marriage is Dictionary else {}
	var spouse_value: Variant = marriage_data.get("spouse", "")
	var spouse := str(spouse_value) if spouse_value is String else ""
	if spouse != "" and (not partners.has(spouse) or str(partners[spouse]) != "dating" or int(npc_stories.get(spouse, {}).get("step", 0)) < 4):
		spouse = ""
	var weekly_data: Variant = marriage_data.get("weekly", {})
	var weekly: Dictionary = weekly_data.duplicate(true) if weekly_data is Dictionary else {}
	var saved_memories: Variant = marriage_data.get("memories", [])
	var memories: Array[Dictionary] = []
	if saved_memories is Array:
		for row in saved_memories:
			if row is Dictionary and int(row.get("day", -1)) >= 0 and int(row.get("day", -1)) <= current_day and str(row.get("activity", "")) in ["meal", "visit", "objects", "plan"]:
				memories.append({"day": int(row.day), "activity": str(row.activity)})
	marriage = {"spouse": spouse, "day": clampi(int(marriage_data.get("day", -1)), -1, current_day), "weekly": weekly, "memories": memories.slice(maxi(0, memories.size() - 80))}
	return {"stories":npc_stories,"partners":partners,"marriage":marriage}
