extends HBoxContainer

signal manage_tags_requested(item_tags, all_tags, on_confirm)

@onready var _sidebar: VBoxContainer = %ActionsSidebar
@onready var _projects_list: VBoxContainer = %ProjectsList
@onready var _import_project_dialog: ConfirmationDialog = %ImportProjectDialog
@onready var _new_project_dialog = %NewProjectDialog
@onready var _scan_dialog = %ScanDialog
@onready var _install_project_from_zip_dialog = %InstallProjectSimpleDialog
@onready var _duplicate_project_dialog = %DuplicateProjectDialog
@onready var _clone_project_dialog = %CloneProjectDialog
@onready var _relocate_project_dialog = %RelocateProjectDialog


var _projects: Projects.List
var _load_projects_queue = []
var _remove_missing_action: Action.Self


func init(projects: Projects.List):
	self._projects = projects

	var remove_missing_popup = RemoveMissingDialog.new(_remove_missing)
	add_child(remove_missing_popup)

	var actions := Action.List.new([
		Action.from_dict({
			"key": "new-project",
			"icon": Action.IconTheme.new(self, "Add", "EditorIcons"),
			"act": _new_project_dialog.raise,
			"label": tr("New"),
		}),
		Action.from_dict({
			"label": tr("Import"),
			"key": "import-project",
			"icon": Action.IconTheme.new(self, "Load", "EditorIcons"),
			"act": func(): import()
		}),
		Action.from_dict({
			"label": tr("Clone"),
			"key": "clone-project",
			"icon": Action.IconTheme.new(self, "VcsBranches", "EditorIcons"),
			"act": func(): _clone_project_dialog.raise()
		}),
		Action.from_dict({
			"label": tr("Scan"),
			"key": "scan-projects",
			"icon": Action.IconTheme.new(self, "Search", "EditorIcons"),
			"act": func():
				_scan_dialog.current_dir = ProjectSettings.globalize_path(
					Config.DEFAULT_PROJECTS_PATH.ret()
				)
				_scan_dialog.popup_centered_ratio(0.5)
				pass\
		}),
		Action.from_dict({
			"label": tr("Cleanup"),
			"key": "remove-missing",
			"icon": Action.IconTheme.new(self, "Clear", "EditorIcons"),
			"act": func(): remove_missing_popup.popup_centered()
		}),
		Action.from_dict({
			"label": tr("Refresh List"),
			"key": "refresh",
			"icon": Action.IconTheme.new(self, "Reload", "EditorIcons"),
			"act": _refresh
		})
	])

	_remove_missing_action = actions.by_key('remove-missing')

	var project_actions = TabActions.Menu.new(
		actions.sub_list([
			'new-project',
			'import-project',
			'clone-project',
			'scan-projects',
		]).all(),
		TabActions.Settings.new(
			Cache.section_of(self),
			[
				'new-project',
				'import-project',
				'clone-project',
				'scan-projects'
			]
		)
	)
	project_actions.add_controls_to_node($ProjectsList/HBoxContainer/TabActions)
	project_actions.icon = get_theme_icon("GuiTabMenuHl", "EditorIcons")
	#$ProjectsList/HBoxContainer/TabActions.add_child(project_actions)

	$ProjectsList/HBoxContainer.add_child(_remove_missing_action.to_btn().make_flat(true).show_text(false))
	$ProjectsList/HBoxContainer.add_child(actions.by_key('refresh').to_btn().make_flat(true).show_text(false))
	$ProjectsList/HBoxContainer.add_child(project_actions)

	_import_project_dialog.imported.connect(func(project_path, editor_path, edit, callback):
		var project: Projects.Item
		if projects.has(project_path):
			project = projects.retrieve(project_path)
			project.editor_path = editor_path
			project.emit_internals_changed()
		else:
			project = _projects.add(project_path, editor_path)
			project.load()
			_projects_list.add(project)
		_projects.save()

		if edit:
			project.edit()
			AutoClose.close_if_should()

		if callback:
			callback.call(project, projects)

		_projects_list.sort_items()
	)

	_clone_project_dialog.cloned.connect(func(path: String):
		assert(path.get_file() == "project.godot")
		import(path)
	)

	_new_project_dialog.created.connect(func(project_path):
		import(project_path)
	)

	_scan_dialog.dir_to_scan_selected.connect(func(dir_to_scan: String):
		_scan_projects(dir_to_scan)
	)

	_duplicate_project_dialog.duplicated.connect(func(project_path, callback):
		import(project_path, callback)
	)

	_projects_list.refresh(_projects.all())
	_load_projects()


func _load_projects():
	_load_projects_array(_projects.all())


