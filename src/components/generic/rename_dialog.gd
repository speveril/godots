extends ConfirmationDialogAutoFree

signal rename_done(new_name)

@onready var _name_edit: LineEdit = %LineEdit

func _ready() -> void:
	super._ready()

	min_size = Vector2(350, 0) * Config.EDSCALE

	confirmed.connect(func():
		rename_done.emit(
			_name_edit.text.strip_edges(),
		)
	)

	_name_edit.text_changed.connect(func(new_text):
		get_ok_button().disabled = new_text.strip_edges().is_empty()
	)
	_name_edit.text_submitted.connect(func(new_text):
		if !new_text.strip_edges().is_empty():
			rename_done.emit(
				_name_edit.text.strip_edges(),
			)
			hide()
	)

	_name_edit.grab_focus()

func init(initial_name):
	_name_edit.text = initial_name
