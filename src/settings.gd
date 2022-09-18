extends Resource

class_name Settings

const FILENAME = "user://settings.res"

export var load_dir = ""
export var save_dir = ""
export var similarity = 0.0
export var proximity = 1 # Width of capture square
export var target_color = Color.white
export var replacement_color = Color.green

func save_data():
	var _e = ResourceSaver.save(FILENAME, self)


func load_data():
	if ResourceLoader.exists(FILENAME):
		return ResourceLoader.load(FILENAME)
	else:
		load_dir = OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS)
		save_dir = load_dir
		return self
