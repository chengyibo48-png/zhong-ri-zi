extends RefCounted
## Optional pacing suggestions; no deadline, reward or save fields.
static func suggestion(day: int) -> String:
	if day < 7:
		return "起步的几件事已经会了。可以用一份收成做饭、去河边坐坐，或给邻居送点心。今天做一件想做的事就够了。"
	match posmod(day,112)/28:
		0: return "春天可以先把照料路线走顺。留一些种子给下一茬，也留一点空闲给邻里。"
		1: return "夏天多看看天气和田里的水分。热的时候歇一歇，料理和采集可以慢慢安排。"
		2: return "秋收可以分一些进食橱，分一些摆摊，余下留给自己和朋友。工程不用赶在同一天完成。"
		_: return "冬天适合整理收成、试做家常菜，再翻翻邻里的故事。走过一年以后，院子和关系都会接着留在这里。"
