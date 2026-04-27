extends Control

# --- 信号 ---
signal selection_changed(node: Control, is_selected: bool)

# --- 状态变量 ---
var item_data: ItemResource = null
var is_selected: bool = false
var is_loading: bool = true

# --- 节点引用 ---
@onready var marquee: ColorRect = $MarqueeBorder
@onready var content: Control = $Content
@onready var background: ColorRect = $Content/Background
@onready var icon: TextureRect = $Content/Icon
@onready var label: Label = $Content/Label # 确保场景中有这个节点

func _ready() -> void:
	# 初始状态：彻底静默
	modulate.a = 0.0
	content.scale = Vector2.ZERO
	marquee.hide()
	marquee.modulate.a = 0.0

# --- 外部接口 ---

## 注入数据并设置动态尺寸
func setup(data: ItemResource, grid_size: float = 64.0) -> void:
	item_data = data

	# 1. 根据格子数动态设置尺寸
	var target_size = Vector2(data.width, data.height) * grid_size
	size = target_size
	custom_minimum_size = target_size

	# 2. 强制刷新所有层级的尺寸和轴心 (防止缩放动画偏移)
	_update_layout_and_pivot()

	# 3. 填充 UI 内容
	background.color = _get_rarity_color(data.rarity)
	# 格式化显示：第一行名字，第二行价值 (带两位小数)
	label.text = "%s\n$%.2f" % [data.item_name, data.base_value]

	# 4. 将尺寸传给 Shader (解决长方形虚线变形和边缘细线)
	if marquee.material:
		marquee.material.set_shader_parameter("rect_size", target_size)

	# 5. 开启出现序列
	modulate.a = 1.0
	_play_arrival_sequence(target_size)

# --- 内部逻辑 ---

## 刷新布局逻辑
func _update_layout_and_pivot() -> void:
	# 设置轴心到正中心
	pivot_offset = size / 2.0
	content.size = size # 确保容器填满根节点
	content.pivot_offset = size / 2.0

	# 让跑马灯稍微外扩 1 像素，完美解决边缘细线问题
	marquee.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	marquee.offset_left = -1
	marquee.offset_top = -1
	marquee.offset_right = 1
	marquee.offset_bottom = 1

func _play_arrival_sequence(target_size: Vector2) -> void:
	is_loading = true

	# 1. 初始隐藏
	content.modulate.a = 0.0
	content.scale = Vector2.ZERO

	# 2. 跑马灯亮相
	marquee.show()
	var tw_mq_in = create_tween()
	tw_mq_in.tween_property(marquee, "modulate:a", 1.0, 0.2)

	# --- 关键改动：遵循文档建议 ---
	# 等待一帧，让容器完成对 Item 根节点尺寸(size)的重新排布
	await get_tree().process_frame

	# 现在尺寸已经稳定，重新计算并强行赋值轴心
	content.size = target_size
	content.pivot_offset = target_size / 2.0
	# --------------------------

	# 模拟加载延迟
	await get_tree().create_timer(randf_range(0.4, 0.8)).timeout

	is_loading = false

	# 再次确认轴心，防止在 timer 等待期间容器又动了布局
	content.pivot_offset = target_size / 2.0

	var tw = create_tween().set_parallel(true)
	tw.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	# 显式从 Vector2.ZERO 开始缩放
	tw.tween_property(content, "modulate:a", 1.0, 0.4)
	tw.tween_property(content, "scale", Vector2.ONE, 0.5)

	if not is_selected:
		var tw_mq_out = create_tween()
		tw_mq_out.tween_property(marquee, "modulate:a", 0.0, 0.3)
		await tw_mq_out.finished
		if not is_selected: marquee.hide()

func set_selected(value: bool) -> void:
	is_selected = value
	var tw = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	if is_selected:
		marquee.show()
		marquee.modulate.a = 1.0
		if marquee.material:
			marquee.material.set_shader_parameter("line_color", Color.WHITE)
		tw.tween_property(content, "scale", Vector2(1.05, 1.05), 0.2)
	else:
		tw.tween_property(marquee, "modulate:a", 0.0, 0.2)
		tw.tween_property(content, "scale", Vector2.ONE, 0.2)
		if marquee.material:
			marquee.material.set_shader_parameter("line_color", Color(1, 0.9, 0.2))

	selection_changed.emit(self , is_selected)

func _get_rarity_color(r: int) -> Color:
	match r:
		0: return Color("4a4a4a") # COMMON
		1: return Color("2ecc71") # UNCOMMON
		2: return Color("3498db") # RARE
		3: return Color("9b59b6") # EPIC
		4: return Color("f1c40f") # LEGENDARY
		5: return Color("e74c3c") # MYTHIC
	return Color.WHITE

func _gui_input(event: InputEvent) -> void:
	if is_loading: return
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			set_selected(!is_selected)
			accept_event()