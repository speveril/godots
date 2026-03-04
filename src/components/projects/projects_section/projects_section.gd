class_name ProjectSectionControl
extends VBoxContainer

@onready var head_button:Button = %HeadButton
@onready var hideable:Container = %Indenter
@onready var subsections:Container = %SubSections
@onready var contents:Container = %Contents

@onready var _indent_bg:ColorRect = %BgColor
@onready var _indent_spacer:Control = %Spacer

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
		var closed:Array[String] = []
		closed.assign(Config.CLOSED_SECTIONS.ret() as Array)
		if _open:
			closed.erase(path)
		else:
			closed.append(path)
		Config.CLOSED_SECTIONS.put(closed)
		fix_hideable()
	get: return _open
var _open:bool

func _ready() -> void:
	_open = !(Config.CLOSED_SECTIONS.ret() as Array[String]).has(path)
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
		_indent_bg.hide()
		_indent_spacer.hide()
	else:
		head_button.show()
		fix_hideable()
		_indent_bg.show()
		_indent_spacer.show()

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

func add_subsection(n:ProjectSectionControl) -> void:
	subsections.add_child(n)

func update_visibility() -> void:
	var should_be_visible := false
	var hideable_visible := hideable.visible
	hideable.show()

	if path == "/":
		visible = true
	if subsections.get_child_count() > 0:
		for subsection in get_subsections():
			subsection.update_visibility()
			should_be_visible = should_be_visible or subsection.visible
	if contents.get_child_count() > 0:
		for item in get_items():
			should_be_visible = should_be_visible or item.visible

	visible = should_be_visible
	hideable.visible = hideable_visible

func add_item(n:ProjectListItemControl) -> void:
	if n.get_parent() != null:
		n.reparent(contents)
	else:
		contents.add_child(n)

func get_subsections() -> Array[ProjectSectionControl]:
	var rtn:Array[ProjectSectionControl] = []
	rtn.assign(subsections.get_children())
	return rtn

func get_items() -> Array[ProjectListItemControl]:
	var rtn:Array[ProjectListItemControl] = []
	rtn.assign(contents.get_children())
	return rtn

func deselect() -> void:
	for subsection in get_subsections():
		subsection.deselect()
	for item in get_items():
		item.deselect()

func _on_pressed_head_button() -> void:
	open = !open
