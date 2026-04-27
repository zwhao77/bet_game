extends Control

const ITEM_SCENE = preload("res://scenes/item.tscn")

var current_loot_data: Array[LootEntry] = []
var grid_dim = Vector2i(15, 30)
var tile_size: int = 0
var is_animating: bool = false
signal item_processed(data: ItemResource)

# 确保路径指向新的 ScrollContainer 内部
@onready var scroll_container: ScrollContainer = $ScrollContainer
@onready var item_layer: Control = $ScrollContainer/ItemSlotLayer

func _ready() -> void:
	# 基础配置
	item_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# 禁用横向滚动，只保留纵向
	scroll_container.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll_container.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO

	resized.connect(_on_self_resized)

func display_loot(loot_entries: Array, dimension: Vector2i) -> void:
	if is_animating:
		skip_animations()

	current_loot_data = loot_entries
	grid_dim = dimension
	is_animating = true

	# 清理旧物品
	for child in item_layer.get_children():
		child.queue_free()

	# 重置滚动条位置到顶部
	scroll_container.scroll_vertical = 0

	_refresh_layout()
	_spawn_sequence()

func _refresh_layout() -> void:
	# 此时 size 是外部 LootGridContainer 的大小
	var my_usable_size = size
	if grid_dim.x <= 0 or my_usable_size.x <= 0: return

	# --- 关键改变：仅根据宽度计算大小 ---
	tile_size = int(floor(my_usable_size.x / grid_dim.x))

	# 计算网格实际像素尺寸
	var grid_pixel_size = Vector2(grid_dim) * tile_size

	# --- 关键改变：撑开滚动条 ---
	# 必须设置最小尺寸，ScrollContainer 才会知道内容有多大
	item_layer.custom_minimum_size = grid_pixel_size
	item_layer.size = grid_pixel_size

	# 水平居中，垂直靠顶
	item_layer.position.x = (my_usable_size.x - grid_pixel_size.x) / 2.0
	item_layer.position.y = 0

func _spawn_sequence() -> void:
	var spawned_items = []
	for entry in current_loot_data:
		var item_ui = ITEM_SCENE.instantiate()
		item_layer.add_child(item_ui)

		item_ui.position = Vector2(entry.pos) * tile_size
		if item_ui.has_method("update_size"):
			item_ui.update_size(float(tile_size))

		spawned_items.append({"node": item_ui, "data": entry})

	for item_info in spawned_items:
		var item_ui = item_info.node
		if item_ui.has_method("setup"):
			await item_ui.setup(item_info.data.res, float(tile_size), is_animating)

		# 信号发射
		item_processed.emit(item_info.data.res)

		# 可选：生成时自动跟随滚动
		_auto_scroll_to_item(item_ui)

		if is_animating:
			await get_tree().create_timer(0.05).timeout

	is_animating = false

# 辅助函数：让滚动条跟随新生成的物品
func _auto_scroll_to_item(item_node: Control) -> void:
	var item_bottom = item_node.position.y + (item_node.size.y if "size" in item_node else float(tile_size))
	var visible_bottom = scroll_container.scroll_vertical + scroll_container.size.y

	if item_bottom > visible_bottom:
		var target_v = item_bottom - scroll_container.size.y + 20 # 留点余量
		# 使用 Tween 实现平滑滚动
		var tween = create_tween()
		tween.tween_property(scroll_container, "scroll_vertical", int(target_v), 0.1)

func _on_self_resized() -> void:
	if is_animating:
		skip_animations()

	_refresh_layout()

	for i in range(item_layer.get_child_count()):
		var item_ui = item_layer.get_child(i)
		if i < current_loot_data.size():
			var entry = current_loot_data[i]
			item_ui.position = Vector2(entry.pos) * tile_size
		if item_ui.has_method("update_size"):
			item_ui.update_size(float(tile_size))

func skip_animations() -> void:
	is_animating = false
