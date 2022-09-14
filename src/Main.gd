extends HBoxContainer

enum { SAVING, LOADING }

const dead_zone = Vector2(8, 8)

onready var file_dialog: FileDialog = $c/FileDialog

var settings: Settings
var file_mode
var cursor_position = Vector2.ZERO
var cursor_visible = false

func _init():
	settings = Settings.new()
	settings = settings.load_data()


func _ready():
	get_node("%TargetColor").color = settings.target_color
	get_node("%Similarity").value = settings.similarity
	get_node("%Proximity").value = settings.proxity
	get_node("%ReplacementColor").color = settings.replacement_color


func _on_LoadImage_pressed():
	file_mode = LOADING
	file_dialog.mode = FileDialog.MODE_OPEN_FILE
	file_dialog.current_dir = settings.load_dir
	show_file_dialog()


func _on_SaveImage_pressed():
	file_mode = SAVING
	file_dialog.mode = FileDialog.MODE_SAVE_FILE
	file_dialog.current_dir = settings.save_dir
	show_file_dialog()


func show_file_dialog():
	# Allow the popup to be closed after loading image
	disable_viewport_input()
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


func load_image(path):
	var texture = ImageTexture.new()
	var image = Image.new()
	image.load(path)
	texture.create_from_image(image)
	get_node("%Image").texture = texture


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


func _draw():
	if cursor_visible:
		draw_circle(cursor_position + $VP.rect_position, 8.0, Color(0.1, 1.0, 0.0, 0.6))


func _on_VP_gui_input(event):
	if event is InputEventMouseMotion:
		cursor_position = event.position # - $M/VP.rect_position
		cursor_visible = Rect2(dead_zone, $VP.rect_size - 2 * dead_zone).has_point(cursor_position)
		update()


func _on_Main_resized():
	$VP/Viewport.size = Vector2.ZERO
	$Timer.start()


func _on_Timer_timeout():
	$VP/Viewport.size = $VP.rect_size


func _on_Help_pressed():
	$VP/Viewport.gui_disable_input = true
	$c/HelpDialog.popup_centered()


func _on_HelpDialog_popup_hide():
	disable_viewport_input(false)


func _on_Similarity_value_changed(value):
	settings.similarity = value


func _on_Proximity_value_changed(value):
	settings.proxity = value


func _on_TargetColor_color_changed(color):
	settings.target_color = color


func _on_ReplacementColor_color_changed(color):
	settings.replacement_color = color


func disable_viewport_input(disable = true):
	$VP/Viewport.gui_disable_input = disable
	# Get the cross cursor back
	get_node("%Image").grab_focus()


func _on_FileDialog_popup_hide():
	disable_viewport_input(false)
