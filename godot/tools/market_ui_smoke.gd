extends Node

var passed := 0
var failed := 0

func _ready() -> void:
	var world = load("res://scenes/main.tscn").instantiate()
	add_child(world)
	await get_tree().process_frame
	_check(get_tree().get_nodes_in_group("seasonal_world_props").size() == 742, "村庄与瓦片数据中的742件场景物件全部实例化")
	var effects: Node2D = world.get_node("WorldEffects")
	var prior_visual_fx: Dictionary = GameState.visual_fx.duplicate(true)
	GameState.visual_fx = {"density": "standard", "weather": "standard", "ambient": true, "motion": "full"}
	var effect_policy: Dictionary = effects.call("_policy")
	_check(int(effect_policy.count) == 12 and int(effect_policy.cap) == 72 and bool(effect_policy.ambient), "标准特效策略保留粒子上限与乡间动效")
	effects.call("burst", "harvest", world.player.global_position, false)
	effects.call("burst", "harvest", world.player.global_position + Vector2(4, 0), true)
	var effect_bursts: Array = effects.get("bursts")
	_check(effect_bursts.size() == 1 and bool(effect_bursts[0].rare), "短时间同位置收获反馈合并并保留珍品标记")
	var player_visual: Node = world.player.get("character_visual")
	world.call("_emit_world_effect", "water", world.player.global_position)
	_check(str(player_visual.get("action_state")) == "water", "成功浇水反馈触发角色倾壶动作")
	player_visual.call("_process", 2.0)
	_check(str(player_visual.get("action_state")) == "", "一次性农事动作在原定时长后收势")
	var festival_original_day := GameState.day
	var festival_original_minutes := GameState.minutes
	var festival_market_position: Vector2 = effects.get("festival_market")
	GameState.day = int(GameState.day / 112) * 112 + 13
	GameState.minutes = 700
	_check(bool(effects.call("festival_dressing_active")), "节庆日午间在老街开启四季装饰")
	effects.set("festival_market", world.player.global_position)
	effects.queue_redraw()
	await get_tree().process_frame
	GameState.minutes = 600
	_check(not bool(effects.call("festival_dressing_active")), "节庆装饰在会期外收起")
	effects.set("festival_market", festival_market_position)
	GameState.day = festival_original_day
	GameState.minutes = festival_original_minutes
	GameState.visual_fx.density = "off"
	effect_policy = effects.call("_policy")
	var saved_effects: Dictionary = GameState._make_save_data()
	_check(int(effect_policy.count) == 0 and not bool(effect_policy.ambient) and str(effect_policy.weather) == "gentle" and str(saved_effects.visual_fx.density) == "off", "关闭粒子保留珍品环反馈并写入存档设置")
	var legacy_fx: Dictionary = GameState._normalize_visual_fx({}, {"prefs": {"motion": "reduced"}}, {"particles": false})
	_check(str(legacy_fx.density) == "off" and str(legacy_fx.motion) == "reduced", "旧版粒子关闭与减少动画选项可转换")
	GameState.visual_fx = prior_visual_fx
	world.hud.call("show_settings")
	_check(bool(world.hud.call("settings_open")) and world.hud.settings_panel.visual_options.density.item_count == 3 and world.hud.settings_panel.visual_toggles.has("motion"), "设置面板提供特效密度与减少动画选项")
	world.hud.call("close_settings")
	var original_day := GameState.day
	var ground: TileMapLayer = world.get_node("Ground")
	var tile_before := ground.get_cell_atlas_coords(Vector2i(0, 0))
	var ground_data := ground.get_cell_tile_data(Vector2i(0, 0))
	_check(ground_data != null and str(ground_data.get_custom_data("surface_kind")) == "mountain_gravel" and int(ground_data.get_custom_data("season_index")) == GameState.season_index() and int(ground_data.get_custom_data("variant")) == posmod(tile_before.y, 4), "原生 TileSet 暴露地貌、季节与变体数据")
	var next_season := posmod(GameState.season_index() + 1, 4)
	GameState.day = next_season * 28
	GameState.changed.emit()
	var tile_after := ground.get_cell_atlas_coords(Vector2i(0, 0))
	_check(tile_after.y / 4 == next_season and tile_after.y % 4 == tile_before.y % 4, "换季批量切换地表瓦片色板并保留细节变体")
	GameState.day = original_day
	GameState.changed.emit()
	world.hud.call("show_market", "buy", true)
	_check(bool(world.hud.call("market_open")), "柜台可打开")
	_check(GameState.ui_open, "柜台开启时暂停角色移动")
	_check(world.hud.market_panel.item_ids.size() > 0, "柜台加载可购买物品")
	world.hud.call("close_market")
	_check(not GameState.ui_open and not bool(world.hud.call("market_open")), "关闭柜台恢复世界输入")
	world.hud.call("show_market", "inventory", false)
	_check(world.hud.market_panel.mode == "inventory", "背包可从世界单独打开")
	world.hud.call("close_market")
	world.hud.call("show_item_catalog")
	_check(bool(world.hud.call("item_catalog_open")) and GameState.ui_open, "F9 物品图录可打开并暂停移动")
	_check(world.hud.item_catalog_panel.item_ids.size() == 190, "物品图录读取全部 190 件物品")
	_check(str(world.hud.item_catalog_panel.detail_icon.get("item_id")) == "cabbage", "物品图录为选中条目绘制对应图标")
	world.hud.call("close_item_catalog")
	_check(not GameState.ui_open, "关闭物品图录恢复世界输入")
	world.hud.call("show_weather")
	_check(bool(world.hud.call("weather_open")) and GameState.ui_open, "观天簿开启并暂停移动")
	_check(world.hud.weather_panel.forecast_box.get_child_count() == 4, "观天簿显示四日预报")
	world.hud.call("close_weather")
	_check(not GameState.ui_open, "关闭观天簿恢复世界输入")
	_check(world.gather_nodes.size() >= 21, "世界生成溪南与天气限定采集点")
	GameState.discover_forage(str(world.gather_nodes[0].node_id))
	world.hud.call("show_forage")
	_check(bool(world.hud.call("forage_open")) and GameState.ui_open, "采集手记开启并暂停移动")
	_check(world.hud.forage_panel.point_ids.size() >= 1, "采集手记列出已发现资源")
	world.hud.call("close_forage")
	_check(not GameState.ui_open, "关闭采集手记恢复移动")
	var river_spot: Node2D
	for fish_spot in world.fish_nodes:
		if str(fish_spot.get("water_id")) == "river":
			river_spot = fish_spot
			break
	_check(river_spot != null, "地图实例化可交互的河岸钓点")
	river_spot.call("set_fishing_state", "fight", 0.25)
	river_spot.call("_process", 0.1)
	var fight_animation_time := float(river_spot.get("state_elapsed"))
	river_spot.call("set_fishing_state", "fight", 0.75)
	_check(float(river_spot.get("state_elapsed")) == fight_animation_time, "搏鱼张力更新保留当前动画时钟")
	river_spot.call("set_fishing_state", "idle")
	world.player.global_position=river_spot.global_position+Vector2(-30,0)
	GameState.player_position=world.player.global_position
	world.hud.call("show_fishing", "river", str(river_spot.get("spot_id")))
	_check(bool(world.hud.call("fishing_open")) and GameState.ui_open, "垂钓手记打开指定水域")
	_check(world.hud.fishing_panel.water_label.text.contains("柳岸河流"), "垂钓手记读取水域内容")
	GameState.set_fishing_option("bait", "plain")
	GameState.set_fishing_option("mode", "relaxed")
	world.hud.fishing_panel.start_cast()
	_check(world.hud.fishing_panel.active, "水边可以开始原生抛竿流程")
	_check(str(river_spot.get("fishing_state")) == "cast", "抛竿阶段的动画同步到选中的具体钓点")
	_check(str(player_visual.get("fishing_state")) == "cast", "角色进入对应持竿动作")
	world.hud.call("close_fishing")
	_check(not GameState.ui_open and not world.hud.fishing_panel.active, "收竿取消未完成垂钓并恢复移动")
	_check(str(river_spot.get("fishing_state")) == "idle", "取消垂钓复位钓点浮漂状态")
	_check(str(player_visual.get("fishing_state")) == "idle", "取消垂钓收回角色持竿姿势")
	world.hud.call("show_fishing", "river", str(river_spot.get("spot_id")))
	var catches_before := GameState.fish_caught
	world.hud.fishing_panel.start_cast()
	var landing_seen:=false
	for _step in range(100):
		if not world.hud.fishing_panel.active:
			break
		GameState._process_action(0.1)
		landing_seen=landing_seen or str(river_spot.get("fishing_state"))=="caught"
	_check(not world.hud.fishing_panel.active, "轻松观漂流程可完成")
	_check(GameState.fish_caught == catches_before + 1, "完成观漂后实际结算鱼获")
	_check(landing_seen and str(river_spot.get("fishing_state"))=="idle", "抄鱼在完整动作末阶段播放，结算后收好浮漂")
	_check(not bool(player_visual.get("sequence_managed")) and str(player_visual.get("fishing_state"))=="idle", "完整收杆后清除角色动作状态")
	world.hud.call("close_fishing")
	_check(str(player_visual.get("fishing_state")) == "idle", "关闭垂钓簿后角色姿势恢复")
	world.hud.call("show_kitchen", false)
	_check(bool(world.hud.call("kitchen_open")) and GameState.ui_open, "厨房手记可随时查阅")
	_check(world.hud.kitchen_panel.entry_ids.size() >= 1 and not world.hud.kitchen_panel.action_button.disabled, "远处可查看菜谱并预约走去小灶")
	world.hud.call("close_kitchen")
	world.hud.call("show_kitchen", true)
	_check(not world.hud.kitchen_panel.action_button.disabled, "走近小灶可操作菜谱")
	world.hud.kitchen_panel._choose_mode("process")
	_check(world.hud.kitchen_panel.entry_ids.size() >= 10, "厨房加载全部加工配方")
	GameState.inventory["rice"] = maxi(1, int(GameState.inventory.get("rice", 0)))
	world.hud.kitchen_panel._choose_mode("pantry")
	_check(world.hud.kitchen_panel.entry_ids.has("bag:rice"), "食橱列出随身食材")
	GameState.upgrades.storage = true
	var stored_rice := int(GameState.storage.get("rice", 0))
	world.hud.kitchen_panel.selected_id = "bag:rice"
	world.hud.kitchen_panel.quantity_box.value = 1
	world.hud.kitchen_panel._act()
	_check(int(GameState.storage.get("rice", 0)) == stored_rice + 1, "食橱界面可实际存入食材")
	world.hud.kitchen_panel._choose_mode("research")
	_check(world.hud.kitchen_panel.first_box.item_count > 0 and world.hud.kitchen_panel.second_box.item_count > 0, "试配页列出可用食材")
	world.hud.kitchen_panel._choose_mode("tools")
	_check(world.hud.kitchen_panel.entry_ids.size() == 10, "工位页列出十台设备")
	world.hud.call("close_kitchen")
	_check(not GameState.ui_open, "关闭厨房恢复移动")
	world.hud.call("show_tools", false)
	_check(bool(world.hud.call("tools_open")) and GameState.ui_open, "农具手记可随时查阅")
	_check(world.hud.tool_panel.tool_list.item_count == 6 and not world.hud.tool_panel.upgrade_button.disabled, "远处可查看六件工具并预约改良")
	world.hud.call("close_tools")
	world.hud.call("show_tools", true)
	_check(not world.hud.tool_panel.upgrade_button.disabled, "走近农具间可改良工具")
	world.hud.call("close_tools")
	_check(not GameState.ui_open, "关闭农具手记恢复移动")
	world.hud.call("show_farm_facilities", false, 7)
	_check(bool(world.hud.call("farm_facilities_open")) and GameState.ui_open, "田间设施簿可随时查看")
	_check(world.hud.farm_facility_panel.type_list.item_count == 7 and world.hud.farm_facility_panel.build_button.disabled, "设施簿载入七类设施并限制远处操作")
	world.hud.call("close_farm_facilities")
	world.hud.call("show_farm_planner", false, 7)
	_check(bool(world.hud.call("farm_planner_open")) and GameState.ui_open, "种子与土壤簿可随时查看")
	_check(world.hud.farm_planner_panel.crop_ids.size() == GameState.crop_catalog.size() and not world.hud.farm_planner_panel.soil_button.disabled, "种植簿读取全量作物并预约换土行走")
	world.hud.call("close_farm_planner")
	_check(not GameState.ui_open, "关闭种植簿恢复移动")
	world.hud.call("show_farm_facilities", true, 7)
	_check(not world.hud.farm_facility_panel.build_button.disabled, "靠近田块可以管理设施")
	world.hud.call("close_farm_facilities")
	GameState.day = 2
	var granny_relation: Dictionary = GameState.initial_state.get("relations", {}).get("granny", {})
	GameState.relations["granny"] = granny_relation.duplicate(true)
	var granny_story_state: Dictionary = GameState.initial_state.get("stories", {}).get("granny", {})
	GameState.npc_stories["granny"] = granny_story_state.duplicate(true)
	GameState.last_gifts.erase("granny")
	GameState.neighbors = {}
	GameState.ensure_neighbor_events()
	var granny_node: Node2D
	for npc in world.npc_nodes:
		if str(npc.get("npc_id")) == "granny":
			granny_node = npc
			break
	granny_node.global_position = world.player.global_position
	GameState.player_position = world.player.global_position
	GameState.npc_positions["granny"] = granny_node.global_position
	GameState.talk_to_npc("granny")
	world.hud.call("show_neighbors")
	_check(bool(world.hud.call("neighbors_open")) and GameState.ui_open, "邻里手记开启并暂停世界输入")
	_check(world.hud.neighbor_journal.resident_list.item_count == 24, "邻里手记列出全部村民")
	_check(world.hud.neighbor_journal.history_view.text.contains(str(GameState.neighbors.people.granny.last.text)), "邻里手记显示刚记录的对白")
	_check(world.hud.neighbor_journal.event_label.visible and not world.hud.neighbor_journal.event_buttons.accept.disabled, "邻里手记展示求助并允许就近答应")
	world.hud.neighbor_journal.event_buttons.accept.pressed.emit()
	await _finish_npc_action()
	_check(str(GameState.neighbors.people.granny.event.status) == "accepted", "邻里手记按钮实际接受求助")
	GameState.inventory["rice"] = 2
	GameState.changed.emit()
	world.hud.neighbor_journal.event_buttons.supply.pressed.emit()
	await _finish_npc_action()
	_check(str(GameState.neighbors.people.granny.event.status) == "done" and str(GameState.neighbors.people.granny.event.method) == "supply", "邻里手记按钮交付材料并完成事件")
	GameState.inventory["greens"] = 1
	GameState.changed.emit()
	var greens_index := -1
	for gift_index in range(world.hud.neighbor_journal.gift_item_option.item_count):
		if str(world.hud.neighbor_journal.gift_item_option.get_item_metadata(gift_index)) == "greens":
			greens_index = gift_index
			break
	world.hud.neighbor_journal.gift_item_option.select(greens_index)
	var points_before_gift := int(GameState.relations.granny.points)
	world.hud.neighbor_journal.gift_button.pressed.emit()
	await _finish_npc_action()
	_check(greens_index >= 0 and int(GameState.relations.granny.points) == points_before_gift + 15 and int(GameState.inventory.greens) == 0, "邻里手记可选择并送出村民喜欢的料理")
	_check(not world.hud.neighbor_journal.story_open_button.disabled, "达到条件后邻里手记可打开个人故事")
	world.hud.neighbor_journal.story_open_button.pressed.emit()
	_check(world.hud.npc_story_panel.visible and world.hud.npc_story_panel.choice_buttons.size()==2 and world.hud.npc_story_panel.last_view.title.contains("旧便条里的饭桌") and world.hud.npc_story_panel.quote.text==str(GameState.content.arcs.granny[0].text), "故事视图展示原版章节和分支回应")
	world.hud.npc_story_panel.choice_buttons[1].pressed.emit()
	await _finish_npc_action()
	_check(int(GameState.npc_stories.granny.step) == 1 and str(GameState.neighbors.people.granny.last.choice) == "把自己做的饭添进名单。", "手记里的分支按钮保存选择并推进故事")
	world.hud.close_top_panel()
	_check(not GameState.ui_open, "关闭邻里手记恢复世界输入")
	world.hud.call("show_museum", "catalog", "npc:granny")
	_check(bool(world.hud.call("museum_open")) and world.hud.museum_panel.selected_key == "npc:granny", "人物图鉴可定位已认识的村民条目")
	_check(world.hud.museum_panel.character_portrait.visible and str(world.hud.museum_panel.character_portrait.get("character_key")) == "granny", "人物图鉴显示村民原生肖像")
	_check(world.hud.museum_panel.detail_label.text.contains("身份：") and world.hud.museum_panel.detail_label.text.contains("已听故事："), "人物图鉴显示身份与已听故事进度")
	world.hud.call("close_museum")
	_check(not GameState.ui_open, "关闭人物图鉴恢复世界输入")
	print("Gameplay UI migration: %d passed, %d failed" % [passed, failed])
	world.free()
	await get_tree().root.get_node("AudioService").prepare_exit()
	get_tree().quit(1 if failed > 0 else 0)

func _finish_npc_action() -> void:
	for step in range(40):
		if not GameState.action_busy():break
		GameState._process_action(0.1)
	await get_tree().process_frame
	await get_tree().process_frame

func _check(condition: bool, label: String) -> void:
	if condition:
		passed += 1
	else:
		failed += 1
		push_error("FAIL: " + label)
