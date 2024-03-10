class_name CommandViewerNewCommandDialog
extends ConfirmationDialogAutoFree

signal created(command_name: String, path: String, args: PackedStringArray, is_local: bool)

@onready var _name_edit = %NameEdit
@onready var _args_edit = %ArgsEdit as ArrayEdit
@onready var _is_local_checkbox = %IsLocalCheckbox
@onready var _path_edit = %PathEdit


var name_text: String:
	get: return _name_edit.text.strip_edges()


var args_array: PackedStringArray:
	get: return _args_edit.get_array()


var path: String:
	get: return _path_edit.text.strip_edges()


var is_local: bool:
	get: return _is_local_checkbox.button_pressed


func _ready():
	min_size = Vector2(250, 0) * Config.EDSCALE
	
	confirmed.connect(func():
		created.emit(name_text, path, args_array, is_local)
	)


func init(cmd_name, cmd_path, cmd_args, is_local):
	_name_edit.text = cmd_name
	_path_edit.text = cmd_path
	_args_edit.override_array(cmd_args)
	_is_local_checkbox.button_pressed = is_local


func _process(delta):
	var ok_button = get_ok_button()
	ok_button.disabled = name_text.is_empty() or len(args_array) == 0
