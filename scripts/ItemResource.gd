# ItemResource.gd
extends Resource
class_name ItemResource

@export_group("Identity")
@export var id: String = ""
@export var item_name: String = ""

@export_group("Physics")
@export_range(1, 5) var width: int = 1
@export_range(1, 5) var height: int = 1

@export_group("Economy")
@export_enum("COMMON", "UNCOMMON", "RARE", "EPIC", "LEGENDARY", "MYTHIC") var rarity: int = 0
@export var base_value: float = 100.0
@export var weight: int = 100 # 在同品质内的抽取权重