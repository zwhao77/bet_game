extends Node

# --- 强类型数据容器 ---

## 掉落条目强类型包装
class LootEntry:
	var res: ItemResource
	var pos: Vector2i

	func _init(_res: ItemResource, _pos: Vector2i):
		self.res = _res
		self.pos = _pos

## 内部类：负责数据缓存与查询 (LootTable)
class LootTable:
	# buckets[rarity][width] = Array[ItemResource]
	var buckets: Dictionary = {}
	var r5_pool: Array[ItemResource] = []

	func _init(path: String):
		for i in range(6): buckets[i] = {}
		_load_from_disk(path)

	func _load_from_disk(path: String):
		var dir = DirAccess.open(path)
		if not dir:
			printerr("LootTable Error: 无法打开目录 ", path)
			return

		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if file_name.ends_with(".tres"):
				var res = load(path + file_name) as ItemResource
				if res:
					if not buckets[res.rarity].has(res.width):
						buckets[res.rarity][res.width] = []
					buckets[res.rarity][res.width].append(res)
					if res.rarity == 5: r5_pool.append(res)
			file_name = dir.get_next()
		print("LootTable: 内存桶构建完成。")

	## 核心查询：仅在指定品质内寻找，预算超支直接返回 null
	func pick_standard(r: int, w: int, budget: float) -> ItemResource:
		if not buckets.has(r): return null

		# 尝试从目标宽度 w 回退到 1，寻找当前品质下买得起的物品
		for check_w in range(w, 0, -1):
			if not buckets[r].has(check_w): continue

			var candidates = buckets[r][check_w]

			# 严格预算过滤
			if budget >= 0:
				candidates = candidates.filter(func(it): return it.base_value <= budget)

			if not candidates.is_empty():
				return candidates.pick_random()
		return null

	func find_r5_upgrade(base: ItemResource) -> ItemResource:
		var matches = r5_pool.filter(func(r5):
			return r5.width == base.width and r5.height == base.height
		)
		return matches.pick_random() if not matches.is_empty() else null

# --- Generator 主类变量 ---

var active_table: LootTable
var width_bag: Array[int] = []

# --- 外部接口 ---

func _ready():
	initialize_table("res://resources/items/")

func initialize_table(path: String):
	active_table = LootTable.new(path)

## 生成主入口
func generate_loot(
	luck: float,
	budget: float,
	grid_size: Vector2i,
	r_params: Dictionary,
	w_params: Dictionary,
	upgrade_prob: float,
	max_items: int = 999,
	max_cells: int = 9999
) -> Array[LootEntry]:
	if not active_table: return []

	# 1. 基础生成
	var sequence = _do_base_generation(luck, budget, grid_size, r_params, w_params, max_items, max_cells)

	# 2. R5 升阶
	_do_upgrade_pass(sequence, upgrade_prob)

	return sequence

# --- 拆分后的核心算法 ---

## 1. 基础生成主逻辑
func _do_base_generation(luck: float, budget: float, grid_size: Vector2i, r_params: Dictionary, w_params: Dictionary, max_items: int, max_cells: int) -> Array[LootEntry]:
	var seq: Array[LootEntry] = []
	var cur_val: float = 0.0
	var cur_cells: int = 0

	# 初始化网格
	var grid_mask = _init_grid_mask(grid_size)

	for y in range(grid_size.y):
		for x in range(grid_size.x):
			# 检查硬性停止条件
			if seq.size() >= max_items or cur_cells >= max_cells:
				return seq

			if grid_mask[x][y]: continue # 跳过已占用的格子

			# --- 探测与决策 ---
			var mw = _probe_max_width(grid_mask, x, y, grid_size.x)
			var target_w = _get_next_width(mw, w_params)
			var target_r = _weighted_choice(luck, range(5), r_params)

			# --- 抽取与校验 ---
			var remaining_budget = budget - cur_val
			var item = active_table.pick_standard(target_r, target_w, remaining_budget)

			if item:
				# 检查格子数是否超限
				if cur_cells + (item.width * item.height) > max_cells:
					continue # 此处放不下则探测下一个空位

				# --- 放置物品 ---
				_apply_item_to_grid(grid_mask, x, y, item)
				seq.append(LootEntry.new(item, Vector2i(x, y)))

				# 更新累加器
				cur_val += item.base_value
				cur_cells += item.width * item.height

				# 预算超支立即返回
				if cur_val >= budget: return seq
			else:
				# 如果因为买不起该品质而失败，且当前已达到预算上限，则视为生成结束
				return seq

	return seq

## 2. 探测可用宽度
func _probe_max_width(mask: Array, x: int, y: int, max_x: int) -> int:
	var mw = 0
	for tx in range(x, max_x):
		if not mask[tx][y]: mw += 1
		else: break
	return min(mw, 5)

## 3. 应用物品到网格
func _apply_item_to_grid(mask: Array, start_x: int, start_y: int, item: ItemResource):
	for i in range(item.width):
		for j in range(item.height):
			var tx = start_x + i
			var ty = start_y + j
			if tx < mask.size() and ty < mask[0].size():
				mask[tx][ty] = true

## 4. 初始化网格遮罩
func _init_grid_mask(size: Vector2i) -> Array:
	var mask = []
	for i in range(size.x):
		var col = []
		col.resize(size.y)
		col.fill(false)
		mask.append(col)
	return mask

# --- 后置处理与工具 ---

func _do_upgrade_pass(sequence: Array[LootEntry], prob: float):
	for entry in sequence:
		if entry.res.rarity == 4 and randf() < prob:
			var r5 = active_table.find_r5_upgrade(entry.res)
			if r5: entry.res = r5

func _refill_width_bag(w_params: Dictionary):
	width_bag.clear()
	for w in range(1, 6):
		var k = w_params.get(w, 0.0)
		var count = int(max(1, 20 * exp(k * 0.5)))
		for i in range(count): width_bag.append(w)
	width_bag.shuffle()

func _get_next_width(mw: int, w_params: Dictionary) -> int:
	if width_bag.is_empty(): _refill_width_bag(w_params)
	for i in range(width_bag.size() - 1, -1, -1):
		if width_bag[i] <= mw: return width_bag.pop_at(i)
	return 1

func _weighted_choice(luck: float, options: Array, params: Dictionary) -> int:
	var total = 0.0
	var weights = []
	for opt in options:
		var k = params.get(opt, 0.0)
		var w = 100.0 * exp(k * luck)
		weights.append(w)
		total += w

	var roll = randf() * total
	var acc = 0.0
	for i in range(options.size()):
		acc += weights[i]
		if roll <= acc: return options[i]
	return options[0]