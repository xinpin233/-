extends Control
## Paper desk, film perforations and read-only shot position indicators.

var desk: Control
var active_stage := 0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	desk = get_parent()
	desk.resized.connect(queue_redraw)
	call_deferred("_connect_film")

func _connect_film() -> void:
	desk.get_node("%Film").resized.connect(queue_redraw)
	desk.get_node("%Film").item_rect_changed.connect(queue_redraw)
	queue_redraw()

func set_stage(value: int) -> void:
	if active_stage != value:
		active_stage = value
		queue_redraw()

func _draw() -> void:
	if not is_instance_valid(desk): return
	draw_rect(Rect2(Vector2.ZERO, desk.size), SoundGameTheme.PAPER)
	var film: Control = desk.get_node("%Film")
	var rect := Rect2(film.global_position - desk.global_position, film.size)
	var surround := Rect2(rect.position - Vector2(12, 40), rect.size + Vector2(24, 80))
	draw_rect(Rect2(surround.position + Vector2(12, 12), surround.size), Color("aaa79e"))
	draw_rect(surround, SoundGameTheme.INK)
	var count := maxi(1, int(rect.size.x / 36.0))
	for index in count:
		var x := rect.position.x + 10 + index * ((rect.size.x - 28) / maxf(1, count - 1))
		for y in [rect.position.y - 20, rect.end.y + 20]:
			draw_rect(Rect2(x, y - 5, 16, 10), SoundGameTheme.PAPER)
	var font := ThemeDB.fallback_font
	var shot_count: int = desk.level.clips.size() if desk.level != null else 0
	for index in shot_count:
		var square := Rect2(surround.position.x - 88, surround.position.y + 48 + index * 62, 50, 50)
		draw_rect(square, SoundGameTheme.RED if index == active_stage else SoundGameTheme.INK)
		var numeral: String = ["I", "II", "III", "IV", "V"][index] if index < 5 else str(index + 1)
		var width := font.get_string_size(numeral, HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x
		draw_string(font, square.position + Vector2((50 - width) / 2, 31), numeral, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, SoundGameTheme.PAPER)