func _load_projects_array(array):
	for project in array:
		project.load()
		await get_tree().process_frame
	_projects_list.sort_items()
	_update_remove_missing_disabled()


func _refresh():
	_projects.load()
	_projects_list.refresh(_projects.all())
	_load_projects()


func import(project_path="", callback=null):
	if _import_project_dialog.visible:
		return
	_import_project_dialog.init(project_path, _projects.get_editors_to_bind(), callback)
	_import_project_dialog.popup_centered()


func install_zip(zip_reader: ZIPReader, project_name):
	if _install_project_from_zip_dialog.visible:
		zip_reader.close()
		return
	_install_project_from_zip_dialog.title = "Install Project: %s" % project_name
	_install_project_from_zip_dialog.get_ok_button().text = tr("Install")
	_install_project_from_zip_dialog.raise(project_name)
	_install_project_from_zip_dialog.dialog_hide_on_ok = false
	_install_project_from_zip_dialog.about_to_install.connect(func(final_project_name, project_dir):
		var unzip_err = zip.unzip_to_path(zip_reader, project_dir)
		zip_reader.close()
		if unzip_err != OK:
			_install_project_from_zip_dialog.error(tr("Failed to unzip."))
			return
		var project_configs = utils.find_project_godot_files(project_dir)
		if len(project_configs) == 0:
			_install_project_from_zip_dialog.error(tr("No project.godot found."))
			return

		var project_file_path = project_configs[0]
		_install_project_from_zip_dialog.hide()
		import(project_file_path.path)
		pass,
		CONNECT_ONE_SHOT
	)


func _scan_projects(dir_path):
	var project_configs = utils.find_project_godot_files(dir_path)
	var added_projects = []
	for project_config in project_configs:
		var project_path = project_config.path
		if _projects.has(project_path):
			continue
		var project = _projects.add(project_path, null)
		_projects_list.add(project)
		added_projects.append(project)
	_projects.save()
	_load_projects_array(added_projects)


func _remove_missing():
	for p in _projects.all().filter(func(x): return x.is_missing):
		_projects.erase(p.path)

	var hierarchy = Config.PROJECT_HIERARCHY.ret()
	for p in hierarchy.keys().filter(func(x): return !_projects.has(x)):
		hierarchy.erase(p)
	Config.PROJECT_HIERARCHY.put(hierarchy)

	_projects.save()
	_projects_list.refresh(_projects.all())
	_projects_list.sort_items()
	_sidebar.refresh_actions([])
	_update_remove_missing_disabled()


func _update_remove_missing_disabled():
	var missing_projects = len(
		_projects.all().filter(func(x): return x.is_missing)
	)
	var orphaned_hierarchy = len(
		Config.PROJECT_HIERARCHY.ret().keys().filter(func(x): return !_projects.has(x))
	)
	_remove_missing_action.disable(missing_projects == 0 and orphaned_hierarchy == 0)


func _on_projects_list_item_selected(item) -> void:
	_sidebar.refresh_actions(item.get_actions())


func _on_projects_list_item_removed(item_data) -> void:
	if _projects.has(item_data.path):
		_projects.erase(item_data.path)
		_projects.save()
	_sidebar.refresh_actions([])
	_update_remove_missing_disabled()


func _on_projects_list_item_edited(item_data) -> void:
	item_data.emit_internals_changed()
	_projects.save()
	_projects_list.sort_items()


func _on_projects_list_item_manage_tags_requested(item_data) -> void:
	var all_tags = Set.new()
	all_tags.append_array(_projects.get_all_tags())
	all_tags.append_array(Config.DEFAULT_PROJECT_TAGS.ret())
	manage_tags_requested.emit(
		item_data.tags,
		all_tags.values(),
		func(new_tags):
			item_data.tags = new_tags
			_on_projects_list_item_edited(item_data)
	)


func _on_projects_list_item_duplicate_requested(project: Projects.Item) -> void:
	if _duplicate_project_dialog.visible:
		return

	_duplicate_project_dialog.raise(project.name, project)


