extends TextureRect

var rects = []
var rect_color = Color(0, 1.0, 0, 0.5)
var marker_rect: Rect2
var marker_color: Color

func _draw():
	for rect in rects:
		draw_rect(rect, rect_color, true)
	marker_color.a = 0.7
	draw_rect(marker_rect, marker_color, false, 2.0)
