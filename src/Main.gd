extends HBoxContainer

enum { SAVING, LOADING }

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
	set_target_color(settings.target_color)
	get_node("%Similarity").value = settings.similarity
	get_node("%Proximity").value = settings.proximity
	get_node("%ReplacementColor").color = settings.replacement_color
	set_replacement_color(settings.replacement_color)
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
			save_image(path)


func load_image(path):
	var texture = ImageTexture.new()
	var image = Image.new()
	image.load(path)
	texture.create_from_image(image)
	get_node("%Image").texture = texture
	init_cells(image.get_size())


func save_image(path):
	var img = $VP/Viewport.get_texture().get_data()
	var isize = get_node("%Image").rect_size
	img.flip_y()
	img.crop(isize.x, isize.y)
	img.save_png(path)


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
		var col = int(cursor_position.x / CELL_SIZE)
		var row = int(cursor_position.y / CELL_SIZE)
		var mouse_state = Input.get_mouse_button_mask()
		if mouse_state > 0:
			update_cells(col, row, mouse_state == BUTTON_MASK_LEFT)
		update_cursor_overlay(col, row)
		get_node("%Image").update()


func _on_Help_pressed():
	$VP/Viewport.gui_disable_input = true
	$c/HelpDialog.popup_centered()


func _on_HelpDialog_popup_hide():
	disable_viewport_input(false)


func _on_Similarity_value_changed(value):
	settings.similarity = value
	get_node("%Image").material.set_shader_param("deviance", 1.0 - value)


func _on_Proximity_value_changed(value):
	settings.proximity = value


func _on_TargetColor_color_changed(color):
	set_target_color(color)


func set_target_color(color):
	settings.target_color = color
	get_node("%Image").material.set_shader_param("target_color", color)


func _on_ReplacementColor_color_changed(color):
	set_replacement_color(color)


func set_replacement_color(color):
	settings.replacement_color = color
	get_node("%Image").material.set_shader_param("replacement_color", color)


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
	set_shader_data()


func update_cells(col, row, add):
	# Note: holding the mouse button down and moving outside of the grid
	# still causes calls to be made but it doesn't matter
	var cell_value = 0xff if add else 0
	if settings.proximity > 0:
		for y in range(-settings.proximity, settings.proximity + 1):
			for x in range(-settings.proximity, settings.proximity + 1):
				update_cell(col + x, row + y, cell_value)
	else:
		update_cell(col, row, cell_value)
	set_shader_data()


func set_shader_data():
	get_node("%Image").material.set_shader_param("cells", get_data_texture())


var not_saved = true

func get_data_texture():
	var img = Image.new()
	img.create_from_data(num_cols, num_rows, false, Image.FORMAT_R8, cells) # Only use the red component
	if not_saved and Input.is_key_pressed(KEY_S):
		img.save_png("res:test.png")
		not_saved = false
	var texture = ImageTexture.new()
	texture.create_from_image(img, 0)
	return texture


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


func update_cursor_overlay(col, row):
	var size = CELL_SIZE if settings.proximity == 0 else (settings.proximity * 2 + 1) * CELL_SIZE
	var offset = settings.proximity
	get_node("%Image").material.set_shader_param("marker_position", Vector2(col - offset, row - offset) * CELL_SIZE)
	get_node("%Image").material.set_shader_param("marker_size", size)


func _on_Main_resized():
	# Allow the Viewport to be reduced in size and throttle how often it does so
	$VP/Viewport.size = Vector2.ZERO
	$Timer.start()


func _on_ViewportSizer_timeout():
	$VP/Viewport.size = $VP.rect_size


func _on_TargetColor_popup_closed():
	disable_viewport_input(false)


func _on_ReplacementColor_popup_closed():
	disable_viewport_input(false)


func _on_TargetColor_pressed():
	disable_viewport_input()


func _on_ReplacementColor_pressed():
	disable_viewport_input()


func _on_HideMarker_timeout():
	get_node("%Image").material.set_shader_param("marker_position", Vector2(-100000, -100000))
