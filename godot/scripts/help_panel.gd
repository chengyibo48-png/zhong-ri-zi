extends Control

const ARTICLES: Array[Dictionary] = [
	{"title":"任务与今天的打算","keywords":"任务 委托 指引 追踪 交付 回礼 订单 截止 期限 寻路",
	"sections":[
		{"heading":"手记告诉你下一步","text":"按 J 或点画面左上的任务手记，查看进行中、可接取、已完成与今天的打算。当前步骤、合格材料、品质、鲜度、保护状态和办理地点都会列出。最多固定两项任务，不用每天清空。"},
		{"heading":"顺着线索找到真实地点","text":"查来源会打开同一套图鉴与配方；返回后保留原任务。地图标记只指向合法站位；沿路寻路由你主动开启。人物会移动，行踪标记与寻路跟随实际位置；方向键或 Esc 可以停下。"},
		{"heading":"面对面交付","text":"任务交付与普通送礼分开。材料备齐后找到人物；合作订单在合作社交接处办理，柜台 08:00—20:00 接单；公共事务在现场立牌处动工。动作完成时再次核对，取消或材料不足不会扣走未提交物品。"},
		{"heading":"期限与回礼","text":"主线、人物与引导任务没有期限，今天的打算可以忽略。合作订单主动接取后保存条件，并显示截止日；过期或放弃不扣钱与关系，未交物资保留。物品回礼放不下时会保留，整理后再领。"},
		{"heading":"四十件起步的小事","text":"安顿小院、农事、牧场、水畔、家常、邻里、共建与四季留痕可以并行。购买不能替代亲自种植或捕获；要求接取后完成的动作会单独计数。普通目标不要求珍品或全图鉴。手柄 View 打开任务，肩键切页，A 确认，B 返回。"}
	]},
	{
		"title": "日常与按键",
		"keywords": "移动 行走 互动 键位 菜单 存档 设置 手柄",
		"sections": [
			{"heading": "把日子过慢一点", "text": "WASD 或方向键移动，Shift 快走，通过手边操作骑车 / 下车；进屋自动下车。E / Space 互动。靠近居民、建筑、田地和服务点再操作；户外和屋内可按 [ / ] 或手柄 L3 切换近距目标，黄色圈表示当前选择；打开生活簿时游戏时间暂停。点击指南按钮或生活菜单中的帮助可打开这本指南，Esc 返回。"},
			{"heading": "常用快捷键", "text": "背包、地图、任务及移动/交互键可在设置中修改；改键以设置显示为准。默认 M 地图 · Tab / Esc 生活菜单 · 手柄 Y 地图、Start / B 菜单 · B 背包 · J 任务手记 · C 日历 · F 全屏 · H 收起界面。打开页面后使用按钮操作，Esc 返回上一页；功能簿可通过生活菜单或对应设施查看。"},
			{"heading": "农事与生活", "text": "1 锄头、2 种子、3 水壶、4 双手、5 鱼竿、6 斧头、7 采集镰刀、8 布置工具；手柄左右肩键轮换。双手收单块，镰刀按改良范围收获；施肥和田间护理在农事簿中管理；Q 选种，近身照料通过牧场名册和伙伴的操作按钮安排。生活手艺、存档、设置和信箱通过对应的页面按钮查看。设置可以重绑常用字母键、调整文字和音量。"}
		]
	},
	{
		"title": "从第一块田开始",
		"keywords": "种植 农事 种子 播种 浇水 收获 田垄",
		"sections": [
			{"heading": "锄地、播种、照料、收获", "text": "选 1 并在空地旁互动开垦，选 2 并在田垄旁播种，选 3 浇水；作物按日生长，选 4 收成熟作物。雨水也会浇灌。漏浇会拖慢生长，萎蔫可以救回，成熟后不必立刻收割。"},
			{"heading": "田地不是计时器", "text": "田地会记录湿度、肥力、健康、杂草、虫害和病害。土质、天气、季节、种植密度与连续种同科作物都会影响生长。不是每块田都需要每天浇水；留意叶片和田垄提示，再决定今天要不要照料。"},
			{"heading": "把农事安排成路线", "text": "P 打开种子与土壤簿，可选作物、种子类型和株距，也能查看 97 块田（小院 7×7、东坡 48 格）的状态、轮作记录、伴生作物和管理动作。田间动作消耗体力与材料；休耕、豆科绿肥和轮作能让土地缓口气。"}
		]
	},
	{
		"title": "水土、品质与田间风险",
		"keywords": "土壤 肥力 湿度 轮作 套种 病虫 品质 设施",
		"sections": [
			{"heading": "水土要配作物", "text": "五类土质各有蒸发和适种特点：水田土照料喜湿作物，沙土更适合部分根菜，腐殖土更适合叶菜。田块湿度过低会缺水，过高可能涝害；堆肥补地力，缓释肥分日供肥，排水和休耕也能修复土地。"},
			{"heading": "品质由整季照料决定", "text": "收成分普通、优质、上品、珍品，受田块健康、肥力、水分、病虫压力、种子类型和设施影响。高品质既可卖出更好价格，也适合留种、做料理、完成订单或捐赠；背包与料仓会保留品质批次。"},
			{"heading": "风险有对应办法", "text": "虫害、病害和杂草分别累积，连作、密植、湿热和弱土会提高风险。可用人工捉虫、草本护苗、速效处理、除草、深耕或设施来应对。稻草人驱鸟；喷灌、温室、遮阳、排水等设施要安置在有效田埂范围并维护耐久。"},
			{"heading": "轮作与套种", "text": "轮换作物科属能减轻连作压力，豆科可养地。部分不同科作物互相帮衬；同一田垄可有主作物和伴生作物，分别成熟、分开采收。株距会改变种子消耗、产量和田间压力。"}
		]
	},
	{
		"title": "照料动物与牧场",
		"keywords": "牧场 动物 鸡 鸭 牛 羊 猪 喂养 产物 繁育",
		"sections": [
			{"heading": "每日照料不是打卡", "text": "O 打开牧场名册，可查看饱食、健康、心情、清洁、疾病、年龄、性格和待收产物。近身可用 E 照料；名册支持喂食、收取、抚摸、梳洗、治疗、请兽医、留舍或放牧。动物不会死亡，走失伙伴可以沿地图寻回。"},
			{"heading": "草场与畜舍", "text": "晴天放牧能觅食，但会消耗草量；切换轮牧区让草场恢复。恶劣天气、幼崽、休养伙伴适合留舍。畜舍可扩容、改善巢床、防护和收集，也能清扫、铺垫草、修缮并逐步安装自动化；自动食槽消耗料仓库存。"},
			{"heading": "产物、繁育与品质", "text": "健康、营养、亲近、清洁与舒适度会影响产出节奏和品质。鸡鸭产蛋、牛产奶、羊产毛、猪带来圈肥及偶发觅得物。成年同种动物满足健康、心情、饱食、清洁和床位要求后可安排繁育；受精蛋可在巢箱孵化。"},
			{"heading": "猫狗也有自己的生活", "text": "猫狗可喂养、训练并切换回家、跟随或巡看模式。训练与亲近会强化辅助效果。牧场配方能把草料、谷物、奶、毛和圈肥加工成补给与手作材料。"}
		]
	},
	{
		"title": "厨房、加工与食材",
		"keywords": "厨房 烹饪 加工 菜谱 新鲜度 火候 食橱",
		"sections": [
			{"heading": "从收成到饭桌", "text": "K 随时查阅厨房手记；走到合适工位才能实际制作。已学菜谱支持批量烹饪，试配可以探索新组合。加工品按设备排队，可能需要等到次日并手动收取。"},
			{"heading": "品质与新鲜度会留下来", "text": "料理与加工结果会读取原料品质、新鲜度、火候、工位清洁度及天气条件。食材和料理按批次保留品质与陈放时间；普通品质会优先用于消耗，珍品可以留作收藏、赠礼或订单。"},
			{"heading": "料理能帮上忙", "text": "料理可恢复体力或提供限时增益，也能用于邻里心愿和四季饭桌。食橱可集中存放食材；阴凉改良会减慢陈放。晾晒等工序受天气影响，安排加工时记得看预报。"}
		]
	},
	{
		"title": "村庄、交易与行走",
		"keywords": "地图 村庄 NPC 交易 商店 摆摊 合作社 天气 采集 钓鱼",
		"sections": [
			{"heading": "认路与找人", "text": "M（或设置的地图键）打开六区地图，可按类别查看建筑、居民、农田、采集点、钓点和家畜，搜索或点击地点预览路线，选择“沿这条路出发”后角色会自动行走；在屋里出发会先走到原门，抵达建筑入口后自动进屋。方向键可接管行走；Esc 或手柄 B 会打开生活菜单并停止带路，地图也有停止按钮。所选地点可留下图钉。道路路线会绕开水域与已登记的障碍；小地图可以在设置或地图界面管理。"},
			{"heading": "居民有自己的作息", "text": "村民会按时工作、回家、赶集、上学或参加聚会。N 打开邻里手记查看关系、喜好、请求与故事；面对面交谈、送礼、帮忙和剧情选择会留下长期影响。生日、节庆与关系阶段会带来特别对白。"},
			{"heading": "交易与季节", "text": "B 打开背包与交易界面。集镇柜台可购买、出售及短期回购；庭院主题摊位和合作社代销会根据需求、品质、新鲜度、季节与年景结算。换季关注当季种子、集日和天气；订单与交易记录在经营页面查看。"},
			{"heading": "野外是会恢复的", "text": "通过山野操作查看采集手记，轻采可照顾资源再生；通过水岸操作查看垂钓手记，鱼种会受水域、季节、时段、天气和鱼饵影响。采集、钓鱼、居民行程与农牧生产都读取同一套游戏日历和天气。"}
		]
	},
	{
		"title": "建设、图鉴与保存",
		"keywords": "建设 房屋 家具 装修 仓库 图鉴 村史馆 捐赠 保存 读取",
		"sections": [
			{"heading": "让院子慢慢长成家", "text": "生活菜单中的营造入口打开营造簿，可扩建老屋、整理庭院与西院、升级功能建筑、制作和摆放家具。草图会检查占地、道路、障碍、材料与步行可达性；摆放后的实体家具也会影响实际通行和地图寻路。"},
			{"heading": "发现、研究、捐赠", "text": "M 打开发现册，记录作物、动物、鱼类、物品、居民、地区和民俗。收获、观察、故事与亲近度会推进图鉴研究。村史馆可接收样品、鱼获、观察、口述和旧物副本；收集包、展馆升级、常设展品与徽章会逐步开放。"},
			{"heading": "安全保存生活", "text": "点击存档按钮管理自动档、三个手动档、备份/恢复及 JSON 导入导出。生活菜单中的设置可调整速度、镜头、文字、音量、提示和键位。浏览器旧存档导入会保留原始副本；重要操作前也可手动存档。"},
			{"heading": "节庆与休息", "text": "通过乡里共作簿打开四季饭桌，带一道料理参加本季或补办往季聚会。回老屋睡觉推进日期；井边和长椅能恢复体力。每日经营没有强制清单，按自己的节奏在农事、交往、探索和休息之间取舍。"}
		]
	}
]

