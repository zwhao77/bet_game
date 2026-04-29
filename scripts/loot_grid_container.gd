# --- loot_grid.gd ---
extends Control

const ITEM_SCENE = preload("res://scenes/item.tscn")

var current_loot_data: Array = []
var grid_dim = Vector2i(15, 30)
var tile_size: int = 0
var is_animating: bool = false
signal item_processed(data: ItemResource)

@onready var scroll_container: ScrollContainer = $ScrollContainer
@onready var item_layer: Control = $ScrollContainer/ItemSlotLayer

func _ready() -> void:
	item_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scroll_container.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	resized.connect(_on_self_resized)

func display_loot(loot_entries: Array, dimension: Vector2i) -> void:
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

func _spawn_sequence() -> void:
	var spawned_nodes = []

	# 阶段 A：瞬间生成物理占位 (灰色框)
	for entry in current_loot_data:
		var item_ui = ITEM_SCENE.instantiate() as ItemUI

		# [核心修改]：在 add_child 前注入数据，触发内建物理适配
		item_ui.init_item(entry, float(tile_size))

		item_layer.add_child(item_ui)
		item_ui.position = Vector2(entry.pos) * tile_size
		spawned_nodes.append(item_ui)

	# 阶段 B：依次启动视觉揭晓
	for item_ui in spawned_nodes:
		if is_animating:
			# 启动物品内部的揭晓动画
			await item_ui.start_reveal()
			_auto_scroll_to_item(item_ui)
			# 控制流式揭晓的速度，0.05 - 0.1 视觉效果最佳
			await get_tree().create_timer(0.08).timeout
		else:
			item_ui.apply_visual_instantly()

		item_processed.emit(item_ui.item_data)

	is_animating = false

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
		item_ui.apply_visual_instantly()

func _on_self_resized() -> void:
	_refresh_layout() # 假设这里更新了所有 entry 的 pos 坐标
	# 直接遍历所有子节点，每个节点自己知道该去哪
	for item_ui in item_layer.get_children():
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
