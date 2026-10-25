extends RefCounted

## Targeted action snapshots. State input uses the source save schema so that
## game state adaptation and settlement rules can be checked independently.
const GRADES := ["普通", "优质", "上品", "珍品"]

static func snapshot(state: Dictionary, point: Dictionary = {}) -> Dictionary:
    var items: Dictionary = {}
    var ids: Dictionary = {}
    for id in state.bag: ids[id] = true
    for id in state.get("storage", {}): ids[id] = true
    for id in ids:
        var counts: Array = [0, 0, 0, 0]
        for side in ["bag", "storage"]:
            var ledger: Array = state.get("quality" if side == "bag" else "storageQuality", {}).get(id, [0, 0, 0])
            var total := 0
            for grade in range(1, 4):
                var quantity: int = int(ledger[grade - 1]) if ledger.size() >= grade else 0
                counts[grade] += quantity
                total += quantity
            counts[0] += maxi(0, int(state.get(side, {}).get(id, 0)) - total)
        items[id] = counts
    var fields: Dictionary = {}
    var index: Variant = point.get("index", null)
    var beds: Array = state.get("farm", {}).get("beds", [])
    if (index is int or index is float and float(index) == floorf(float(index))) and int(index) >= 0 and int(index) < beds.size():
        var bed: Dictionary = beds[int(index)]
        fields["水分"] = floori(float(bed.moisture) + 0.5)
        fields["肥力"] = floori(float(bed.fertility) + 0.5)
        fields["健康"] = floori(float(bed.health) + 0.5)
    var animal_id: Variant = point.get("animalId", null)
    if animal_id == null or animal_id == "":
        animal_id = point.get("id", null) if point.get("kind", "") == "animal" else null
    for animal in state.animals:
        if animal.id == animal_id:
            fields["饱食"] = floori(float(animal.hunger) + 0.5)
            fields["心情"] = floori(float(animal.mood) + 0.5)
            fields["清洁"] = floori(float(animal.clean) + 0.5)
            break
    var relations: Dictionary = {}
    for id in state.relations: relations[id] = state.relations[id].points
    var casts := 0
    for water in state.fishing.waters.values():
        if water.day == state.day: casts += int(water.casts)
    var tools: Dictionary = {}
    for id in state.toolkit.tools: tools[id] = state.toolkit.tools[id].level
    var neighbors: Dictionary = {}
    for id in state.neighbors.people:
        var event: Variant = state.neighbors.people[id].get("event", null)
        # Native residents normalize absent events to {}, while JS uses null.
        neighbors[id] = event.duplicate(true) if event is Dictionary and not event.is_empty() else null
    var last_fish: Variant = state.fishing.get("last", null)
    return {
        "day": state.day, "minute": state.minutes, "money": state.money,
        "stamina": state.stamina, "items": items, "relations": relations,
        "fields": fields, "world": {
            "fish": state.fishing.records.duplicate(true), "fishCasts": casts,
            "lastFish": last_fish.duplicate(true) if last_fish is Dictionary and not last_fish.is_empty() else null,
            "kitchen": state.kitchen.jobs.duplicate(true),
            "trade": state.economy.jobs.duplicate(true),
            "orders": state.economy.claimed.duplicate(true),
            "building": state.building.jobs.duplicate(true), "tools": tools,
            "neighbors": neighbors
        }
    }

static func difference(before: Dictionary, after: Dictionary) -> Dictionary:
    var items: Array = []
    var ids: Dictionary = {}
    for id in before.items: ids[id] = true
    for id in after.items: ids[id] = true
    for id in ids:
        for grade in range(4):
            var amount: int = int(after.items.get(id, [0,0,0,0])[grade]) - int(before.items.get(id, [0,0,0,0])[grade])
            if amount != 0: items.append({"id": id, "grade": grade, "qty": amount})
    var relations: Array = []
    for id in after.relations:
        var amount: Variant = after.relations[id] - before.relations.get(id, 0)
        if amount != 0: relations.append({"id": id, "amount": amount})
    var fields: Array = []
    for name in after.fields:
        if after.fields[name] != before.fields.get(name):
            fields.append({"name": name, "from": before.fields.get(name), "to": after.fields[name]})
    return {"items": items, "relations": relations, "fields": fields,
        "money": after.money - before.money, "stamina": after.stamina - before.stamina}

static func number_text(value: Variant) -> String:
    return preload("res://scripts/js_number.gd").text(value)

static func signed(value: Variant) -> String:
    return ("+" if value > 0 else "") + number_text(value)

