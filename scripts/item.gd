extends Control
class_name ItemUI
# --- 信号 ---
signal arrival_finished
signal selection_changed(node: Control, is_selected: bool)

# --- 状态与引用 ---
var item_data: ItemResource = null
var is_selected: bool = false
var is_loading: bool = false
var active_tween: Tween = null
var current_grid_size: float = 32.0

# 预加载缓冲变量
var item_entry: LootEntry = null
var _pending_grid_size: float = 32.0

@onready var marquee: ColorRect = $MarqueeBorder
@onready var content: Control = $Content
@onready var background: ColorRect = $Content/Background
@onready var label: Label = $Content/InfoVBox/Label
@onready var static_border: Panel = $Content/StaticBorder # 请确保场景中有此节点
@onready var selection_frame: Panel = $Content/SelectionBorder
func _ready() -> void:
	# 1. 初始隐藏动态内容
	content.modulate.a = 1.0
	content.scale = Vector2.ONE
	marquee.hide()

	# 2. 如果在 add_child 之前已经注入了数据，立即执行物理设置
	if item_entry:
		_apply_pre_visuals(item_entry.res, _pending_grid_size)
	#mouse_entered.connect(_on_mouse_entered)

## 外部接口：在 instantiate 之后，add_child 之前调用，确保 _ready 时已有数据
func init_item(entry: LootEntry, grid_size: float = 32.0) -> void:
	item_entry = entry
	_pending_grid_size = grid_size

## 物理层面初始化：设置尺寸、Shader参数和占位底色
func _apply_pre_visuals(data: ItemResource, grid_size: float) -> void:
	item_data = data
	current_grid_size = grid_size

	# 立即更新尺寸（Shader 依赖此参数）
	update_size(grid_size)

	# 占位视觉：灰色背景，隐藏文字，显示常驻边框
	background.color = Color("2d2d2d")
	label.text = ""

	if static_border:
		static_border.show()
		static_border.modulate.a = 0.7 # 淡淡的常驻轮廓

func start_reveal() -> void:
	update_size(current_grid_size)
	if not item_data: return
	is_loading = true

	label.text = item_data.item_name
	var target_color = _get_rarity_color(item_data.rarity)
	var warm_up_time = 0.4 + (item_data.rarity * 0.2)

	if active_tween and active_tween.is_valid():
		active_tween.kill()

	# --- 阶段 1：纯串行等待 ---
	# 这个 Tween 只负责把跑马灯亮起来并等待
	marquee.modulate.a = 1.0
	marquee.show()

	# 使用 await 强制程序在这里停住，直到等待时间结束
	# 这样可以确保阶段 2 的并行逻辑绝对不会提前触发
	await get_tree().create_timer(warm_up_time).timeout
	# --- 阶段 2：纯并行揭晓 ---
	# 时间到，启动第二个 Tween，这次我们直接开启并行模式
	content.scale = Vector2(0.9, 0.9)
	active_tween = create_tween().set_parallel(true)
	active_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	active_tween.tween_property(background, "color", target_color, 0.1)
	active_tween.tween_property(content, "modulate:a", 1.0, 0.1)

	# 瞬间从 0.9 缩放到 1.0
	active_tween.tween_property(content, "scale", Vector2.ONE, 0.2)

	marquee.hide()

	await active_tween.finished

	is_loading = false
	arrival_finished.emit()

func update_size(grid_size: float) -> void:
	if not item_data: return
	current_grid_size = grid_size
	var target_size = Vector2(item_data.width, item_data.height) * grid_size

	# 1. 物理布局更新
	custom_minimum_size = target_size
	set_deferred("size", target_size)

	# 2. 同步 Shader 参数
	if marquee.material:
		# marquee 必须是一个 CanvasItem (如 ColorRect/Sprite2D)
		marquee.set_instance_shader_parameter("rect_size", target_size)

	# 3. 动态计算字体大小（已修复 float 报错）
	var calculated_font_size = int(grid_size / 4)
	label.add_theme_font_size_override("font_size", calculated_font_size)

	# 4. 【新增】为 Label 设置动态边距
	# 我们可以基于 grid_size 的比例来设置边距，例如边距为网格大小的 10%
	var margin_value = int(grid_size * 0.1)

	# 获取现有的 StyleBox（如果没有则创建一个新的 StyleBoxFlat）
	var sb = label.get_theme_stylebox("normal").duplicate()
	if not sb is StyleBox:
		sb = StyleBoxFlat.new()
		sb.bg_color = Color(0, 0, 0, 0) # 设为透明背景

	# 设置内边距
	sb.content_margin_left = margin_value
	sb.content_margin_top = margin_value
	sb.content_margin_right = margin_value
	sb.content_margin_bottom = margin_value

	# 应用覆盖
	label.add_theme_stylebox_override("normal", sb)


func apply_visual_instantly() -> void:
	is_loading = false
	if active_tween and active_tween.is_valid():
		active_tween.kill()

	background.color = _get_rarity_color(item_data.rarity)
	label.text = item_data.item_name
	content.scale = Vector2.ONE
	content.modulate.a = 1.0
	marquee.hide()

	arrival_finished.emit()

func set_selected(value: bool) -> void:
	if is_selected == value: return # 避免重复触发逻辑
	is_selected = value
	if is_selected:
		selection_frame.show()
		# 如果想要一点动感，可以用简短的缩放
		#content.scale = Vector2(0.95, 0.95)
	else:
		selection_frame.hide()
		#content.scale = Vector2.ONE
	selection_changed.emit(self , is_selected)

func _get_rarity_color(r: int) -> Color:
	var colors = [Color("4a404a"), Color("2ecc71"), Color("3498db"), Color("9b59b6"), Color("f1c40f"), Color("e74c3c")]
	return colors[clamp(r, 0, colors.size() - 1)]

func _gui_input(event: InputEvent) -> void:
	if is_loading: return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		set_selected(!is_selected)
		if is_selected: print("选中了", item_data.item_name)
		else: print("取消选中了", item_data.item_name)
func _on_mouse_entered() -> void:
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		set_selected(!is_selected)
