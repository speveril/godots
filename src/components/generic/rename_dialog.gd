class_name RenameDialog
extends ConfirmationDialogAutoFree

signal rename_done(new_name: String)

@onready var _name_edit: LineEdit = %LineEdit

func _ready() -> void:
	super._ready()

	min_size = Vector2(350, 0) * Config.EDSCALE

	confirmed.connect(func() -> void:
		rename_done.emit(
			_name_edit.text.strip_edges(),
		)
	)

	_name_edit.text_changed.connect(func(new_text: String) -> void:
		get_ok_button().disabled = new_text.strip_edges().is_empty()
	)
	_name_edit.text_submitted.connect(func(new_text: String) -> void:
		if !new_text.strip_edges().is_empty():
			rename_done.emit(
				_name_edit.text.strip_edges(),
			)
			hide()
	)

	_name_edit.grab_focus()

func init(initial_name: String) -> void:
	_name_edit.text = initial_name
