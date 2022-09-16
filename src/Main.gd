extends HBoxContainer

enum { SAVING, LOADING }

const DEAD_ZONE = Vector2(8, 8) # To be able to detect mouse movements before exiting the image area
const CELL_SIZE = 4 # e.g. 4 x 4 pixels square

onready var file_dialog: FileDialog = $c/FileDialog

var settings: Settings
var file_mode
var cursor_position = Vector2.ZERO
var cursor_visible = false
var cells = PoolByteArray()
var num_rows = 32
var num_cols = 32
var area

func _init():
	settings = Settings.new()
	settings = settings.load_data()


func _ready():
	get_node("%TargetColor").color = settings.target_color
	get_node("%Similarity").value = settings.similarity
	get_node("%Proximity").value = settings.proximity
	get_node("%ReplacementColor").color = settings.replacement_color
	Input.use_accumulated_input = true


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
	init_cells(image.get_size())


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


func _on_Image_gui_input(event):
	if event is InputEventMouseMotion:
		cursor_position = event.position
		# May not need this unless wanting to display an overlay around the cursor
		cursor_visible = Rect2(DEAD_ZONE, $VP.rect_size - 2 * DEAD_ZONE).has_point(cursor_position)
		var mouse_state = Input.get_mouse_button_mask()
		if mouse_state > 0:
			update_cells(cursor_position.x, cursor_position.y, mouse_state == BUTTON_MASK_LEFT)


func _on_Help_pressed():
	$VP/Viewport.gui_disable_input = true
	$c/HelpDialog.popup_centered()


func _on_HelpDialog_popup_hide():
	disable_viewport_input(false)


func _on_Similarity_value_changed(value):
	settings.similarity = value


func _on_Proximity_value_changed(value):
	settings.proximity = value


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


func init_cells(_area: Vector2):
	area = _area
	# Want to at least cover the image area with the grid of cells
	num_rows = int(round(area.y / CELL_SIZE))
	num_cols = int(round(area.x / CELL_SIZE))
	cells = PoolByteArray() # Later use this as shader input data
	cells.resize(num_rows * num_cols)
	for idx in cells.size():
		cells[idx] = 0


func update_cells(x, y, add):
	var col = int(x / CELL_SIZE)
	var row = int(y / CELL_SIZE)
	# Note: holding the mouse button down and moving outside of the grid
	# still causes calls to be made but it doesn't matter
	var cell_value = 0xff if add else 0
	if settings.proximity > 0:
		for y in range(-settings.proximity, settings.proximity + 1):
			for x in range(-settings.proximity, settings.proximity + 1):
				update_cell(col + x, row + y, cell_value)
	else:
		update_cell(col, row, cell_value)
	update_rects()


func update_cell(col, row, cell_value):
	if col < num_cols and row < num_rows and col >= 0 and row >= 0:
		cells[col + num_cols * row] = cell_value


# Temporary until the shader is written
func update_rects():
	var rects = get_node("%Image").rects
	var size = Vector2(CELL_SIZE, CELL_SIZE)
	rects.clear()
	var pos = Vector2.ZERO
	var idx = 0
	for row in num_rows:
		for col in num_cols:
			if cells[idx] > 0:
				rects.append(Rect2(pos, size))
			pos.x += CELL_SIZE
			idx += 1
		pos.y += CELL_SIZE
		pos.x = 0
	get_node("%Image").update()


func _on_Main_resized():
	# Allow the Viewport to be reduced in size and throttle how often it does so
	$VP/Viewport.size = Vector2.ZERO
	$Timer.start()


func _on_Timer_timeout():
	$VP/Viewport.size = $VP.rect_size