var topic_list: ItemList
var search_field: LineEdit
var article_body: VBoxContainer
var topic_ids: Array[int] = []
var selected_article := 0

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var backdrop := ColorRect.new()
	backdrop.color = Color(0.06, 0.10, 0.08, 0.86)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)

	var panel := PanelContainer.new()
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -450
	panel.offset_right = 450
	panel.offset_top = -276
	panel.offset_bottom = 276
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color("2e3b30")
	panel_style.border_color = Color("b0b886")
	panel_style.set_border_width_all(3)
	panel_style.set_corner_radius_all(8)
	panel_style.set_content_margin_all(14)
	panel.add_theme_stylebox_override("panel", panel_style)
	add_child(panel)

	var column := VBoxContainer.new()
	set_meta("notification_column",column);set_meta("notification_index",1)
	column.add_theme_constant_override("separation", 10)
	panel.add_child(column)
	var header := HBoxContainer.new()
	column.add_child(header)
	var title := Label.new()
	title.text = "禾溪生活指南"
	title.add_theme_font_size_override("font_size", 24)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var close_button := Button.new()
	close_button.text = "关闭 Esc"
	close_button.pressed.connect(close)
	header.add_child(close_button)

	var search_row := HBoxContainer.new()
	column.add_child(search_row)
	var search_hint := Label.new()
	search_hint.text = "查找"
	search_row.add_child(search_hint)
	search_field = LineEdit.new()
	search_field.placeholder_text = "搜种植、畜牧、按键、存档……"
	search_field.clear_button_enabled = true
	search_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	search_field.text_changed.connect(_search_changed)
	search_row.add_child(search_field)

	var content := HBoxContainer.new()
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 12)
	column.add_child(content)
	topic_list = ItemList.new()
	topic_list.custom_minimum_size = Vector2(190, 0)
	topic_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	topic_list.item_selected.connect(_topic_selected)
	content.add_child(topic_list)

	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content.add_child(scroll)
	article_body = VBoxContainer.new()
	article_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	article_body.add_theme_constant_override("separation", 12)
	scroll.add_child(article_body)

	var footer := Label.new()
	footer.text = "操作会在生活簿关闭后继续；需要确认的操作会在界面中再次提示。"
	footer.add_theme_color_override("font_color", Color("d9c99f"))
	column.add_child(footer)
	visible = false
	_refresh_topics("")

