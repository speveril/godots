extends VBoxContainer

@onready var head_button:Button = %HeadButton
@onready var hideable:Container = %Indenter
@onready var subsections:Container = %SubSections
@onready var contents:Container = %Contents

var path:String:
	set(x):
		path = x
		if head_button != null:
			head_button.text = x
var is_root:bool = false:
	set(x):
		is_root = x
		fix_is_root()

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
	fix_is_root()
	fix_hideable()
	head_button.text = path
	head_button.pressed.connect(_on_pressed_head_button)

func fix_is_root() -> void:
	if !is_node_ready():
		return
	if is_root:
		head_button.hide()
		hideable.visible = true
		$ColorRect.hide()
		$Indenter/ColorRect.hide()
		$Indenter/Spacer.hide()
	else:
		head_button.show()
		fix_hideable()
		$ColorRect.show()
		$Indenter/ColorRect.show()
		$Indenter/Spacer.show()

func fix_hideable() -> void:
	if !is_node_ready():
		return
	if is_root:
		return

	if _open:
		head_button.icon = get_theme_icon("GuiTreeArrowDown", "EditorIcons")
	else:
		head_button.icon = get_theme_icon("GuiTreeArrowRight", "EditorIcons")
	hideable.visible = _open

func is_empty() -> bool:
	if path == "/":
		return false
	return subsections.get_child_count() + contents.get_child_count() == 0

func add_subsection(n:Node):
	subsections.add_child(n)

func update_visibility():
	print("[uv ", path, "]")
	var should_be_visible = false
	var hideable_visible = hideable.visible
	hideable.show()

	if path == "/":
		visible = true
	if subsections.get_child_count() > 0:
		print("[uv ", path, "]", "subsections of ", path, ": ", get_subsections())
		for subsection in get_subsections():
			subsection.update_visibility()
			print("[uv ", path, "]", " -> ", subsection, " ", subsection.visible)
			should_be_visible = should_be_visible or subsection.visible
		print("[uv ", path, "]", "children of ", path, ": ", get_subsections())
	if contents.get_child_count() > 0:
		for item in get_items():
			print("[uv ", path, "]", " -> ", item, " ", item.visible)
			should_be_visible = should_be_visible or item.visible
	print("[uv ", path, "]", path, " => ", should_be_visible)

	visible = should_be_visible
	hideable.visible = hideable_visible

func add_item(n:Node):
	if n.get_parent() != null:
		n.reparent(contents)
	else:
		contents.add_child(n)

func get_subsections() -> Array[Node]:
	return subsections.get_children()

func get_items() -> Array[Node]:
	return contents.get_children()

func _on_pressed_head_button():
	open = !open
