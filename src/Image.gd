extends TextureRect

var rects = []

func _draw():
	for rect in rects:
		draw_rect(rect, Color(0, 1.0, 0, 0.5), true)
