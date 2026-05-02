# --- loot_grid.gd ---
extends Control

const ITEM_SCENE = preload("res://scenes/item.tscn")

var current_loot_data: LootEntryArray = null
var grid_dim = Vector2i(15, 30)
var tile_size: int = 0
var is_animating: bool = false
signal item_processed(data: ItemResource)
# 滑动选择相关
signal sweep_state_changed(sweeping: bool, target_state: bool)
var sweep_pending: bool = false # 等待第一个选中信号
var sweep_active: bool = false # 滑动模式已激活
var sweep_target_state: bool = false # 所有物划物品的目标选中状态
var shift_held: bool = false
var mouse_held: bool = false
var _entry_to_ui_map: Dictionary = {} # { LootEntry: ItemUI }
@onready var scroll_container: ScrollContainer = $ScrollContainer
@onready var item_layer: Control = $ScrollContainer/ItemSlotLayer

func _ready() -> void:
	item_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scroll_container.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	resized.connect(_on_self_resized)

func display_loot(loot_entries: LootEntryArray, dimension: Vector2i) -> void:
	current_loot_data = loot_entries
	grid_dim = dimension
	is_animating = true

	# 清理
	for child in item_layer.get_children():
		child.queue_free()
	scroll_container.scroll_vertical = 0

	_refresh_layout()
	_spawn_sequence()

func _refresh_layout() -> void:
	var my_usable_size = size
	if grid_dim.x <= 0: return

	tile_size = int(floor(my_usable_size.x / grid_dim.x))
	var grid_pixel_size = Vector2(grid_dim) * tile_size
	item_layer.custom_minimum_size = grid_pixel_size
	item_layer.size = grid_pixel_size

func _place_item(entry: LootEntry, display_mode: ItemUI.DisplayMode = ItemUI.DisplayMode.FULL_ITEM) -> ItemUI:
	var item_ui = ITEM_SCENE.instantiate() as ItemUI
	# [核心修改]：在 add_child 前注入数据，触发内建物理适配
	item_ui.init_item(entry, float(tile_size), display_mode)
	item_layer.add_child(item_ui)
	item_ui.position = Vector2(entry.pos) * tile_size
	item_ui.arrival_finished.connect(_on_item_revealed)
	item_ui.selection_changed.connect(_on_item_selected_changed)
	sweep_state_changed.connect(item_ui._on_sweep)
	_entry_to_ui_map[entry] = item_ui
	return item_ui
func _start_item(item_ui: ItemUI) -> void:
	if is_animating:
			# 启动物品内部的揭晓动画
			await item_ui.start_reveal()
			_auto_scroll_to_item(item_ui)
			# 控制流式揭晓的速度，0.05 - 0.1 视觉效果最佳
			await get_tree().create_timer(0.08).timeout
	else:
		item_ui.apply_visual_instantly()
func _start_all(item_uis: Array[ItemUI]) -> void:
	item_uis.sort_custom(ItemUI.compare_by_entry_pos)
	for item_ui in item_uis:
		await _start_item(item_ui)
func _place_all() -> Array[ItemUI]:
	var spawned_nodes: Array[ItemUI] = []
	for entry in current_loot_data:
		spawned_nodes.append(_place_item(entry))
	return spawned_nodes
func _spawn_sequence() -> void:
	var spawned_nodes: Array[ItemUI] = _place_all()
	await get_tree().process_frame
	await _start_all(spawned_nodes)
	is_animating = false
func _on_item_revealed(item: ItemUI) -> void:
	item_processed.emit(item.item_data)
func _on_item_selected_changed(item: ItemUI, is_selected: bool) -> void:
	print("选中状态改变: ", item.item_data.item_name, " 选中: ", is_selected)
	if sweep_pending:
		# 从等待滑动状态进入滑动模式
		sweep_pending = false
		sweep_active = true
		sweep_target_state = is_selected
		sweep_state_changed.emit(true, sweep_target_state)
		print("滑动选择已激活，目标选中状态: ", sweep_target_state)
func _auto_scroll_to_item(item_node: Control) -> void:
	var item_bottom = item_node.position.y + item_node.size.y
	var visible_bottom = scroll_container.scroll_vertical + scroll_container.size.y

	if item_bottom > visible_bottom:
		var target_v = item_bottom - scroll_container.size.y + 20
		var tween = create_tween()
		tween.tween_property(scroll_container, "scroll_vertical", int(target_v), 0.15)

func skip_animating() -> void:
	is_animating = false
	for item_ui in item_layer.get_children():
		if item_ui is ItemUI:
			item_ui.apply_visual_instantly()

func _on_self_resized() -> void:
	_refresh_layout() # 假设这里更新了所有 entry 的 pos 坐标
	# 直接遍历所有子节点，每个节点自己知道该去哪
	for item_ui in item_layer.get_children():
		if item_ui is ItemUI:
			var entry = item_ui.item_entry
			if entry:
				# 1. 使用 entry 内部存储的最新坐标
				# 2. Vector2i * int 是合法的，会自动转换为 Vector2
				item_ui.position = entry.pos * tile_size
				# 3. 这里的 tile_size 如果是 int，转为 float 传参更严谨
				item_ui.update_size(float(tile_size))

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		skip_animating()
		var grid_pos = get_grid_pos_at_mouse()
		print("鼠标点击网格坐标: ", grid_pos)
		var entry_under_mouse = current_loot_data.get_entry_at(grid_pos)
		if entry_under_mouse:
			print("点击了物品: ", entry_under_mouse.res.item_name)
		else:
			print("点击了空格子")
func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.keycode == KEY_SHIFT:
		shift_held = event.pressed
		_update_sweep_state()
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		mouse_held = event.pressed
		_update_sweep_state()

func _update_sweep_state() -> void:
	if shift_held and mouse_held:
		if not sweep_active and not sweep_pending:
			# 进入等待滑动状态
			sweep_pending = true
			print("滑动选择准备中...等待第一个选中信号")
	elif (not shift_held or not mouse_held) and (sweep_pending or sweep_active):
		# 退出所有滑动状态
		_end_sweep()
func _end_sweep() -> void:
	if not sweep_pending and not sweep_active:
		return
	sweep_pending = false
	sweep_active = false
	sweep_target_state = false
	# 通知所有子节点结束滑动模式
	sweep_state_changed.emit(false, false)
	print("滑动选择结束")

	## 将屏幕/像素坐标转换为网格坐标
func get_grid_pos_at_mouse() -> Vector2i:
	# 获取鼠标相对于 item_layer 左上角的像素位置
	# 这会自动处理 ScrollContainer 的滚动偏移
	var local_mouse_pos = item_layer.get_local_mouse_position()

	# 转换为网格坐标
	var gx = int(floor(local_mouse_pos.x / tile_size))
	var gy = int(floor(local_mouse_pos.y / tile_size))

	return Vector2i(gx, gy)