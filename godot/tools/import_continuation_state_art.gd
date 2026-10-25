extends SceneTree

const RECEIPTS_PATH := "res://artifacts/continuation-art-20261013/generation-receipts.json"
const QUEUE_PATH := "res://artifacts/independent-fine-art-20261011/queue.json"
const REMAINING_PATH := "res://artifacts/independent-fine-art-20261011/remaining.json"
const MANIFEST_PATH := "res://data/world_art_manifest.json"
const CANVAS_SIZE := Vector2i(256, 160)

func _initialize() -> void:
	print("CONTINUATION_IMPORT_START")
	var receipts: Variant = _read_json(RECEIPTS_PATH)
	var queue: Variant = _read_json(QUEUE_PATH)
	var manifest: Variant = _read_json(MANIFEST_PATH)
	if not receipts is Array or not queue is Dictionary or not manifest is Dictionary:
		push_error("Continuation state import metadata is invalid.")
		quit(1)
		return
	var imported := 0
	for index in range(receipts.size()):
		var item_value: Variant = receipts[index]
		if not item_value is Dictionary or str(item_value.get("status", "")) != "approved_static_review":
			continue
		var item: Dictionary = item_value
		var id := str(item.get("id", ""))
		var state := str(item.get("state", ""))
		var master := str(item.get("master", ""))
		var image := Image.load_from_file(master)
		if id == "" or state not in ["night", "focused", "working"] or image == null or image.is_empty():
			push_error("Invalid continuation image: " + id + " " + state)
			quit(1)
			return
		image.convert(Image.FORMAT_RGBA8)
		if image.detect_alpha() == Image.ALPHA_NONE:
			push_error("Continuation image is not transparent: " + id + " " + state)
			quit(1)
			return
		var bounds := image.get_used_rect()
		if bounds.size.x <= 0 or bounds.size.y <= 0 or bounds.position.x <= 0 or bounds.position.y <= 0 or bounds.end.x >= image.get_width() or bounds.end.y >= image.get_height():
			push_error("Continuation image has clipped or empty alpha bounds: " + id + " " + state)
			quit(1)
			return
		var crop := image.get_region(bounds)
		var scale := minf(float(CANVAS_SIZE.x - 4) / float(bounds.size.x), float(CANVAS_SIZE.y - 4) / float(bounds.size.y))
		var fitted := Vector2i(maxi(1, roundi(float(bounds.size.x) * scale)), maxi(1, roundi(float(bounds.size.y) * scale)))
		crop.resize(fitted.x, fitted.y, Image.INTERPOLATE_LANCZOS)
		var canvas := Image.create(CANVAS_SIZE.x, CANVAS_SIZE.y, false, Image.FORMAT_RGBA8)
		canvas.blit_rect(crop, Rect2i(Vector2i.ZERO, fitted), Vector2i((CANVAS_SIZE.x - fitted.x) / 2, CANVAS_SIZE.y - fitted.y))
		var path := "res://art/world/interior_props/fine/" + id.get_file() + "-" + state + ".png"
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
		if canvas.save_png(path) != OK:
			push_error("Could not save continuation runtime asset: " + path)
			quit(1)
			return
		var row_value: Variant = manifest.get("entries", {}).get(id, {})
		if not row_value is Dictionary:
			push_error("Missing world art row: " + id)
			quit(1)
			return
		var row: Dictionary = row_value
		var states: Dictionary = row.get("states", {})
		states[state] = path
		row["states"] = states
		var pending: Array = row.get("pendingPaintedStates", [])
		pending.erase(state)
		row["pendingPaintedStates"] = pending
		row["plannedPaintedStatesImported"] = pending.is_empty()
		row["status"] = "partial"
		row["artBatch"] = "continuation-art-20261013"
		row["artReview"] = "Source image statically reviewed; runtime placement and interaction alignment remain pending."
		row["verification"] = "Native runtime PNG imported; gameplay not tested in this batch."
		manifest["entries"][id] = row
		item["runtimePath"] = path
		item["runtimeSha256"] = _sha256(ProjectSettings.globalize_path(path))
		item["sourceDimensions"] = [image.get_width(), image.get_height()]
		item["status"] = "imported_static_review_only"
		receipts[index] = item
		for job_value in queue.get("jobs", []):
			if not job_value is Dictionary:
				continue
			var job: Dictionary = job_value
			if str(job.get("id", "")) == id and str(job.get("state", "")) == state:
				job["master"] = master
				job["sha256"] = str(item.get("generatedSha256", ""))
				job["runtimePath"] = path
				job["status"] = "imported_not_gameplay_tested"
				job["verification"] = "Source image statically reviewed and native runtime PNG imported; gameplay not tested."
		imported += 1
	var counts: Dictionary = queue.get("counts", {})
	counts["total"] = queue.get("jobs", []).size()
	counts["imported"] = 0
	counts["pending"] = 0
	var remaining_jobs: Array = []
	for job_value in queue.get("jobs", []):
		if not job_value is Dictionary:
			continue
		var job: Dictionary = job_value
		if str(job.get("status", "")) == "imported_not_gameplay_tested":
			counts["imported"] = int(counts.imported) + 1
		else:
			counts["pending"] = int(counts.pending) + 1
			remaining_jobs.append({
				"id": str(job.get("id", "")),
				"name": str(job.get("name", "")),
				"state": str(job.get("state", "")),
				"reason": str(job.get("reason", "Pending static review or generation"))
			})
	queue["counts"] = counts
	var remaining := {
		"updated": "2026-10-13",
		"pendingImages": int(counts.pending),
		"jobs": remaining_jobs
	}
	if not _write_json(MANIFEST_PATH, manifest) or not _write_json(QUEUE_PATH, queue) or not _write_json(REMAINING_PATH, remaining) or not _write_json(RECEIPTS_PATH, receipts):
		push_error("Could not save continuation import metadata.")
		quit(1)
		return
	print("CONTINUATION_STATE_IMPORT: ", imported, " statically reviewed state images imported; ", counts.pending, " remain.")
	quit(0)

func _read_json(path: String) -> Variant:
	return JSON.parse_string(FileAccess.get_file_as_string(path))

func _write_json(path: String, value: Variant) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(value, "  ") + "\n")
	file.close()
	return true

func _sha256(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(file.get_buffer(file.get_length()))
	return context.finish().hex_encode()

