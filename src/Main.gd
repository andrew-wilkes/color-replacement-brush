extends HBoxContainer

enum { SAVING, LOADING }

onready var file_dialog: FileDialog = $c/FileDialog

var settings
var file_mode

func _init():
	settings = Settings.new()
	settings = settings.load_data()


func _ready():
	pass


func _on_LoadImage_pressed():
	file_mode = LOADING
	file_dialog.mode = FileDialog.MODE_OPEN_FILE
	file_dialog.current_dir = settings.load_dir
	file_dialog.current_path = ""
	file_dialog.current_file = ""
	file_dialog.popup_centered()


func _on_SaveImage_pressed():
	file_mode = SAVING
	file_dialog.mode = FileDialog.MODE_SAVE_FILE
	file_dialog.current_dir = settings.save_dir
	file_dialog.current_path = ""
	file_dialog.current_file = ""
	file_dialog.popup_centered()


func _on_FileDialog_file_selected(path):
	match file_mode:
		LOADING:
			settings.load_dir = path.get_base_dir()
			load_image(path)
		SAVING:
			settings.save_dir = path.get_base_dir()
	print(path)


func load_image(path):
	var texture = ImageTexture.new()
	var image = Image.new()
	image.load(path)
	texture.create_from_image(image)
	$Image.texture = texture


func _unhandled_input(event):
	if event is InputEventKey:
		if event.pressed and event.scancode == KEY_ESCAPE:
			save_and_quit()


# Handle shutdown of App
func _notification(what):
	if what == MainLoop.NOTIFICATION_WM_QUIT_REQUEST:
		save_and_quit()


func save_and_quit():
	settings.save_data()
	get_tree().quit()



