extends VBoxContainer

signal item_selected(item)

signal item_removed(item_data)
signal item_edited(item_data)
signal item_manage_tags_requested(item_data)
signal item_duplicate_requested(item_data)
signal item_relocate_requested(item_data)

@export var _section_scene: PackedScene
@export var _item_scene: PackedScene

@onready var _items_container: VBoxContainer = %ItemsContainer
@onready var _sort_option_button: OptionButton = %SortOptionButton
@onready var _search_box = %SearchBox

var _sections = {}
var _all_item_controls = []
var _current_selection = null

func _ready():
	_update_theme()
	theme_changed.connect(_update_theme)
	_fill_sort_options(_sort_option_button)
	_sort_option_button.item_selected.connect(func(_arg):
		sort_items()
	)
	_add_section("/", true)

func _update_theme():
	_search_box.right_icon = get_theme_icon("Search", "EditorIcons")
	%ScrollContainer.add_theme_stylebox_override(
		"panel",
		get_theme_stylebox("search_panel", "ProjectManager")
	)


func set_search_box_text(text):
	_search_box.text = text
	_update_filters()

func refresh(data):
	for child in _items_container.get_children():
		child.queue_free()
	_all_item_controls = []
	_sections = {}
	_add_section("/", true)
	for item_data in data:
		add(item_data)
	_update_filters()

func add(item_data):
	var section = _normalize_section_path(item_data.hierarchy)
	_ensure_section_exists(section)

	var item_control = _item_scene.instantiate()
	_sections[section].add_item(item_control)
	_all_item_controls.append(item_control)
	item_control.init(item_data)
	item_control.clicked.connect(
		_select_item.bind(item_control)
	)
	item_control.right_clicked.connect(
		_select_item.bind(item_control)
	)
	if item_control.has_signal("tag_clicked"):
		item_control.tag_clicked.connect(
			func(tag):
				set_search_box_text("tag:%s" % tag)
				_search_box.grab_focus()
		)
	_post_add(item_data, item_control)

func _normalize_section_path(path:String) -> String:
	if !path.begins_with("/"):
		path = "/" + path
	if !path.ends_with("/"):
		path = path + "/"
	return path

func _ensure_section_exists(normalized_path:String) -> void:
	# special case for "/"; it doesn't play with the loop properly, and it should always exist already
	if normalized_path == "" or normalized_path == "/":
		return

	var hierarchy_pieces = normalized_path.rstrip("/").split("/")
	var accum = ""
	for pc in hierarchy_pieces:
		accum += pc + "/"
		if !_sections.has(accum):
			_add_section(accum)

func _add_section(normalized_path:String, is_root:bool = false) -> void:
	var section = _section_scene.instantiate()
	section.path = normalized_path
	section.is_root = is_root
	_sections[normalized_path] = section
	if normalized_path == "/":
		_items_container.add_child(section)
	else:
		var parent = _get_section_parent(normalized_path)
		_sections[parent].add_subsection(section)

func _get_section_parent(normalized_path:String) -> String:
	var p = normalized_path.lstrip("/").rstrip("/")
	p = "/".join(p.split("/").slice(0, -1))
	return _normalize_section_path(p)

func sort_items():
	var section_cleanup = []

	for control in _all_item_controls:
		var section = _normalize_section_path(control.get_section())
		_ensure_section_exists(section)
		_sections[section].add_item(control)
	for sec in _sections.values():
		if sec.is_empty():
			section_cleanup.append(sec)
			continue

		var subsection_sort = sec.get_subsections().map(
			func(x): return x.path
		)
		subsection_sort.sort()
		for i in range(len(subsection_sort)):
			sec.subsections.move_child(_sections[subsection_sort[i]], i)

		var sort_data = sec.get_items().map(
			func(x): return x.get_sort_data()
		)
		sort_data.sort_custom(self._item_comparator)
		for i in range(len(sort_data)):
			var sorted_item = sort_data[i]
			sec.contents.move_child(
				sorted_item.ref,
				i
			)
	for p in section_cleanup:
		_sections.erase(_normalize_section_path(p.path))
		p.queue_free()

func _post_add(item_data, item_control):
	item_control.removed.connect(
		func(): item_removed.emit(item_data)
	)
	item_control.edited.connect(
		func(): item_edited.emit(item_data)
	)
	item_control.manage_tags_requested.connect(
		func(): item_manage_tags_requested.emit(item_data)
	)
	item_control.duplicate_requested.connect(
		func(): item_duplicate_requested.emit(item_data)
	)
	item_control.relocate_requested.connect(
		func(): item_relocate_requested.emit(item_data)
	)

func _item_comparator(a, b):
	#if a.hierarchy != b.hierarchy:
		#if a.hierarchy == "" and b.hierarchy != "": return false
		#elif a.hierarchy != "" and b.hierarchy == "": return true
		#elif a.hierarchy.begins_with(b.hierarchy): return true
		#elif b.hierarchy.begins_with(a.hierarchy): return false
		#else:
			#return a.hierarchy < b.hierarchy
	if a.favorite && !b.favorite:
		return true
	if b.favorite && !a.favorite:
		return false
	match _sort_option_button.selected:
		0: return a.last_modified > b.last_modified
		2: return a.path < b.path
		3: return a.tag_sort_string < b.tag_sort_string
		_: return a.name < b.name
	return a.name < b.name


func _fill_sort_options(btn: OptionButton):
	btn.add_item(tr("Last Edited"))
	btn.add_item(tr("Name"))
	btn.add_item(tr("Path"))
	btn.add_item(tr("Tags"))

	var last_checked_sort = Cache.smart_value(self, "last_checked_sort", true)
	btn.select(last_checked_sort.ret(1))
	btn.item_selected.connect(func(idx): last_checked_sort.put(idx))


func _select_item(item):
	if _current_selection and is_instance_valid(_current_selection) and _current_selection.has_method("deselect"):
		_current_selection.deselect()
	_current_selection = item
	item.select()
	item_selected.emit(item)


func _on_search_box_text_changed(_new_text: String) -> void:
	_update_filters()


func _update_filters():
	var search_tag = ""
	var search_term = ""
	for part in _search_box.text.split(" "):
		if part.begins_with("tag:"):
			var tag_parts = part.split(":")
			if len(tag_parts) > 1:
				search_tag = part.split(":")[1]
		else:
			search_term += part

	for section_path in _sections.keys():
		var sec = _sections[section_path]
		for item in sec.get_items():
			if item.has_method("apply_filter"):
				var should_be_visible = item.apply_filter(func(data):
					var search_path = data['path']
					if not search_term.contains('/'):
						search_path = search_path.get_file()
					var check_path = search_path.findn(search_term) != -1
					var check_name = data['name'].findn(search_term) != -1
					var check_term = search_term.is_empty() or check_path or check_name
					if not search_tag.is_empty():
						return check_term and _has_tag(data, search_tag)
					else:
						return check_term
				)
				item.visible = should_be_visible
	_sections["/"].update_visibility()

func _has_tag(tags_source, tag):
	return Array(tags_source.tags).find(tag) > -1

