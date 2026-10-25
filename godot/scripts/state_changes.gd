extends RefCounted
## Compatibility adapter: old commands retain changed, focused views receive domains.
var fingerprints: Dictionary = {}
func publish(state: Node) -> void:
	var domains := {
		"inventory": hash([state.inventory,state.storage,state.quality,state.storage_quality]),
		"farm": hash([state.plots,state.farm]),
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
		state.domain_changed.emit(domain)
		world_dirty = true
	if world_dirty: state.world_changed.emit()
