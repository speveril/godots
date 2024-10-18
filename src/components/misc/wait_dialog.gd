class_name WaitDialog extends AcceptDialog

static func raise(caller:Node, text:String):
	var dialog = WaitDialog.new()
	dialog.title = "Please wait"
	dialog.dialog_text = text
	dialog.initial_position = Window.WINDOW_INITIAL_POSITION_CENTER_MAIN_WINDOW_SCREEN
	dialog.dialog_close_on_escape = false
	dialog.exclusive = true
	dialog.get_ok_button().hide()
	caller.get_viewport().add_child(dialog)
	dialog.show()
	return dialog

static func raise_with_signal(caller:Node, text:String, done_signal:Signal):
	var dialog = raise(caller, text)
	done_signal.connect(dialog.close, CONNECT_ONE_SHOT)
	return dialog

func close():
	hide()
	get_parent().remove_child(self)
	queue_free()
