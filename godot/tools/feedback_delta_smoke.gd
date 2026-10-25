extends SceneTree
const RULES := preload("res://scripts/feedback_action.gd")
var passed := 0
var failed := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
    if ok: passed += 1
    else: failed += 1; push_error(label)
func same(a: Variant, b: Variant) -> bool:
    if a is Dictionary and b is Dictionary:
        if a.size() != b.size(): return false
        for key in a:
            if not b.has(key) or not same(a[key], b[key]): return false
        return true
    if a is Array and b is Array:
        if a.size() != b.size(): return false
        for i in a.size():
            if not same(a[i], b[i]): return false
        return true
    if (a is float or a is int) and (b is float or b is int): return float(a) == float(b)
    return a == b
func adapt(native: Node, source: Dictionary) -> void:
    native.day = int(source.day); native.minutes = float(source.minutes)
    native.money = int(source.money); native.stamina=float(source.stamina)
    native.inventory = source.bag.duplicate(true); native.storage = source.storage.duplicate(true)
    native.quality = source.quality.duplicate(true); native.storage_quality = source.storageQuality.duplicate(true)
    native.plots.assign(source.farm.beds.duplicate(true))
    native.animals.assign(source.animals.duplicate(true)); native.relations = source.relations.duplicate(true)
    native.fishing = source.fishing.duplicate(true); native.kitchen = source.kitchen.duplicate(true)
    native.economy = source.economy.duplicate(true); native.building = source.building.duplicate(true)
    native.toolkit = source.toolkit.duplicate(true); native.neighbors = source.neighbors.duplicate(true)
func run() -> void:
    await process_frame
    var temp := OS.get_environment("TEMP").replace("\\", "/").trim_suffix("/")
    if temp == "" or not OS.get_user_data_dir().replace("\\", "/").begins_with(temp + "/"): quit(1); return
    var native := root.get_node("GameState"); native.set_process(false)
    var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("FEEDBACK_DELTA_FIXTURE")))
    for row in fixture.rows:
        if row.get("rounding", false):
            check(same(RULES.describe_delta(row.delta, fixture.items, fixture.names), row.description), "JS signed rounding " + str(row.delta.stamina))
            continue
        var before := RULES.snapshot(row.original, row.point)
        var after := RULES.snapshot(row.state, row.point)
        check(same(before, row.before), "targeted before snapshot " + str(row.mask))
        check(same(after, row.after), "targeted after snapshot " + str(row.mask))
        var delta := RULES.difference(before, after)
        check(same(delta, row.delta), "exact source delta " + str(row.mask))
        var description := RULES.describe_delta(delta, fixture.items, fixture.names)
        if not same(description, row.description): print("ACTUAL ", description, " EXPECTED ", row.description)
        check(same(description, row.description), "exact source delta text " + str(row.mask))
        adapt(native, row.state)
        var expected: Dictionary = row.after.duplicate(true)
        check(same(native.feedback_action_snapshot(row.point), expected), "native snapshot adapter " + str(row.mask))
        var saved: Dictionary = after.duplicate(true)
        row.state.fishing.records["mutation"] = {"count": 9}
        check(same(after, saved), "snapshot owns nested mutable state " + str(row.mask))
    for row in fixture.finishes:
        native.day = int(row.state.day); native.minutes = float(row.state.minutes)
        native.feedback = row.state.feedback.duplicate(true)
        var runtime: Dictionary = row.oldRuntime.duplicate(true)
        var result: Variant = RULES.finish(row.before, RULES.snapshot(row.state, row.point), row.point, row.spec, native.feedback, runtime, fixture.catalog, row.state.player, native._feedback_note)
        if not same(result, row.result): print("FINISH ", row.mask, " ACTUAL ", result, " EXPECTED ", row.result)
        check(same(result, row.result), "source finish result " + str(row.mask))
        check(same(native.feedback, row.feedback), "source finish journal and days " + str(row.mask))
        check(same(runtime, row.runtime), "source finish merged floats " + str(row.mask))
    for row in fixture.clocks:
        native.feedback_action_runtime = row.initial.duplicate(true)
        native.current_interior = row.room
        native.tick_feedback_floats(float(row.dt))
        check(same(native.feedback_action_runtime, row.expected), "actual source draw clock and room " + str(row.dt) + "/" + str(row.room))
    # The native story channel is optional and transient; never create it for source floats.
    for start_room in ["", "home-granny"]:
        for end_room in ["", "home-granny"]:
            for step in [-1.0, 0.0, 0.04, 0.1, 10.0]:
                var story: Dictionary = {"x":10.0,"y":20.0,"text":"transient-clock-probe-unique-text","at":4.0,"duration":4.0}
                native.feedback_action_runtime={"clock":4.4,"serial":0,"room":start_room,"floats":[],"stories":[story.duplicate(true)]}
                native.current_interior=end_room
                native.tick_feedback_floats(float(step))
                check(native.feedback_action_runtime.clock==4.4+clampf(float(step),0.0,0.1),"story uses unchanged source draw clock")
                var expected_stories: Array = [] if start_room!=end_room else [story]
                check(same(native.feedback_action_runtime.stories,expected_stories),"story clears only at original room boundary")
                check(not JSON.stringify(native._make_save_data()).contains("transient-clock-probe-unique-text"),"story channel never enters native save")
    for start_at in [-3.95,-3.8]:
        native.current_interior="home-granny"
        native.feedback_action_runtime={"clock":0.0,"serial":0,"room":"home-granny","floats":[],"stories":[{"x":10.0,"y":20.0,"text":"timed-story","at":start_at,"duration":4.0}]}
        native.tick_feedback_floats(0.1)
        check(native.feedback_action_runtime.stories.size()==(0 if start_at==-3.95 else 1),"four-second story expiration boundary")
    print("Feedback delta: %d passed, %d failed" % [passed, failed])
    await root.get_node("AudioService").prepare_exit()
    quit(1 if failed else 0)
