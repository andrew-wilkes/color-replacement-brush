extends HBoxContainer

enum { SAVING, LOADING }

const CELL_SIZE = 4 # e.g. 4 x 4 pixels square
const INPUT_FILE_FILTERS = "*.jpg,*.jpeg,*.png,*.webp,*.tga,*.bmp ; Image files"
const OUTPUT_FILE_FILTERS = "*.png ; PNG image files"

onready var file_dialog: FileDialog = $c/FileDialog

var settings: Settings
var file_mode
var cursor_position = Vector2.ZERO
var cursor_visible = false
var cells = PoolByteArray()
var num_rows = 32
var num_cols = 32
var area
var marker_col
var marker_row
var saved = false

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
	if OS.get_name() == "HTML5":
		load_demo_image()


func _on_Image_gui_input(event):
	if event is InputEventMouseMotion:
		cursor_position = event.position
		marker_col = int(cursor_position.x / CELL_SIZE)
		marker_row = int(cursor_position.y / CELL_SIZE)
		var mouse_state = Input.get_mouse_button_mask()
		if mouse_state > 0:
			# Left and middle mouse buttons to paint (1010 0000)
			update_cells(marker_col, marker_row, mouse_state & 5 > 0)
		update_cursor_overlay(marker_col, marker_row)
		get_node("%Image").update()
	# Use mouse wheel to alter proximity value
	if event is InputEventMouseButton and event.pressed:
		match event.button_index:
			4:
				get_node("%Proximity").value = settings.proximity + 1
			5:
				get_node("%Proximity").value = settings.proximity - 1
		update_cursor_overlay(marker_col, marker_row)
		get_node("%Image").update()
	$HideMarker.start()


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
	var offset = int(settings.proximity / 2.0)
	for y in settings.proximity:
			for x in settings.proximity:
				update_cell(col + x - offset, row + y - offset, cell_value)
	set_shader_data()


func set_shader_data():
	get_node("%Image").material.set_shader_param("cells", get_data_texture())


func get_data_texture():
	var img = Image.new()
	img.create_from_data(num_cols, num_rows, false, Image.FORMAT_R8, cells) # Only use the red component
	var texture = ImageTexture.new()
	texture.create_from_image(img, 0)
	return texture


func update_cell(col, row, cell_value):
	if col < num_cols and row < num_rows and col >= 0 and row >= 0:
		cells[col + num_cols * row] = cell_value


func update_cursor_overlay(col, row):
	var size = settings.proximity * CELL_SIZE
	var offset = int(settings.proximity / 2.0)
	get_node("%Image").material.set_shader_param("marker_position", Vector2(col - offset, row - offset) * CELL_SIZE)
	get_node("%Image").material.set_shader_param("marker_size", size)


func _on_LoadImage_pressed():
	file_mode = LOADING
	file_dialog.mode = FileDialog.MODE_OPEN_FILE
	file_dialog.current_dir = settings.load_dir
	file_dialog.filters = PoolStringArray([INPUT_FILE_FILTERS])
	file_dialog.current_path = ""
	file_dialog.current_file = ""
	show_file_dialog()
	file_dialog.deselect_items()


func _on_SaveImage_pressed():
	file_mode = SAVING
	file_dialog.mode = FileDialog.MODE_SAVE_FILE
	file_dialog.current_dir = settings.save_dir
	file_dialog.filters = PoolStringArray([OUTPUT_FILE_FILTERS])
	show_file_dialog()
	if not saved:
		file_dialog.current_path = ""
		file_dialog.current_file = ""
		file_dialog.deselect_items()


func _on_Help_pressed():
	disable_viewport_input()
	$c/AboutDialog.popup_centered()


func _on_AboutDialog_popup_hide():
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


func show_file_dialog():
	# Allow the popup to be closed after loading image
	disable_viewport_input()
	file_dialog.popup_centered()


func _on_FileDialog_file_selected(path):
	match file_mode:
		LOADING:
			settings.load_dir = path.get_base_dir()
			load_image(path)
			get_node("%SaveImage").disabled = false
			saved = false
		SAVING:
			settings.save_dir = path.get_base_dir()
			save_image(path)
			saved = true


func load_image(path):
	var texture = ImageTexture.new()
	var image = Image.new()
	if OK == image.load(path):
		texture.create_from_image(image)
		get_node("%Image").texture = texture
		init_cells(image.get_size())


func load_demo_image():
	get_node("%Image").texture = load("res://assets/demo.png")
	init_cells(Vector2(256, 256))
	get_node("%SaveImage").disabled = false
	saved = false


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


func _on_Main_resized():
	# Allow the Viewport to be reduced in size and throttle how often it does so
	$VP/Viewport.size = Vector2.ZERO
	$ViewportSizer.start()


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


func _on_Author_meta_clicked(meta):
	var _e = OS.shell_open(str(meta))


func disable_viewport_input(disable = true):
	$VP/Viewport.gui_disable_input = disable
	# Get the cross cursor back
	get_node("%Image").grab_focus()


func _on_FileDialog_popup_hide():
	disable_viewport_input(false)
