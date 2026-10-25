extends RefCounted
## Quality stays a pure calculation; care and inventory remain transactional commands.
static func quality(animal: Dictionary, barn: Dictionary, breeds: Dictionary) -> int:
	var breed: Dictionary = breeds.get(str(animal.get("breed", "local")), breeds.get("local", {}))
	var score := float(animal.health) * 0.26 + float(animal.hunger) * 0.2 + float(animal.mood) * 0.2 + float(animal.clean) * 0.14 + float(animal.bond) * 0.1 + float(barn.get("clean", 90)) * 0.1 + float(animal.feedQuality) + float(barn.get("comfort", 0)) * 2.0 - float(animal.illness) * 0.2 - float(animal.stress) * 0.1
	return mini(int(breed.get("cap", 2)), 3 if score >= 92.0 else 2 if score >= 77.0 else 1 if score >= 55.0 else 0)