func open_panel() -> void:
	if GameState.action_busy():return
	preload("res://scripts/modal_status.gd").clear_message(self)
	visible = true
	GameState.ui_open = true
	search_field.clear()
	_refresh_topics("")
	topic_list.grab_focus()

func close() -> void:
	visible = false
	GameState.ui_open = false

func is_open() -> bool:
	return visible

func _search_changed(query: String) -> void:
	_refresh_topics(query)

func _refresh_topics(query: String) -> void:
	if not is_instance_valid(topic_list):
		return
	var previous_article := selected_article
	var needle := query.strip_edges().to_lower()
	topic_ids.clear()
	topic_list.clear()
	for i in range(ARTICLES.size()):
		var article: Dictionary = ARTICLES[i]
		var searchable := ("%s %s" % [str(article.get("title", "")), str(article.get("keywords", ""))]).to_lower()
		for section in article.get("sections", []):
			searchable += " " + str(section.get("heading", "")).to_lower() + " " + str(section.get("text", "")).to_lower()
		if needle.is_empty() or searchable.contains(needle):
			topic_ids.append(i)
			topic_list.add_item(str(article.get("title", "")))
	if topic_ids.is_empty():
		_clear_article("没有找到相关条目。试试“种子”“产物”“地图”或“存档”。")
		return
	var selected_slot := topic_ids.find(previous_article)
	if selected_slot < 0:
		selected_slot = 0
	selected_article = topic_ids[selected_slot]
	topic_list.select(selected_slot)
	_show_article(selected_article)

