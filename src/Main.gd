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
	get_node("%Proximity").value = settings.cell_size
	get_node("%ReplacementColor").color = settings.replacement_color
	init_cells($VP.rect_size)
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


func _on_Image_gui_input(event):
	if event is InputEventMouseMotion:
		cursor_position = event.position
		cursor_visible = Rect2(dead_zone, $VP.rect_size - 2 * dead_zone).has_point(cursor_position)
		var mouse_state = Input.get_mouse_button_mask()
		if mouse_state > 0:
			update_cells(cursor_position.x, cursor_position.y, mouse_state == BUTTON_MASK_LEFT)


func _on_Main_resized():
	$VP/Viewport.size = Vector2.ZERO
	$Timer.start()


func _on_Timer_timeout():
	$VP/Viewport.size = $VP.rect_size
	resize_num_cells($VP.rect_size)


func _on_Help_pressed():
	$VP/Viewport.gui_disable_input = true
	$c/HelpDialog.popup_centered()


func _on_HelpDialog_popup_hide():
	disable_viewport_input(false)


func _on_Similarity_value_changed(value):
	settings.similarity = value


func _on_Proximity_value_changed(value):
	settings.cell_size = int(value)


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

var cells = PoolByteArray()
var num_rows = 32
var num_cols = 32

func init_cells(area: Vector2):
	num_rows = int(area.y) / settings.cell_size
	num_cols = int(area.x) / settings.cell_size
	var a = []
	a.resize(num_rows * num_cols)
	a.fill(0)
	cells = PoolByteArray(a)


func resize_cells(new_cell_size: int):
	var new_cells = PoolByteArray()
	var factor = new_cell_size / settings.cell_size
	var num_new_rows = num_rows * factor
	var num_new_cols = num_cols * factor
	new_cells.resize(num_new_rows * num_new_cols)
	var idx1 = 0
	var idx2 = 0
	if new_cell_size > settings.cell_size:
		for row in num_rows:
			for col in num_cols:
				for y in factor:
					for x in factor:
						new_cells[idx2] = cells[idx1]
						idx2 += 1
				idx1 += 1
	else:
		for row in num_rows:
			for col in num_cols:
				var n = 0
				for y in factor:
					for x in factor:
						n += cells[idx1]
						idx1 += 1
				new_cells[idx2] = n
				idx2 += 1
	cells = new_cells


# Expand cells size if area grows
func resize_num_cells(area: Vector2):
	var num_new_cols = int(area.x) / settings.cell_size
	var num_new_rows = int(area.y) / settings.cell_size
	if num_new_cols > num_cols or num_new_rows > num_rows:
		var new_cells = PoolByteArray()
		new_cells.resize(num_new_rows * num_new_cols)
		var idx = 0
		var new_idx = 0
		for row in num_new_rows:
			for col in num_new_cols:
				if row < num_rows and col < num_cols:
					new_cells[new_idx] = cells[idx]
					idx += 1
				else:
					new_cells[new_idx] = 0
				new_idx += 1
		cells = new_cells


func update_cells(x, y, add):
	cells[int(x) / settings.cell_size + num_cols * int(y) / settings.cell_size] = 0xff if add else 0
	update_rects()


func update_rects():
	var rects = get_node("%Image").rects
	var size = Vector2(settings.cell_size, settings.cell_size)
	rects.clear()
	var pos = Vector2.ZERO
	var idx = 0
	for col in num_cols:
		for row in num_rows:
			if cells[idx] > 0:
				rects.append(Rect2(pos, size))
			pos.x += settings.cell_size
			idx += 1
		pos.y += settings.cell_size
		pos.x = 0
	get_node("%Image").update()
