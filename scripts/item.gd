extends Control

# --- 信号 ---
signal arrival_finished
signal selection_changed(node: Control, is_selected: bool)

# --- 状态与引用 ---
var item_data: ItemResource = null
var is_selected: bool = false
var is_loading: bool = false
var active_tween: Tween = null
var current_grid_size: float = 32.0

@onready var marquee: ColorRect = $MarqueeBorder
@onready var content: Control = $Content
@onready var background: ColorRect = $Content/Background
@onready var label: Label = $Content/InfoVBox/Label

func _ready() -> void:
	# 移除了代码设置 pivot_offset，交由面板的 pivot_offset_ratio 自动处理 [cite: 1]
	modulate.a = 1
	content.scale = Vector2.ZERO
	content.modulate.a = 0.0
	marquee.hide()

## 外部接口：注入数据。animate 参数决定是否播放掉落动画
func setup(data: ItemResource, grid_size: float = 32.0, animate: bool = true) -> void:
	item_data = data
	current_grid_size = grid_size

	# 同步更新基础尺寸和颜色
	update_size(grid_size)
	background.color = _get_rarity_color(data.rarity)
	label.text = "%s" % [data.item_name]

	if animate:
		await _play_arrival_sequence()
	else:
		apply_visual_instantly()

func update_size(grid_size: float) -> void:
	if not item_data: return
	current_grid_size = grid_size

	var target_size = Vector2(item_data.width, item_data.height) * grid_size

	# 修复警告：如果根节点有锚点限制，手动设置 size 会被覆盖
	# 方案 A：确保根节点 Anchors 为 Top/Left，且使用 custom_minimum_size 撑开
	custom_minimum_size = target_size
	# 使用 set_deferred 确保在下一帧闲时更新 size，避开布局冲突
	set_deferred("size", target_size)

	# 内部 Content 节点通常我们希望它跟随机体缩放
	if content:
		content.custom_minimum_size = target_size
		content.set_deferred("size", target_size)

	if background:
		background.set_deferred("size", target_size)

	if marquee.material:
		marquee.material.set_shader_parameter("rect_size", target_size)

	# 跑马灯修复：直接对齐到父节点边缘，无需手动设 size，这样它会跟随父节点缩放
	marquee.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# 确保 offset 为 0 以实现完美对齐
	marquee.offset_left = 0
	marquee.offset_top = 0
	marquee.offset_right = 0
	marquee.offset_bottom = 0

	#var dynamic_font_size = max(4, int(grid_size * 0.3))
	#label.add_theme_font_size_override("font_size", dynamic_font_size)

func skip_animation() -> void:
	if not is_loading: return
	is_loading = false
	if active_tween and active_tween.is_valid():
		active_tween.kill()
	_finish_instantly()
## 强制瞬间完成所有视觉表现，取消正在播放的动画
func apply_visual_instantly() -> void:
	is_loading = false

	# 彻底杀掉可能的 Tween，防止属性被动画逻辑覆盖
	if active_tween and active_tween.is_valid():
		active_tween.kill()

	# 强制设置最终视觉属性
	modulate.a = 1.0
	content.scale = Vector2.ONE
	content.modulate.a = 1.0

	if is_selected:
		marquee.show()
		marquee.modulate.a = 1.0
		content.scale = Vector2(1.05, 1.05)
	else:
		marquee.modulate.a = 0.0
		marquee.hide()

	arrival_finished.emit()
func _play_arrival_sequence() -> void:
	is_loading = true

	marquee.modulate.a = 1.0
	modulate.a = 1.0
	marquee.show()
	content.modulate.a = 0.0

	await get_tree().process_frame

	var wait_time = item_data.rarity * 0.2 + 0.1
	while wait_time > 0 and is_loading:
		wait_time -= get_process_delta_time()
		await get_tree().process_frame

	if not is_loading:
		_finish_instantly()
		return

	content.scale = Vector2(0.4, 0.4)
	content.modulate.a = 0.0

	active_tween = create_tween().set_parallel(true)
	active_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	active_tween.tween_property(content, "modulate:a", 1.0, 0.3)
	active_tween.tween_property(content, "scale", Vector2.ONE, 0.3)
	active_tween.tween_property(marquee, "modulate:a", 0.0, 0.25)

	await active_tween.finished

	if not is_selected:
		marquee.hide()
	is_loading = false
	arrival_finished.emit()

func _finish_instantly() -> void:
	modulate.a = 1.0
	content.scale = Vector2.ONE
	content.modulate.a = 1.0
	if not is_selected:
		marquee.modulate.a = 0.0
		marquee.hide()
	is_loading = false
	arrival_finished.emit()

func _get_rarity_color(r: int) -> Color:
	var colors = [Color("4a404a"), Color("2ecc71"), Color("3498db"), Color("9b59b6"), Color("f1c40f"), Color("e74c3c")]
	return colors[clamp(r, 0, colors.size() - 1)]

func _gui_input(event: InputEvent) -> void:
	if is_loading: return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		set_selected(!is_selected)

func set_selected(value: bool) -> void:
	is_selected = value
	var tw = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if is_selected:
		marquee.show()
		marquee.modulate.a = 1.0
		tw.tween_property(content, "scale", Vector2(1.05, 1.05), 0.2)
	else:
		tw.tween_property(marquee, "modulate:a", 0.0, 0.2).finished.connect(func(): if not is_selected: marquee.hide())
		tw.tween_property(content, "scale", Vector2.ONE, 0.2)
	selection_changed.emit(self , is_selected)
