extends VBoxContainer

@onready var head_button:Button = %HeadButton
@onready var hideable:Container = %Indenter
@onready var sub_sections:Container = %SubSections
@onready var contents:Container = %Contents

var path:String:
	set(x):
		path = x
		if head_button != null:
			head_button.text = x
var is_root:bool = false:
	set(x):
		is_root = x
		fix_hideable()

var open:bool:
	set(x):
		_open = x
		var closed = Config.CLOSED_SECTIONS.ret()
		if _open:
			closed.erase(path)
		else:
			closed.append(path)
		Config.CLOSED_SECTIONS.put(closed)
		fix_hideable()
	get: return _open
var _open:bool

func _ready():
	_open = !Config.CLOSED_SECTIONS.ret().has(path)
	fix_hideable()
	head_button.text = path
	head_button.pressed.connect(_on_pressed_head_button)

func fix_hideable() -> void:
	if !is_node_ready():
		return
	if is_root:
		head_button.icon = null
		hideable.visible = true
		return
	if _open:
		head_button.icon = get_theme_icon("GuiTreeArrowDown", "EditorIcons")
	else:
		head_button.icon = get_theme_icon("GuiTreeArrowRight", "EditorIcons")
	hideable.visible = _open

func is_empty() -> bool:
	if path == "/":
		return false
	return sub_sections.get_child_count() + contents.get_child_count() == 0

func add_subsection(n:Node):
	sub_sections.add_child(n)

func add_item(n:Node):
	if n.get_parent() != null:
		n.reparent(contents)
	else:
		contents.add_child(n)

func get_subsections() -> Array[Node]:
	return sub_sections.get_children()

func get_items() -> Array[Node]:
	return contents.get_children()

func _on_pressed_head_button():
	open = !open
