extends SceneTree

const SMOKE_FILES := preload("res://tools/smoke_files.gd")

var passed := 0
var failed := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var state = load("res://scripts/game_state.gd").new()
	state._load_content()
	state._load_initial_state()
	state._reset_plots()
	state.inventory = state._new_inventory()
	state.day = 0
	state.neighbors = {}
	state.talk_to_npc("granny")
	_check(int(state.relations.granny.points) == 5, "每日首次交谈增加五点关系")
	_check(bool(state.neighbors.people.granny.introduced), "初次交谈登记人物初识状态")
	_check(str(state.neighbors.people.granny.last.category) == "故事", "首次交谈按原版候选顺序选择可用故事对白")
	state.talk_to_npc("granny")
	_check(int(state.relations.granny.points) == 5, "同一天重复交谈不重复增加关系")
	_check(state.npc_history("granny").size() == 2, "同日不同对白进入交谈历史")
	var qiao: Dictionary = state.npc_catalog[1]
	state.day = int(qiao.birthday) - 1
	state.neighbors.people.qiao = {"introduced": true, "recent": ["story-0"], "last": {}}
	state.talk_to_npc("qiao")
	_check(str(state.neighbors.people.qiao.last.category) == "节庆" and str(state.neighbors.people.qiao.last.key).begins_with("birthday-"), "生日对白优先于普通对白")
	state.day = 13
	state.neighbors.people.lin = {"introduced": true, "recent": ["story-0"], "last": {}}
	state.talk_to_npc("lin")
	_check(str(state.neighbors.people.lin.last.key) == "festival-14-0", "节令当天使用当季饭桌对白")
	state.neighbors = {}
	state.day = 1
	state.ensure_neighbor_events()
	_check(state.neighbors.people.granny.event.is_empty(), "首轮邻里小事在第二天前不出现")
	state.day = 2
	state.ensure_neighbor_events()
	_check(str(state.neighbors.people.granny.event.status) == "offered" and str(state.neighbors.people.qiao.event.status) == "offered", "第二天按原版轮换表向两位村民发起求助")
	state.npc_positions = {"granny": state.player_position + Vector2(80, 0), "qiao": state.player_position}
	_check(state.npc_is_near("granny") and not state.npc_is_near("missing"), "事件距离校验遵循八十像素交谈范围")
	var granny_points := int(state.relations.get("granny", {}).get("points", 0))
	_check(state.resolve_npc_event("granny", "accept", 2), "靠近村民后可以答应无期限的帮忙请求")
	_check(str(state.neighbors.people.granny.event.status) == "accepted", "接受后保留待办状态")
	state.inventory["rice"] = 1
	_check(not state.resolve_npc_event("granny", "supply", 2) and int(state.inventory.rice) == 1, "材料不足时不会扣物品或关闭事件")
	state.inventory["rice"] = 2
	_check(state.resolve_npc_event("granny", "supply", 2), "可提交请求对应的两份材料完成事件")
	_check(str(state.neighbors.people.granny.event.method) == "supply" and int(state.relations.granny.points) == granny_points + 6, "交材料完成后记录方式并增加六点关系")
	_check(str(state.neighbors.history.back().choice).contains("稻米 ×2"), "邻里手记保存完成方式")
	var qiao_points := int(state.relations.get("qiao", {}).get("points", 0))
	_check(state.resolve_npc_event("qiao", "later", 2), "可以将求助暂缓")
	_check(int(state.relations.get("qiao", {}).get("points", 0)) == qiao_points and str(state.neighbors.people.qiao.event.status) == "postponed", "暂缓不扣关系且请求仍可重新接起")
	_check(state.resolve_npc_event("qiao", "accept", 2), "暂缓的请求可以随后接受")
	state.stamina = 10
	state.minutes = 600
	_check(state.resolve_npc_event("qiao", "join", 2), "接受后可以选择共同劳动完成")
	_check(state.stamina == 7 and state.minutes == 620 and str(state.neighbors.people.qiao.event.method) == "join", "共同劳动消耗三点体力与二十分钟")
	var granny_gift_points := int(state.relations.granny.points)
	state.inventory["greens"] = 1
	_check(state.gift_npc("granny", "greens"), "可以向附近村民送出背包物品")
	_check(int(state.relations.granny.points) == granny_gift_points + 15 and int(state.inventory.greens) == 0, "送出偏好料理消耗物品并增加十五点关系")
	_check(not state.gift_npc("granny", "rice"), "同一村民每天最多收一份礼物")
	state.day = 3
	state.npc_positions["granny"] = state.player_position
	state.inventory["greens"] = 1
	var repeated_gift_points := int(state.relations.granny.points)
	_check(state.gift_npc("granny", "greens") and int(state.relations.granny.points) == repeated_gift_points + 8, "连续送同一礼物时好感收益减半并向上取整")
	var qiao_arc: Array = state.content.arcs.qiao
	for chapter in range(4):
		state.day = 10 + chapter
		state.relations.qiao.points = maxi(int(state.relations.qiao.points), int(qiao_arc[chapter].points))
		var story_needs: Variant = qiao_arc[chapter].get("needs", {})
		if story_needs is Dictionary and not story_needs.is_empty():
			state.inventory.greens = 1
		_check(bool(state.npc_story_readiness("qiao").ok), "达到关系和材料条件后可读下一章")
		var answer := 0 if chapter == 3 else chapter % 2
		_check(state.choose_npc_story("qiao", answer), "分支故事第 %d 章可以选择回应" % (chapter + 1))
	_check(int(state.npc_stories.qiao.step) == 4 and str(state.partners.qiao) == "dating", "第四章选择可确立恋爱关系，双方也可以选择朋友")
	state.money = 100
	state.inventory.wood = 0
	state.inventory.bamboo = 0
	_check(not state.upgrade_home_room() and state.money == 100, "材料或金币不足时不会扣除厢房费用")
	state.money = 500
	state.inventory.wood = 10
	state.inventory.bamboo = 4
	_check(state.upgrade_home_room() and state.money == 280 and bool(state.upgrades.room), "厢房按原版成本解锁共同生活空间")
	state.day = 14
	state.relations.qiao.points = 75
	_check(state.marry_npc("qiao") and str(state.marriage.spouse) == "qiao", "完成关系确认、信任和厢房条件后可结婚")
	_check(bool(state.npc_story_readiness("qiao").ok), "结婚后解锁共同生活的故事章节")
	_check(state.choose_npc_story("qiao", 0) and int(state.npc_stories.qiao.step) == 5, "结婚后的最终故事可结章")
	_check(state.share_life("visit") and state.marriage.memories.size() == 1, "每周共同安排会留下伴侣生活记忆")
	var event_path := SMOKE_FILES.create_path("npc_event_smoke")
	state.save_game(event_path)
	var event_save = load("res://scripts/game_state.gd").new()
	event_save._load_content()
	event_save._load_initial_state()
	var event_read_back: bool = event_save.load_game(event_path)
	_check(event_read_back, "v16 邻里与故事存档可正常读回")
	if event_read_back:
		_check(str(event_save.neighbors.people.granny.event.method) == "supply" and str(event_save.neighbors.people.qiao.event.method) == "join", "读档保留两种事件完成方式")
		_check(str(event_save.last_gifts.granny) == "greens", "读档保留连续送礼偏好记录")
		_check(int(event_save.npc_stories.qiao.step) == 5 and str(event_save.marriage.spouse) == "qiao" and event_save.marriage.memories.size() == 1, "读档保留剧情选择和共同生活进度")
	SMOKE_FILES.remove(event_path)
	_check(state.separate_from_partner() and str(state.partners.qiao) == "friend" and str(state.marriage.spouse) == "", "可以友好分开并保留关系故事")
	var old_points := int(state.relations.get("mei", {}).get("points", 0))
	for next_day in range(5):
		state.day = 20 + next_day
		state.talk_to_npc("mei")
	_check(int(state.relations.mei.points) == old_points + 25, "跨日关系累积受每日一次限制")
	_check(int(state.inventory.get("rice", 0)) >= 2, "达到关系门槛后收到一次新米回礼")
	var path := SMOKE_FILES.create_path("npc_dialogue_smoke")
	state.save_game(path)
	var restored = load("res://scripts/game_state.gd").new()
	restored._load_content()
	restored._load_initial_state()
	var dialogue_read_back: bool = restored.load_game(path)
	_check(dialogue_read_back, "v15 邻里手记存档可读回")
	if dialogue_read_back:
		_check(restored.npc_history("mei").size() == 5, "读档保留 NPC 交谈历史")
	SMOKE_FILES.remove(path)
	var legacy_path := SMOKE_FILES.create_path("npc_dialogue_v13")
	state.save_game(legacy_path)
	var legacy_file := FileAccess.open(legacy_path, FileAccess.READ)
	var legacy_data: Dictionary = JSON.parse_string(legacy_file.get_as_text())
	legacy_file.close()
	legacy_data.version = 13
	legacy_data.erase("neighbors")
	legacy_data.erase("last_gifts")
	legacy_data.erase("npc_stories")
	legacy_data.erase("partners")
	legacy_data.erase("marriage")
	var rewrite := FileAccess.open(legacy_path, FileAccess.WRITE)
	rewrite.store_string(JSON.stringify(legacy_data))
	rewrite.close()
	var old_save = load("res://scripts/game_state.gd").new()
	old_save._load_content()
	old_save._load_initial_state()
	_check(old_save.load_game(legacy_path), "v13 旧档兼容读入")
	_check(old_save.neighbors.people.size() == 24 and old_save.neighbors.history.is_empty(), "旧档为 24 位村民补齐空白邻里手记")
	_check(int(old_save.npc_stories.qiao.step) == 0 and str(old_save.marriage.spouse) == "", "v13 旧档补齐空白个人故事和伴侣状态")
	legacy_data.version = 14
	legacy_data.neighbors = {"people": "invalid", "history": "invalid"}
	rewrite = FileAccess.open(legacy_path, FileAccess.WRITE)
	rewrite.store_string(JSON.stringify(legacy_data))
	rewrite.close()
	var malformed_save = load("res://scripts/game_state.gd").new()
	malformed_save._load_content()
	malformed_save._load_initial_state()
	_check(malformed_save.load_game(legacy_path), "损坏的手记字段不阻止其他存档读入")
	_check(malformed_save.neighbors.people.size() == 24 and malformed_save.neighbors.history.is_empty(), "异常手记字段被安全重置")
	SMOKE_FILES.remove(legacy_path)
	print("NPC dialogue migration: %d passed, %d failed" % [passed, failed])
	state.free()
	event_save.free()
	restored.free()
	old_save.free()
	malformed_save.free()
	await root.get_node("AudioService").prepare_exit()
	quit(1 if failed > 0 else 0)

func _check(ok: bool, label: String) -> void:
	if ok:
		passed += 1
		print("PASS ", label)
	else:
		failed += 1
		push_error("FAIL " + label)