func _on_projects_list_item_relocate_requested(project:Projects.Item) -> void:
	var path_split:PackedStringArray = project.path.simplify_path().split("/")
	path_split.remove_at(path_split.size() - 1)
	var initial_path = "/".join(path_split)

	var _relocate_project_dialog = %RelocateProjectDialog
	_relocate_project_dialog.show()

	var new_path = _relocate_project_dialog.current_file.simplify_path()
	if new_path == "" or new_path == initial_path:
		return

	if FileAccess.file_exists(new_path + "/project.godot"):
		var d:AcceptDialog = AcceptDialog.new()
		d.dialog_text = "%s already contains a Godot project!\nCannot relocate." % [new_path]
		d.initial_position = Window.WINDOW_INITIAL_POSITION_CENTER_MAIN_WINDOW_SCREEN
		d.position
		d.exclusive = true
		get_viewport().add_child(d)
		d.show()
		await d.visibility_changed
	else:
		var actually_move = func():
			var wait_dialog = WaitDialog.raise(self, "Relocating \"%s\" to\n%s..." % [project.name, new_path])
			var result = await _rename_absolute_recursive(initial_path, new_path)
			wait_dialog.close()
			if result[0] == Error.OK:
				var new_project = _projects.add(new_path + "/project.godot", project.editor_path)
				new_project.hierarchy = project.hierarchy
				new_project.favorite = project.favorite
				_projects.erase(project.path)
				_projects.save()
				_refresh()
			if result[0] or result[1] != null:
				var d:AcceptDialog = AcceptDialog.new()
				d.title = "Relocation " + ("Warning" if result[0] == Error.OK else "Failure")
				d.dialog_text = ""
				if result[0] != Error.OK:
					d.dialog_text += error_string(result[0])
				if result[0] != Error.OK and result[1] != null:
					d.dialog_text += ": "
				if result[1] != null:
					d.dialog_text += result[1]
				d.initial_position = Window.WINDOW_INITIAL_POSITION_CENTER_MAIN_WINDOW_SCREEN
				d.position
				d.exclusive = true
				get_viewport().add_child(d)
				d.show()
				await d.visibility_changed

		var confirm = true
		if DirAccess.get_files_at(new_path).size() != 0:
			confirm = false

			var d:ConfirmationDialogAutoFree = ConfirmationDialogAutoFree.new()
			d.dialog_text = "%s is not empty.\nAre you sure you want to relocate %s to here?" % [new_path, project.name]
			d.initial_position = Window.WINDOW_INITIAL_POSITION_CENTER_MAIN_WINDOW_SCREEN
			d.position
			d.exclusive = true
			get_viewport().add_child(d)
			d.show()
			d.confirmed.connect(actually_move)
			await d.visibility_changed
		else:
			actually_move.call()

func _rename_absolute_recursive(from_path:String, to_path:String, remove:bool=true, time_box=null) -> Array:
	var from_dir = DirAccess.open(from_path)
	from_dir.include_hidden = true
	DirAccess.make_dir_absolute(to_path)

	var errors = []

	if time_box == null:
		time_box = [Time.get_ticks_msec()]

	for f in from_dir.get_files():
		var e = DirAccess.copy_absolute(from_path+"/"+f, to_path+"/"+f)
		if e: return [e,"Failed to copy "+from_path+"/"+f+" -> "+to_path+"/"+f]
		e = FileAccess.set_hidden_attribute(to_path+"/"+f, FileAccess.get_hidden_attribute(from_path+"/"+f))
		if e: return [e,"Could not set hidden attr on "+to_path+"/"+f]

	if Time.get_ticks_msec() - time_box[0] > 0.015:
		time_box[0] = Time.get_ticks_msec()
		await get_tree().process_frame

	for d in from_dir.get_directories():
		var e = await _rename_absolute_recursive(from_path+"/"+d, to_path+"/"+d, false, time_box)
		if e[0]: return e
		e = FileAccess.set_hidden_attribute(to_path+"/"+d, FileAccess.get_hidden_attribute(from_path+"/"+d))
		if e: return [e,"Could not set hidden attr on "+to_path+"/"+d]

	if Time.get_ticks_msec() - time_box[0] > 0.015:
		time_box[0] = Time.get_ticks_msec()
		await get_tree().process_frame

	if remove:
		var e = _remove_absolute_recursive(from_path)
		if e.keys().size() > 0:
			return [Error.OK,"Some files could not be cleaned up; you will need to manually delete %s" % from_path]
	return [Error.OK,null]

func _remove_absolute_recursive(path:String) -> Dictionary:
	var errors:Dictionary = {};

	var from_dir = DirAccess.open(path)
	from_dir.include_hidden = true

	for d in from_dir.get_directories():
		var e = _remove_absolute_recursive(path+"/"+d)

		# merge the error dictionaries
		for k in e.keys():
			if !errors.has(k):
				errors[k] = []
			for x in e[k]:
				errors[k].append(x)

	for f in from_dir.get_files():
		var e = DirAccess.remove_absolute(path+"/"+f)
		if e:
			if !errors.has(e):
				errors[e] = []
			errors[e].append(path+"/"+f)

	DirAccess.remove_absolute(path)
	return errors
