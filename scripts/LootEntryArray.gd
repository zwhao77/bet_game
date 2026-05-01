extends Node
class_name LootEntryArray

# 使用下划线前缀表示这是内部私有数据，不建议外部直接访问
var _iter_ptr: int = 0
var _entries: Array[LootEntry] = []
var _grid_dim: Vector2i = Vector2i.ZERO
var _grid_map: Array = []

func _init(p_entries: Array[LootEntry], p_grid_dim: Vector2i) -> void:
	self._entries = p_entries
	self._grid_dim = p_grid_dim
	_init_grid_map()
	_build_spatial_mapping()

# --- 空间映射逻辑 (保持不变) ---
func _init_grid_map() -> void:
	_grid_map.clear()
	for i in range(_grid_dim.x):
		var col = []
		col.resize(_grid_dim.y)
		col.fill(null)
		_grid_map.append(col)

func _build_spatial_mapping() -> void:
	for entry in _entries:
		if not entry or not entry.res: continue
		var item = entry.res
		for i in range(item.width):
			for j in range(item.height):
				var tx = entry.pos.x + i
				var ty = entry.pos.y + j
				if _is_within_bounds(tx, ty):
					_grid_map[tx][ty] = entry

# --- 迭代器接口实现 ---

## 使该对象支持 for 循环：for entry in LootEntryArray


## 1. 初始化迭代：重置状态并判断是否可以直接开始
func _iter_init(_arg) -> bool:
	_iter_ptr = 0 # 核心：每次循环启动前重置指针
	return _iter_ptr < _entries.size()

## 2. 获取数据：返回当前指针指向的内容
func _iter_get(_arg):
	return _entries[_iter_ptr]

## 3. 步进迭代：指针后移，并判断是否还有下一项
func _iter_next(_arg) -> bool:
	_iter_ptr += 1
	return _iter_ptr < _entries.size()

## 类似 Rust 的闭包迭代器
func for_each(action: Callable) -> void:
	for entry in _entries:
		action.call(entry)

# --- 只读查询接口 ---

func get_entry_at(pos: Vector2i) -> LootEntry:
	if not _is_within_bounds(pos.x, pos.y): return null
	return _grid_map[pos.x][pos.y]

func get_size() -> Vector2i:
	return _grid_dim

func is_empty() -> bool:
	return _entries.is_empty()

# --- 辅助工具 ---

func _is_within_bounds(x: int, y: int) -> bool:
	return x >= 0 and x < _grid_dim.x and y >= 0 and y < _grid_dim.y

func _sort_entrys_by_pos() -> void:
	_entries.sort_custom(LootEntry.compare_by_pos)