static func describe_delta(delta: Dictionary, item_catalog: Dictionary, npc_names: Dictionary) -> Array[String]:
    var result: Array[String] = []
    for item in delta.items:
        result.append(signed(item.qty) + " " + GRADES[int(item.grade)] + str(item_catalog[item.id].name))
    if delta.money != 0: result.append(signed(delta.money) + " 元")
    for relation in delta.relations:
        result.append(str(npc_names[relation.id]) + "关系 " + signed(relation.amount))
    for field in delta.fields:
        result.append(str(field.name) + " " + ("undefined" if field.from == null else number_text(field.from)) + " → " + number_text(field.to))
    if delta.stamina != 0:
        result.append("体力 " + signed(float(floori(float(delta.stamina) * 10.0 + 0.5)) / 10.0))
    return result


static func stage(points: float) -> String:
    return "初识" if points < 10 else "熟悉" if points < 30 else "亲近" if points < 70 else "信任"

static func world_changes(before: Dictionary, after: Dictionary, catalog: Dictionary) -> Array[Dictionary]:
    var out: Array[Dictionary] = []
    var a: Dictionary = before.world
    var b: Dictionary = after.world
    for id in b.fish:
        var record: Dictionary = b.fish[id]
        if record.count > a.fish.get(id, {}).get("count", 0):
            var fresh: bool = not a.fish.has(id)
            var best: bool = not fresh and record.best > a.fish[id].best
            var last: Dictionary = b.lastFish
            var prefix := "图鉴新发现 · " if fresh else "体长新纪录 · " if best else "鱼获记录 · "
            out.append({"text": prefix + str(catalog.fishing.species[id].name) + " " + number_text(last.length) + " 厘米 · " + GRADES[int(last.grade)] + (" · 已轻放回水中" if last.released else " · 已收进鱼篓"), "link": "fishing", "priority": 1 if fresh or best else 0, "type": "提醒"})
    if b.lastFish is Dictionary and b.lastFish.get("fish", "") == null and b.fishCasts > a.fishCasts:
        out.append({"text": "这竿没有鱼获：" + str(b.lastFish.reason) + "；可以改用轻松观漂模式", "link": "fishing", "priority": 1, "type": "未完成"})
    for id in after.relations:
        var prior := stage(float(before.relations.get(id, 0)))
        var current := stage(float(after.relations[id]))
        if prior != current: out.append({"text": str(catalog.npc_names[id]) + "：" + prior + " → " + current, "link": "neighbors", "priority": 1, "type": "社交"})
    for job in b.kitchen:
        if not a.kitchen.any(func(old: Dictionary) -> bool: return old.key == job.key):
            out.append({"text": str(catalog.kitchen.stations[job.station].name) + "已开始加工 " + str(catalog.items[job.id].name) + " ×" + number_text(job.qty) + "；约 " + str(ceili(float(job.ready) - (float(after.day) * 1440 + float(after.minute)))) + " 游戏分钟后手动收取", "link": "processing", "priority": 0, "type": "提醒"})
    for job in b.trade:
        if not a.trade.any(func(old: Dictionary) -> bool: return old.key == job.key):
            out.append({"text": ("合作社代销" if job.channel == "coop" else "乡间摆摊") + "已接收 " + str(catalog.items[job.id].name) + " ×" + number_text(job.qty) + "；待结算 " + number_text(job.price) + " 元（尚未到账）", "link": "economy", "priority": 0, "type": "提醒"})
    for id in b.orders:
        if not a.orders.has(id): out.append({"text": "供货单 " + str(id) + " 已交付，货款已计入本次收支", "link": "economy", "priority": 1, "type": "提醒"})
    for job in b.building:
        if not a.building.any(func(old: Dictionary) -> bool: return old.id == job.id and old.level == job.level):
            out.append({"text": str(catalog.building.projects[job.id].name) + "第 " + number_text(job.level) + " 阶已开工；第 " + number_text(job.readyDay + 1) + " 天竣工", "link": "build", "priority": 1, "type": "提醒"})
    for id in b.tools:
        if a.tools.has(id) and b.tools[id] > a.tools[id]:
            out.append({"text": str(catalog.tools.defs[id].name) + "升至第 " + number_text(b.tools[id]) + " 阶；可在工具手记选择用法", "link": "tools", "priority": 1, "type": "提醒"})
    for id in b.neighbors:
        var event: Variant = b.neighbors[id]
        var old_event: Variant = a.neighbors.get(id, null)
        if event is Dictionary and event.get("status") != (old_event.get("status") if old_event is Dictionary else null):
            var status: String = {"offered": "想找你搭把手", "done": "已经办妥", "accepted": "已答应帮忙", "postponed": "留待下次"}.get(event.get("status"), "已有新进展")
            out.append({"text": str(catalog.npc_names[id]) + "的邻里小事：" + status, "link": "neighbors", "priority": 1, "type": "社交"})
    return out

