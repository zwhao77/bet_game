# ItemDatabase.gd
extends Resource
class_name ItemDatabase

# 强引用所有道具，确保导出时 Godot 知道这些 .tres 文件是有用的
@export var all_items: Array[ItemResource] = []