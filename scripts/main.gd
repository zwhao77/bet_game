# main.gd
extends Node2D

@onready var loot_generator = $Generator

# 核心变量
var current_loot = []
var grid_dim = Vector2i(15, 30)
var tile_size = 32.0

# 动画控制
var draw_index = 0 # 当前绘制到第几个物品
var is_animating = false # 是否正在播放生成动画
var animation_speed = 0.07 # 每个物品出现的间隔秒数
var anim_timer = 0.0
var luck = 0

func _ready() -> void:
	get_tree().root.size_changed.connect(_on_window_resized)
	_do_generate()

func _process(delta: float) -> void:
	if not is_animating:
		return

	anim_timer += delta

	# 动态获取当前进度对应的物品品质
	if draw_index < current_loot.size():
		#var current_item_rarity = current_loot[draw_index].res.rarity
		# 计算当前物品需要的展示时间：R0-R2 快，R3-R5 慢
		var effective_speed = animation_speed
		if anim_timer >= effective_speed:
			anim_timer = 0
			draw_index += 1
			queue_redraw()
	else:
		is_animating = false

func _do_generate():
	# 随机化参数
	luck = randf() * 2 - 1
	var budget = 1000000.0 + randf() * 5000
	# 对应 R0, R1, R2, R3, R4
	# 在 Luck = 0.5 时，出率比例恰好为 1 : 2 : 3 : 4 : 5
	var r_k = {
		0: - 1.02, # 极力压制
		1: - 0.58, # 适度压制
		2: 0.0, # 基准线（不随 Luck 变化相对权重）
		3: 0.81, # 适度拔高
		4: 2.20 # 极力拔高
	}
	var w_k = {1: 1.0, 2: 0.0, 3: 0.5, 4: 0.4, 5: 0.5}

	# 生成逻辑
	current_loot = loot_generator.generate_loot(luck, budget, grid_dim, r_k, w_k, 0.05)

	# 重置动画状态
	draw_index = 0
	is_animating = true

	_recalculate_layout()
	queue_redraw()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"): # 空格重新生成
		_do_generate()

	if event is InputEventMouseButton and event.pressed: # 点击跳过动画
		_skip_animation()

func _skip_animation():
	if is_animating:
		draw_index = current_loot.size()
		is_animating = false
		queue_redraw()

func _recalculate_layout():
	var win_size = get_viewport_rect().size
	# 分配 70% 宽度给网格，30% 给侧边栏
	var available_w = win_size.x * 0.65
	var available_h = win_size.y * 0.9
	tile_size = min(available_w / grid_dim.x, available_h / grid_dim.y)

func _on_window_resized():
	_recalculate_layout()
	queue_redraw()

func _draw():
	var win_size = get_viewport_rect().size
	var grid_pixel_size = Vector2(grid_dim) * tile_size
	var grid_offset = Vector2(win_size.x * 0.05, (win_size.y - grid_pixel_size.y) / 2.0)

	draw_set_transform(grid_offset)

	# 第一层：绘制所有物品的轮廓（占位感）
	# 哪怕 draw_index 还没到，玩家也能一眼看到整个背包的布局
	for entry in current_loot:
		var item = entry.res
		var rect = Rect2(Vector2(entry.pos) * tile_size, Vector2(item.width, item.height) * tile_size)

		# 绘制半透明的深色背景作为底座
		draw_rect(rect, Color(0.2, 0.2, 0.2, 0.4))
		# 绘制浅灰色的细边框
		draw_rect(rect, Color(0.4, 0.4, 0.4, 0.5), false, 1.0)

	# 第二层：绘制已“激活”填充色的物品
	for i in range(draw_index):
		var entry = current_loot[i]
		var item = entry.res
		var rect = Rect2(Vector2(entry.pos) * tile_size, Vector2(item.width, item.height) * tile_size)
		var color = _get_rarity_color(item.rarity)

		# 填充品质色
		draw_rect(rect, color)
		# 绘制深色边框增加立体感
		draw_rect(rect, Color.BLACK, false, 1.0)

		# 可选：如果是刚刚蹦出来的那个，加一个高亮边框
		if i == draw_index - 1 and is_animating:
			draw_rect(rect, Color.WHITE, false, 2.0)

	# 3. 绘制侧边栏
	draw_set_transform(Vector2.ZERO)
	_draw_sidebar(win_size)

func _draw_sidebar(win_size: Vector2):
	var sidebar_x = win_size.x * 0.75
	var sidebar_y = win_size.y * 0.05
	var line_height = 24.0
	var font = ThemeDB.fallback_font
	var font_size = 14

	# 1. 绘制背景
	draw_rect(Rect2(sidebar_x - 10, 0, win_size.x - sidebar_x + 10, win_size.y), Color(0.1, 0.1, 0.1, 0.8))

	# 2. 绘制标题
	draw_string(font, Vector2(sidebar_x, sidebar_y), "生成状态报告", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size + 2, Color.YELLOW)

	# 3. 绘制当前 Luck 值 (这里是新增内容)
	# 使用当前生成时保存的 luck 变量
	var luck_color = Color.AQUAMARINE if luck > 0.5 else Color.LIGHT_CORAL
	var luck_text = "当前幸运值: %.2f (影响权重指数)" % luck
	draw_string(font, Vector2(sidebar_x, sidebar_y + 30), luck_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, luck_color)

	# 4. 绘制列表分割线
	draw_line(Vector2(sidebar_x, sidebar_y + 45), Vector2(win_size.x - 20, sidebar_y + 45), Color.DARK_GRAY, 1.0)

	# 5. 绘制物品清单 (向下平移，给 Luck 腾出位置)
	var list_start_y = sidebar_y + 70
	draw_string(font, Vector2(sidebar_x, list_start_y), "物品清单 (最近 30 项):", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size - 2, Color.GRAY)

	var start_idx = max(0, draw_index - 30)
	for i in range(start_idx, draw_index):
		var item = current_loot[i].res
		var display_y = list_start_y + 25 + (i - start_idx) * line_height
		var color = _get_rarity_color(item.rarity)

		# 格式化输出：[品质] 名称 | 价格
		var text = "[R%d] %-8s | ¥%.0f" % [item.rarity, item.item_name, item.base_value]
		draw_string(font, Vector2(sidebar_x, display_y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)

func _get_rarity_color(r: int) -> Color:
	match r:
		0: return Color(0.5, 0.5, 0.5) # 灰色
		1: return Color(0.2, 0.8, 0.2) # 绿色
		2: return Color(0.2, 0.5, 1.0) # 蓝色
		3: return Color(0.7, 0.3, 1.0) # 紫色
		4: return Color(1.0, 0.7, 0.0) # 橙色
		5: return Color(1.0, 0.2, 0.2) # 红色
	return Color.WHITE