static func finish(before: Dictionary, after: Dictionary, point: Dictionary, spec: Dictionary, feedback: Dictionary, runtime: Dictionary, catalog: Dictionary, player: Dictionary, note: Callable) -> Variant:
    var delta := difference(before, after)
    var events := world_changes(before, after, catalog)
    if delta.items.is_empty() and delta.money == 0 and delta.relations.is_empty() and delta.fields.is_empty() and delta.stamina == 0 and events.is_empty(): return null
    var type := "收支" if delta.money != 0 or not delta.items.is_empty() else "社交" if not delta.relations.is_empty() else "照料"
    var day_row: Dictionary = {}
    for candidate in feedback.days:
        if candidate.day == after.day: day_row = candidate; break
    if day_row.is_empty():
        day_row = {"day": after.day, "actions": 0, "income": 0, "spent": 0, "items": {}}
        feedback.days.append(day_row)
        feedback.days = feedback.days.slice(-7)
    day_row.actions += 1
    day_row.income += max(0, delta.money)
    day_row.spent += max(0, -delta.money)
    for item in delta.items:
        if item.qty > 0:
            var key: String = str(item.id) + ":" + str(item.grade)
            day_row.items[key] = day_row.items.get(key, 0) + item.qty
    var details: Array[String] = []
    var important: Dictionary = {}
    var row_type := type
    for event in events:
        details.append(event.text)
        if important.is_empty() and event.priority > 0: important = event
    if events.any(func(event: Dictionary) -> bool: return event.type == "未完成"): row_type = "未完成"
    elif events.any(func(event: Dictionary) -> bool: return event.type == "社交"): row_type = "社交"
    details.append_array(describe_delta(delta, catalog.items, catalog.npc_names))
    var target_kind: String = str(point.get("kind", ""))
    var key: String = "action/" + str(spec.kind) + "/" + ("farm" if target_kind == "farm-task" else target_kind if target_kind != "" else "menu") + "/" + number_text(feedback.next)
    var link: String = str(important.link) if not important.is_empty() else str(events[0].link) if not events.is_empty() else "neighbors" if type == "社交" else "bag" if not delta.items.is_empty() else "feedback"
    var priority := 1 if not important.is_empty() or delta.items.any(func(item: Dictionary) -> bool: return item.qty > 0 and item.grade == 3) else 0
    var row: Dictionary = note.call({"key": key, "title": spec.get("label") if spec.get("label") != null and spec.get("label", "") != "" else "手边的事完成了", "text": "；".join(details), "type": row_type, "priority": priority, "link": link})
    if feedback.prefs.floating != "off":
        var gains: Array = delta.items.filter(func(item: Dictionary) -> bool: return item.qty > 0)
        for item in gains:
            var float_key: String = str(item.id) + ":" + str(item.grade)
            var prior: Dictionary = {}
            for candidate in runtime.floats:
                if candidate.key == float_key and runtime.clock - candidate.at < 4.5: prior = candidate; break
            var x: Variant = point.get("x") if point.get("x") != null else player.x
            var y: Variant = point.get("y") if point.get("y") != null else player.y
            if not prior.is_empty():
                prior.qty += item.qty; prior.at = runtime.clock; prior.x = x; prior.y = y
            else:
                runtime.floats.append({"key": float_key, "item": item.id, "grade": item.grade, "qty": item.qty, "at": runtime.clock, "x": x, "y": y})
        if not important.is_empty() or gains.is_empty() and (not delta.fields.is_empty() or delta.money != 0 or not delta.relations.is_empty() or not events.is_empty()):
            var visible: Array[String] = []
            for detail in details:
                if not detail.begins_with("体力") and visible.size() < 2: visible.append(detail)
            runtime.floats.append({"key": "result", "text": str(important.text) if not important.is_empty() else " · ".join(visible), "at": runtime.clock, "x": point.get("x") if point.get("x") != null else player.x, "y": point.get("y") if point.get("y") != null else player.y})
        runtime.floats = runtime.floats.slice(-4)
    return {"row": row, "delta": delta}

