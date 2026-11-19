extends RefCounted
## Compatibility adapter: old commands retain changed, focused views receive domains.
var fingerprints: Dictionary = {}
var plot_fingerprints:Array[int]=[]
var facility_fingerprint:=-1
func _farm_changes(state:Node)->void:
	var dirty:Dictionary={};var next:Array[int]=[]
	var facilities:=hash(state.farm.get("facilities",[]))
	var layout:Script=preload("res://scripts/farm_layout.gd")
	for i in state.plots.size():
		var value:=hash(state.plots[i]);next.append(value)
		if i<plot_fingerprints.size() and plot_fingerprints[i]==value and facilities==facility_fingerprint:continue
		var first:int=layout.first(i);var columns:int=layout.columns(i)
		for neighbor:int in [i-1,i,i+1]:
			if neighbor<0 or neighbor>=state.plots.size() or layout.first(neighbor)!=first:continue
			if (neighbor-first)/columns==(i-first)/columns:dirty[neighbor]=true
	plot_fingerprints=next;facility_fingerprint=facilities
	state.set_meta("farm_dirty_indices",dirty.keys())
func publish(state: Node) -> void:
	var domains := {
		"household":hash(state.interior_state),
		"village":hash(state.village_progress),
		"progress":hash([state.flags,state.community_projects,state.season_events,state.legacy_chapters,state.player_stats]),
		"player":hash([state.stamina,state.selected_tool,state.selected_seed,state.riding,state.player_name]),
		"inventory": hash([state.inventory,state.storage,state.quality,state.storage_quality]),
		"farm": hash([state.plots,state.farm]),
		"decor":hash(state.legacy_systems.get("layouts",[])),
		"forage":hash([state.forage,state.gathered]),
		"fishing":hash(state.fishing),
		"ranch": hash([state.animals,state.ranch]),
		"economy": hash([state.economy,state.money,state.kitchen]),
		"relations": hash([state.relations,state.neighbors,state.npc_stories,state.marriage]),
		"settings": hash([state.player_settings,state.appearance,state.visual_fx,state.ui_art]),
		"world": hash([state.day,state.building,state.upgrades,state.collection,state.current_interior])
	}
	var world_dirty := false
	for domain: String in domains:
		if fingerprints.get(domain) == domains[domain]: continue
		fingerprints[domain] = domains[domain]
		if domain=="farm":_farm_changes(state)
		state.domain_changed.emit(domain)
		var revisions:Dictionary=state.get_meta("domain_revisions",{})
		revisions[domain]=int(revisions.get(domain,0))+1;state.set_meta("domain_revisions",revisions)
		state.domain_changed.emit(domain)
		if domain in ["world","decor","forage"]:world_dirty = true
	if world_dirty: state.world_changed.emit()
