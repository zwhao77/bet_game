@tool
extends EditorScript

func _run():
	var csv_path = "res://items.csv"
	var save_dir = "res://resources/items/"

	# 修复点 1: 使用 _absolute 后缀的静态方法
	if not DirAccess.dir_exists_absolute(save_dir):
		DirAccess.make_dir_recursive_absolute(save_dir)

	# 修复点 2: FileAccess 也要确保使用正确的静态打开方式
	if not FileAccess.file_exists(csv_path):
		printerr("找不到 CSV 文件！")
		return

	var file = FileAccess.open(csv_path, FileAccess.READ)
	file.get_line() # 跳过表头

	while file.get_position() < file.get_length():
		var d = file.get_csv_line()
		if d.size() < 7: continue

		var item = ItemResource.new()
		item.id = d[0]
		item.item_name = d[1]
		item.width = d[2].to_int()
		item.height = d[3].to_int()
		item.rarity = d[4].to_int()
		item.base_value = d[5].to_float()
		item.weight = d[6].to_int()

		ResourceSaver.save(item, save_dir + item.id + ".tres")
	print("数据导入完成！")