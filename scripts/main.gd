extends Node2D # 这里必须匹配节点类型

@onready var loot_generator = $Generator
# 这里的路径一定要根据你场景面板里的实际结构来写
@onready var loot_display = $CanvasLayer/HBoxContainer/LootGridContainer
@onready var message_log = $CanvasLayer/HBoxContainer/VBoxContainer/MessageLog
@onready var label = $CanvasLayer/HBoxContainer/VBoxContainer/Label
var grid_dim = Vector2i(15, 30)
var total_value = 0

func _ready() -> void:
	if loot_display == null:
		push_error("错误：找不到 LootGridContainer 节点，请检查路径和场景树结构！")
		return
	_do_generate()
	loot_display.item_processed.connect(_on_item_revealed)

func _do_generate() -> void:
	var luck = randf() * 2 - 1
	var budget = 1000000.0
	message_log.clear()
	label.text = ""
	total_value = 0

	# 生成数据模型
	var entries = loot_generator.generate_loot(luck, budget, grid_dim, {}, {}, 0.05)

	# 喂给 UI 容器
	loot_display.display_loot(entries, grid_dim)

func _on_item_revealed(data: ItemResource) -> void:
	total_value += data.base_value

	# 打印一行带有格式的消息
	# [b] 是加粗，[color] 可以根据稀有度自定义
	var color_hex = _get_rarity_color_hex(data.rarity)
	var msg = "[color=%s][+][/color] 获得 [b]%s[/b] - 价值: [color=yellow]$%.2f[/color]\n" % [
		color_hex,
		data.item_name,
		data.base_value
	]

	message_log.append_text(msg)
	label.text = "$%.2f" % total_value
	# 可选：更新标题或单独的 Label 显示总价值
	# print("当前累计总价值: ", total_value)
func _get_rarity_color_hex(rarity: int) -> String:
	var colors = ["#aaaaaa", "#2ecc71", "#3498db", "#9b59b6", "#f1c40f", "#e74c3c"]
	return colors[clamp(rarity, 0, colors.size() - 1)]

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		_do_generate()
