# import_items.gd
@tool
extends EditorScript

func _run():
    var csv_path = "res://items.csv"
    var save_dir = "res://resources/items/"
    var db_path = "res://resources/ItemDatabase.tres"

    # 1. 确保目录存在
    if not DirAccess.dir_exists_absolute(save_dir):
        DirAccess.make_dir_recursive_absolute(save_dir)

    if not FileAccess.file_exists(csv_path):
        printerr("找不到 CSV 文件：", csv_path)
        return

    # 2. 获取或创建数据库实例
    var db: ItemDatabase
    if ResourceLoader.exists(db_path):
        db = load(db_path)
    else:
        db = ItemDatabase.new()

    db.all_items.clear() # 清空旧数据准备覆盖更新

    # 3. 解析 CSV
    var file = FileAccess.open(csv_path, FileAccess.READ)
    file.get_line() # 跳过表头

    while file.get_position() < file.get_length():
        var d = file.get_csv_line()
        if d.size() < 7: continue

        var item = ItemResource.new()
        item.id = d[0].strip_edges()
        item.item_name = d[1]
        item.width = d[2].to_int()
        item.height = d[3].to_int()
        item.rarity = d[4].to_int()
        item.base_value = d[5].to_float()
        item.weight = d[6].to_int()

        var res_path = save_dir.path_join(item.id + ".tres")

        # 保存单个资源
        ResourceSaver.save(item, res_path)

        # 将磁盘上的资源重新加载并存入数据库数组（建立强引用链）
        var saved_res = load(res_path)
        if saved_res:
            db.all_items.append(saved_res)

    # 4. 保存数据库索引
    var error = ResourceSaver.save(db, db_path)
    if error == OK:
        print("✅ 导入成功！共生成 ", db.all_items.size(), " 个资源并已更新数据库。")
    else:
        printerr("❌ 数据库保存失败，错误码：", error)