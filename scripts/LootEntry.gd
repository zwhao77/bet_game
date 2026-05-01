# LootEntry.gd
extends RefCounted # 建议继承 RefCounted，这样它会自动管理内存，无需手动 queue_free
class_name LootEntry

var res: ItemResource
var pos: Vector2i

# 构造函数，方便通过 LootEntry.new(res, pos) 快速创建
func _init(_res: ItemResource = null, _pos: Vector2i = Vector2i.ZERO):
	self.res = _res
	self.pos = _pos
static func compare_by_pos(a: LootEntry, b: LootEntry) -> bool:
	if not a: return false
	if not b: return true # 将 null 排在最后
	if a.pos.y != b.pos.y:
		return a.pos.y < b.pos.y
	return a.pos.x < b.pos.x