func _topic_selected(index: int) -> void:
	if index < 0 or index >= topic_ids.size():
		return
	selected_article = topic_ids[index]
	_show_article(selected_article)

func _clear_article(message: String) -> void:
	for child in article_body.get_children():
		child.queue_free()
	var empty_label := Label.new()
	empty_label.text = message
	empty_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	article_body.add_child(empty_label)

func _show_article(index: int) -> void:
	for child in article_body.get_children():
		child.queue_free()
	var article: Dictionary = ARTICLES[index]
	for section in article.get("sections", []):
		var card := PanelContainer.new()
		var style := StyleBoxFlat.new()
		style.bg_color = Color("39483a")
		style.border_color = Color("71806b")
		style.set_border_width_all(1)
		style.set_corner_radius_all(5)
		style.set_content_margin_all(10)
		card.add_theme_stylebox_override("panel", style)
		article_body.add_child(card)
		var card_column := VBoxContainer.new()
		card_column.add_theme_constant_override("separation", 5)
		card.add_child(card_column)
		var heading := Label.new()
		heading.text = str(section.get("heading", ""))
		heading.add_theme_color_override("font_color", Color("e7d8b3"))
		heading.add_theme_font_size_override("font_size", 18)
		card_column.add_child(heading)
		var paragraph := Label.new()
		paragraph.text = str(section.get("text", ""))
		paragraph.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		paragraph.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card_column.add_child(paragraph)

