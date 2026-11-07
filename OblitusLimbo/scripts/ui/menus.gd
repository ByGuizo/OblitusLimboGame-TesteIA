class_name Menus
extends CanvasLayer
## Telas: splash, título, capítulos, compêndio, opções, pausa, morte, créditos.

signal act(name: String, arg)

const GOLD := Color("d8b46a")
var f_title: Font
var f_deco: Font
var f_deco_black: Font
var f_serif: Font
var f_italic: Font
var screens := {}
var panel_return := "title"
var btn_continue: Button
var death_quote: Label
var credits_roll: VBoxContainer
var credits_t := 0.0
var opt_widgets := {}

func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	f_title = load("res://assets/fonts/Cinzel.ttf")
	f_deco = load("res://assets/fonts/CinzelDecorative-Bold.ttf")
	f_deco_black = load("res://assets/fonts/CinzelDecorative-Black.ttf")
	f_serif = load("res://assets/fonts/Cormorant.ttf")
	f_italic = load("res://assets/fonts/CormorantItalic.ttf")
	_build_splash()
	_build_title()
	_build_chapters()
	_build_codex()
	_build_options()
	_build_pause()
	_build_death()
	_build_credits()
	_build_versus()
	_build_vs_result()
	hide_all()

# ---------------------------------------------------------------------
#  Utilidades
# ---------------------------------------------------------------------
func _fv(base: Font, spacing := 0, weight := 0) -> Font:
	return UIRoot._fv(base, spacing, weight)

func _lbl(text: String, font: Font, size: int, col: Color, align := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	l.add_theme_constant_override("shadow_offset_y", 3)
	l.add_theme_constant_override("shadow_outline_size", 8)
	l.horizontal_alignment = align
	return l

func _btn(text: String, action: String, arg = null, size := 25) -> Button:
	var b := Button.new()
	b.text = text
	b.flat = true
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.focus_mode = Control.FOCUS_ALL
	b.add_theme_font_override("font", _fv(f_title, 5))
	b.add_theme_font_size_override("font_size", size)
	b.add_theme_color_override("font_color", Color("d8d0c0"))
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_focus_color", Color.WHITE)
	b.add_theme_color_override("font_pressed_color", GOLD)
	b.add_theme_color_override("font_disabled_color", Color(0.85, 0.82, 0.75, 0.3))
	var empty := StyleBoxEmpty.new()
	empty.content_margin_left = 6; empty.content_margin_top = 8; empty.content_margin_bottom = 8
	var hov := StyleBoxEmpty.new()
	hov.content_margin_left = 30; hov.content_margin_top = 8; hov.content_margin_bottom = 8
	b.add_theme_stylebox_override("normal", empty)
	b.add_theme_stylebox_override("hover", hov)
	b.add_theme_stylebox_override("focus", hov)
	b.add_theme_stylebox_override("pressed", hov)
	b.add_theme_stylebox_override("disabled", empty)
	b.draw.connect(func():
		if b.is_hovered() or b.has_focus():
			var y := b.size.y * 0.5
			b.draw_colored_polygon(PackedVector2Array([Vector2(8, y - 6), Vector2(14, y), Vector2(8, y + 6), Vector2(2, y)]), GOLD))
	b.mouse_entered.connect(func(): Audio.sfx("ui", 0.25))
	b.pressed.connect(func():
		Audio.sfx("ui", 0.6)
		act.emit(action, arg))
	return b

func _screen(name: String, bg: Texture2D = null, col := Color(0, 0, 0, 0)) -> Control:
	var c := Control.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_STOP
	if bg:
		var tr := TextureRect.new()
		tr.texture = bg
		tr.set_anchors_preset(Control.PRESET_FULL_RECT)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_SCALE
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		c.add_child(tr)
	elif col.a > 0.0:
		var cr := ColorRect.new()
		cr.color = col
		cr.set_anchors_preset(Control.PRESET_FULL_RECT)
		cr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		c.add_child(cr)
	add_child(c)
	screens[name] = c
	return c

func _panel_title(parent: Control, text: String) -> void:
	var h := _lbl(text, _fv(f_title, 12, 600), 30, GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	h.set_anchors_preset(Control.PRESET_CENTER_TOP)
	h.offset_left = -400; h.offset_right = 400; h.offset_top = 56; h.offset_bottom = 100
	parent.add_child(h)

func _back_btn(parent: Control) -> void:
	var b := _btn("‹  Voltar", "back")
	b.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	b.offset_left = -90; b.offset_right = 120; b.offset_top = -100; b.offset_bottom = -50
	parent.add_child(b)

func hide_all() -> void:
	for k in screens:
		screens[k].visible = false

func show_screen(name: String) -> void:
	screens[name].visible = true
	var first := _first_button(screens[name])
	if first:
		first.grab_focus.call_deferred()

func _first_button(n: Node) -> Button:
	for c in n.get_children():
		if c is Button and c.visible and not c.disabled:
			return c
		var r := _first_button(c)
		if r:
			return r
	return null

func is_open(name: String) -> bool:
	return screens.has(name) and screens[name].visible

func any_panel_open() -> bool:
	return is_open("chapters") or is_open("codex") or is_open("options") or is_open("versus")

# ---------------------------------------------------------------------
#  Splash
# ---------------------------------------------------------------------
func _build_splash() -> void:
	var s := _screen("splash", null, Color.BLACK)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.offset_left = -200; box.offset_right = 200; box.offset_top = -230; box.offset_bottom = 230
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	s.add_child(box)
	box.add_child(_lbl("FEITO POR", _fv(f_title, 10), 16, Color(0.8, 0.76, 0.9), HORIZONTAL_ALIGNMENT_CENTER))
	box.add_child(_lbl("ByGuizo", _fv(f_deco_black, 4), 64, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER))
	box.name = "Box"

func play_splash() -> void:
	var s: Control = screens.splash
	s.visible = true
	var box: Control = s.get_node("Box")
	box.modulate.a = 0.0
	var tw := create_tween().set_ignore_time_scale(true)
	tw.tween_property(box, "modulate:a", 1.0, 0.9)
	tw.tween_interval(2.4)
	tw.tween_property(box, "modulate:a", 0.0, 0.9)
	await tw.finished

# ---------------------------------------------------------------------
#  Título
# ---------------------------------------------------------------------
func _build_title() -> void:
	var g := Gradient.new()
	g.set_color(0, Color(0, 0, 0, 0.82)); g.set_color(1, Color(0, 0, 0, 0.05))
	g.add_point(0.55, Color(0, 0, 0, 0.35))
	var gt := GradientTexture2D.new(); gt.gradient = g; gt.width = 256; gt.height = 8
	var s := _screen("title", gt)
	var v := VBoxContainer.new()
	v.position = Vector2(170, 160)
	v.add_theme_constant_override("separation", 0)
	s.add_child(v)
	var logo := _lbl("OBLITUS\nLIMBO", _fv(f_deco_black, 6), 128, Color("f2ede4"))
	logo.add_theme_constant_override("line_spacing", -28)
	logo.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	logo.add_theme_constant_override("shadow_offset_y", 6)
	v.add_child(logo)
	var sub := _lbl("VOLUME I  ·  DEMO", _fv(f_title, 10), 16, GOLD)
	sub.custom_minimum_size = Vector2(0, 90)
	sub.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	v.add_child(sub)
	v.add_child(_btn("Novo Jogo", "new"))
	btn_continue = _btn("Continuar", "continue")
	v.add_child(btn_continue)
	v.add_child(_btn("Versus", "versus"))
	v.add_child(_btn("Capítulos", "chapters"))
	v.add_child(_btn("Compêndio", "codex"))
	v.add_child(_btn("Opções", "options"))
	v.add_child(_btn("Créditos", "credits"))
	v.add_child(_btn("Sair", "exit"))
	var foot := _lbl("Baseado no livro Oblitus Limbo: Volume I, de ByGuizo", f_italic, 18, Color("857d6c"))
	foot.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	foot.offset_left = 172; foot.offset_top = -60; foot.offset_right = 900; foot.offset_bottom = -30
	s.add_child(foot)

func show_title() -> void:
	hide_all()
	btn_continue.disabled = not (Save.ch > 0 or Save.seg > 0)
	show_screen("title")

# ---------------------------------------------------------------------
#  Capítulos
# ---------------------------------------------------------------------
func _panel_bg() -> GradientTexture2D:
	return UIRoot.radial_tex(Color(0.03, 0.02, 0.04, 0.9), Color(0.01, 0.008, 0.015, 0.97))

func _build_chapters() -> void:
	var s := _screen("chapters", _panel_bg())
	_panel_title(s, "CAPÍTULOS")
	var grid := GridContainer.new()
	grid.name = "Grid"
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 26)
	grid.add_theme_constant_override("v_separation", 26)
	grid.set_anchors_preset(Control.PRESET_CENTER)
	grid.offset_left = -560; grid.offset_right = 560; grid.offset_top = -230; grid.offset_bottom = 260
	s.add_child(grid)
	_back_btn(s)

func fill_chapters(chapters: Array) -> void:
	var grid: GridContainer = screens.chapters.get_node("Grid")
	for c in grid.get_children():
		c.queue_free()
	for i in chapters.size():
		var c: Dictionary = chapters[i]
		var locked := i > Save.unlocked
		var b := Button.new()
		b.custom_minimum_size = Vector2(540, 190)
		b.disabled = locked
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.1, 0.075, 0.09, 0.75)
		sb.border_color = Color(0.79, 0.7, 0.48, 0.45)
		sb.set_border_width_all(1)
		var sh: StyleBoxFlat = sb.duplicate()
		sh.border_color = GOLD
		sh.bg_color = Color(0.16, 0.11, 0.12, 0.85)
		b.add_theme_stylebox_override("normal", sb)
		b.add_theme_stylebox_override("hover", sh)
		b.add_theme_stylebox_override("focus", sh)
		b.add_theme_stylebox_override("pressed", sh)
		b.add_theme_stylebox_override("disabled", sb)
		b.modulate.a = 0.35 if locked else 1.0
		var v := VBoxContainer.new()
		v.set_anchors_preset(Control.PRESET_FULL_RECT)
		v.offset_left = 26; v.offset_top = 22; v.offset_right = -26; v.offset_bottom = -18
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(v)
		for l in [_lbl(c.num, _fv(f_title, 6), 14, GOLD), _lbl(c.name, f_title, 23, Color("f0e6d4")), _lbl("Bloqueado" if locked else c.desc, f_italic, 20, Color("b8ae9a"))]:
			l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			l.mouse_filter = Control.MOUSE_FILTER_IGNORE
			v.add_child(l)
		var idx := i
		b.pressed.connect(func():
			Audio.sfx("uiOk")
			act.emit("chapter", idx))
		grid.add_child(b)

# ---------------------------------------------------------------------
#  Compêndio
# ---------------------------------------------------------------------
func _build_codex() -> void:
	var s := _screen("codex", _panel_bg())
	_panel_title(s, "COMPÊNDIO")
	var sc := ScrollContainer.new()
	sc.set_anchors_preset(Control.PRESET_FULL_RECT)
	sc.offset_left = 120; sc.offset_right = -120; sc.offset_top = 130; sc.offset_bottom = -120
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	s.add_child(sc)
	var grid := GridContainer.new()
	grid.name = "Grid"
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 24)
	grid.add_theme_constant_override("v_separation", 24)
	sc.add_child(grid)
	s.set_meta("grid", grid)
	_back_btn(s)

func fill_codex(entries: Array) -> void:
	var grid: GridContainer = screens.codex.get_meta("grid")
	for c in grid.get_children():
		c.queue_free()
	for e in entries:
		var p := PanelContainer.new()
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.06, 0.045, 0.06, 0.75)
		sb.border_color = Color(0.79, 0.7, 0.48, 0.35)
		sb.set_border_width_all(1)
		sb.set_content_margin_all(14)
		p.add_theme_stylebox_override("panel", sb)
		p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 16)
		p.add_child(h)
		var im := TextureRect.new()
		var tx: Texture2D = load("res://assets/portraits/%s.jpg" % e.img)
		var at := AtlasTexture.new()
		at.atlas = tx
		var ts := tx.get_size()
		var aspect := 120.0 / 160.0
		var w := minf(ts.x, ts.y * aspect)
		var hh := w / aspect
		at.region = Rect2((ts.x - w) * e.pos.x, (ts.y - hh) * e.pos.y, w, hh)
		im.texture = at
		im.custom_minimum_size = Vector2(130, 174)
		im.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		im.stretch_mode = TextureRect.STRETCH_SCALE
		h.add_child(im)
		var v := VBoxContainer.new()
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(v)
		v.add_child(_lbl(e.name, _fv(f_title, 2, 600), 21, GOLD))
		v.add_child(_lbl(e.ep, f_italic, 18, Color("a89e8a")))
		var tx2 := _lbl(e.text, f_serif, 19, Color("d8d0c0"))
		tx2.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		tx2.custom_minimum_size = Vector2(420, 0)
		tx2.add_theme_constant_override("shadow_outline_size", 0)
		v.add_child(tx2)
		grid.add_child(p)

# ---------------------------------------------------------------------
#  Opções
# ---------------------------------------------------------------------
func _build_options() -> void:
	var s := _screen("options", _panel_bg())
	_panel_title(s, "OPÇÕES")
	var sc := ScrollContainer.new()
	sc.set_anchors_preset(Control.PRESET_FULL_RECT)
	sc.offset_left = 0; sc.offset_right = 0; sc.offset_top = 120; sc.offset_bottom = -110
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	s.add_child(sc)
	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(center)
	var v := VBoxContainer.new()
	v.custom_minimum_size = Vector2(760, 0)
	v.add_theme_constant_override("separation", 10)
	center.add_child(v)
	_slider(v, "Volume geral", "master", 0.0, 1.0, 0.05)
	_slider(v, "Música", "music", 0.0, 1.0, 0.05)
	_slider(v, "Efeitos", "sfx", 0.0, 1.0, 0.05)
	_slider(v, "Sensibilidade do mouse", "sens", 0.3, 2.5, 0.05)
	_choice(v, "Qualidade gráfica", "quality", [["Alta", "high"], ["Média", "med"], ["Baixa", "low"]])
	_choice(v, "Dificuldade", "diff", [["História", 0.75], ["Normal", 1.0], ["Pesadelo", 1.35]])
	var chars := []
	for id in Kits.IDS:
		chars.append([String(Kits.info(id).name), id])
	_choice(v, "Personagem da história (teste)", "story_char", chars)
	_check(v, "Tela cheia", "fullscreen")
	_check(v, "V-Sync", "vsync")
	_check(v, "Inverter eixo Y", "invert_y")
	var h2 := _lbl("CONTROLES", _fv(f_title, 12, 600), 26, GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	h2.custom_minimum_size = Vector2(0, 80)
	h2.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	v.add_child(h2)
	var g := GridContainer.new()
	g.columns = 2
	g.add_theme_constant_override("h_separation", 40)
	g.add_theme_constant_override("v_separation", 8)
	v.add_child(g)
	for row in [["W A S D", "Mover"], ["Mouse", "Câmera (sempre livre)"], ["Clique Esq.", "Ataque leve (combo)"], ["Clique Dir.", "Ataque pesado (ramifica / finaliza)"], ["C (segurar)", "Defender · no tempo certo: Aparar"],
			["Espaço", "Esquivar (perfeita = câmera lenta)"], ["Shift", "Correr"], ["Q / Botão do meio", "Travar alvo"], ["1 2 3", "Habilidades"],
			["F", "Ultimate cinematográfico · segure F: Despertar"], ["Enter / Espaço (segurar)", "Pular cena"], ["R / Tab", "Poção"], ["E", "Interagir"], ["Esc", "Pausa"]]:
		var hb := HBoxContainer.new()
		hb.add_theme_constant_override("separation", 10)
		var k := _lbl(row[0], _fv(f_title, 1), 15, Color("f0e8d8"))
		var kb := PanelContainer.new()
		var ks := StyleBoxFlat.new(); ks.bg_color = Color(0.07, 0.07, 0.07); ks.border_color = Color("b8ac90"); ks.set_border_width_all(1); ks.set_corner_radius_all(4)
		ks.content_margin_left = 8; ks.content_margin_right = 8; ks.content_margin_top = 1; ks.content_margin_bottom = 1
		kb.add_theme_stylebox_override("panel", ks)
		kb.add_child(k)
		hb.add_child(kb)
		hb.add_child(_lbl(row[1], f_serif, 20, Color("e8e0d0")))
		g.add_child(hb)
	_back_btn(s)

func _row(parent: Control, label: String) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.custom_minimum_size = Vector2(0, 44)
	var l := _lbl(label, f_serif, 23, Color("ece4d4"))
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(l)
	parent.add_child(h)
	return h

func _slider(parent: Control, label: String, key: String, mn: float, mx: float, step: float) -> void:
	var h := _row(parent, label)
	var s := HSlider.new()
	s.min_value = mn; s.max_value = mx; s.step = step
	s.custom_minimum_size = Vector2(280, 24)
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var gb := StyleBoxFlat.new(); gb.bg_color = Color(0.79, 0.7, 0.48); gb.content_margin_top = 3; gb.content_margin_bottom = 3
	var sb := StyleBoxFlat.new(); sb.bg_color = Color(0.2, 0.18, 0.15); sb.content_margin_top = 3; sb.content_margin_bottom = 3
	s.add_theme_stylebox_override("slider", sb)
	s.add_theme_stylebox_override("grabber_area", gb)
	s.add_theme_stylebox_override("grabber_area_highlight", gb)
	s.value_changed.connect(func(val: float):
		Save.opts[key] = val
		act.emit("option", key))
	h.add_child(s)
	opt_widgets[key] = s

func _choice(parent: Control, label: String, key: String, items: Array) -> void:
	var h := _row(parent, label)
	var o := OptionButton.new()
	o.custom_minimum_size = Vector2(280, 36)
	o.add_theme_font_override("font", f_serif)
	o.add_theme_font_size_override("font_size", 21)
	for i in items.size():
		o.add_item(items[i][0], i)
		o.set_item_metadata(i, items[i][1])
	o.item_selected.connect(func(i: int):
		Save.opts[key] = o.get_item_metadata(i)
		act.emit("option", key))
	h.add_child(o)
	opt_widgets[key] = o

func _check(parent: Control, label: String, key: String) -> void:
	var h := _row(parent, label)
	var c := CheckButton.new()
	c.toggled.connect(func(on: bool):
		Save.opts[key] = on
		act.emit("option", key))
	h.add_child(c)
	opt_widgets[key] = c

func sync_options() -> void:
	for k in opt_widgets:
		var w = opt_widgets[k]
		var v = Save.opts.get(k)
		if w is HSlider:
			w.set_value_no_signal(float(v))
		elif w is OptionButton:
			for i in w.item_count:
				if str(w.get_item_metadata(i)) == str(v):
					w.select(i)
		elif w is CheckButton:
			w.set_pressed_no_signal(bool(v))

# ---------------------------------------------------------------------
#  Pausa / Morte / Créditos
# ---------------------------------------------------------------------
func _build_pause() -> void:
	var s := _screen("pause", null, Color(0, 0, 0, 0.66))
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_CENTER)
	v.offset_left = -220; v.offset_right = 260; v.offset_top = -200; v.offset_bottom = 200
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	s.add_child(v)
	var h := _lbl("PAUSA", _fv(f_title, 14, 600), 34, GOLD, HORIZONTAL_ALIGNMENT_LEFT)
	h.custom_minimum_size = Vector2(0, 80)
	v.add_child(h)
	v.add_child(_btn("Continuar", "resume"))
	btn_pause_restart = _btn("Reiniciar trecho", "restart")
	v.add_child(btn_pause_restart)
	v.add_child(_btn("Opções e Controles", "options"))
	v.add_child(_btn("Voltar ao título", "quit"))

func _build_death() -> void:
	var s := _screen("death", UIRoot.radial_tex(Color(0.24, 0.0, 0.0, 0.5), Color(0, 0, 0, 0.93)))
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_CENTER)
	v.offset_left = -480; v.offset_right = 480; v.offset_top = -220; v.offset_bottom = 240
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 10)
	s.add_child(v)
	var h := _lbl("APAGÃO", _fv(f_deco, 12), 84, Color("b3121e"), HORIZONTAL_ALIGNMENT_CENTER)
	v.add_child(h)
	death_quote = _lbl("", f_italic, 26, Color("c8b8a0"), HORIZONTAL_ALIGNMENT_CENTER)
	death_quote.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	death_quote.custom_minimum_size = Vector2(800, 110)
	v.add_child(death_quote)
	var bb := VBoxContainer.new()
	bb.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	bb.add_child(_btn("Tentar novamente", "retry"))
	bb.add_child(_btn("Voltar ao título", "quit"))
	v.add_child(bb)

func show_death(quote: String) -> void:
	death_quote.text = quote
	var s: Control = screens.death
	s.modulate.a = 0.0
	show_screen("death")
	var tw := create_tween().set_ignore_time_scale(true)
	tw.tween_property(s, "modulate:a", 1.0, 1.5)

func _build_credits() -> void:
	var s := _screen("credits", null, Color.BLACK)
	s.clip_contents = true
	credits_roll = VBoxContainer.new()
	credits_roll.alignment = BoxContainer.ALIGNMENT_BEGIN
	credits_roll.add_theme_constant_override("separation", 6)
	s.add_child(credits_roll)
	var add := func(kind: String, text: String):
		var l: Label
		match kind:
			"big": l = _lbl(text, f_deco, 64, Color("f0e8dc"), HORIZONTAL_ALIGNMENT_CENTER)
			"mid": l = _lbl(text, f_deco, 42, Color("f0e8dc"), HORIZONTAL_ALIGNMENT_CENTER)
			"h": l = _lbl(text, _fv(f_title, 10), 17, GOLD, HORIZONTAL_ALIGNMENT_CENTER)
			"i": l = _lbl(text, f_italic, 27, Color("e0d8c8"), HORIZONTAL_ALIGNMENT_CENTER)
			"gap": l = _lbl("", f_serif, 30, Color.WHITE)
			_: l = _lbl(text, f_serif, 27, Color("e0d8c8"), HORIZONTAL_ALIGNMENT_CENTER)
		if kind == "h":
			l.custom_minimum_size = Vector2(0, 80)
			l.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		credits_roll.add_child(l)
	for row in [["big", "OBLITUS LIMBO"], ["i", "Volume I — Demo"],
			["h", "CRIADO POR"], ["p", "ByGuizo"],
			["h", "BASEADO NA OBRA DE"], ["p", "Guilherme O. Silva (ByGuizo)"],
			["h", "PERSONAGENS"], ["p", "Kiana · Near Shade · Amnon Akmenos · Darin Leafheart"], ["p", "Viktor Vanshee · Calista Vanshee"], ["p", "Lorde Krauser · Darius · Velha Mira · Rurik"],
			["h", "MÚSICA"], ["p", "“O Alvorecer da Ausência” — tema de Kiana"], ["p", "Trilha sintetizada proceduralmente"],
			["h", "ARTE"], ["p", "Ilustrações dos personagens: material original do livro"], ["p", "Modelos 3D: Quaternius (Universal Animation Library, Modular Outfits, Medieval Village, Stylized Nature)"], ["p", "KayKit (Dungeon Remastered, Fantasy Weapons) — Kay Lousberg"], ["p", "Texturas pintadas à mão: Lynocs — Stylized Texture Pack (CC0)"], ["p", "Fonte de pincel: Kaushan Script — Impallari Type (OFL)"], ["p", "Cabeças, cabelos, tecidos, shaders e efeitos feitos à mão em código"],
			["h", "MOTOR"], ["p", "Godot Engine 4"],
			["h", "AGRADECIMENTOS"], ["p", "Aqueles Que Sabem"],
			["gap", ""], ["gap", ""], ["i", "“O tempo não cura todas as feridas,"], ["i", "mas nos ensina a construir algo novo sobre as cicatrizes.”"],
			["gap", ""], ["gap", ""], ["h", "CONTINUA EM"], ["mid", "OBLITUS LIMBO: VOLUME II"]]:
		add.call(row[0], row[1])
	s.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed:
			credits_t = 999.0)

func play_credits() -> void:
	hide_all()
	var s: Control = screens.credits
	s.visible = true
	await get_tree().process_frame
	var vs := get_viewport().get_visible_rect().size
	credits_roll.size = Vector2(vs.x, 0)
	credits_roll.reset_size()
	credits_roll.size.x = vs.x
	var total := credits_roll.get_combined_minimum_size().y
	credits_t = 0.0
	var dur := 48.0
	while credits_t < dur:
		await get_tree().process_frame
		credits_t += Game.real_dt()
		credits_roll.position = Vector2(0, vs.y - (vs.y + total) * (credits_t / dur))
	s.visible = false

# ---------------------------------------------------------------------
#  Modo Versus: seleção de lutadores e resultado
# ---------------------------------------------------------------------
const VS_FIGHTERS := Kits.IDS
const VS_ARENAS := ["throne", "tavern", "valley", "domain", "limbo"]
const VS_DIFFS := [["Fácil", "easy"], ["Normal", "normal"], ["Difícil", "hard"]]
const VS_ROUNDS := [["Melhor de 3", 2], ["Rodada única", 1], ["Melhor de 5", 3]]
const VS_PORTRAIT := {"kiana": Vector2(0.55, 0.2), "viktor": Vector2(0.5, 0.1), "near": Vector2(0.5, 0.25), "darin": Vector2(0.5, 0.15),
	"amnon": Vector2(0.45, 0.3), "calista": Vector2(0.45, 0.18), "krauser": Vector2(0.45, 0.08), "yuto": Vector2(0.5, 0.12)}
var vs_cfg := {"p1": "kiana", "cpu": "viktor", "arena": "throne", "diff": "normal", "rounds": 2}
var vs_widgets := {}
var vs_result_title: Label
var vs_result_score: Label
var btn_pause_restart: Button

func set_pause_versus(on: bool) -> void:
	if btn_pause_restart:
		btn_pause_restart.text = "Reiniciar luta" if on else "Reiniciar trecho"

func _vs_portrait(id: String) -> AtlasTexture:
	var tx: Texture2D = load("res://assets/portraits/%s.jpg" % id)
	var at := AtlasTexture.new()
	at.atlas = tx
	var ts := tx.get_size()
	var aspect := 300.0 / 420.0
	var w := minf(ts.x, ts.y * aspect)
	var hh := w / aspect
	var pp: Vector2 = VS_PORTRAIT.get(id, Vector2(0.5, 0.2))
	at.region = Rect2((ts.x - w) * pp.x, (ts.y - hh) * pp.y, w, hh)
	return at

## Seletor ◀ valor ▶
func _cycler(parent: Control, key: String, values: Array, label_of: Callable, width := 380.0) -> void:
	var h := HBoxContainer.new()
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_theme_constant_override("separation", 8)
	parent.add_child(h)
	var lbl := _lbl("", _fv(f_title, 3, 600), 22, Color("f0ecff"), HORIZONTAL_ALIGNMENT_CENTER)
	lbl.custom_minimum_size = Vector2(width, 40)
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var mk := func(txt: String, step: int) -> Button:
		var b := Button.new()
		b.text = txt
		b.flat = true
		b.focus_mode = Control.FOCUS_ALL
		b.add_theme_font_override("font", _fv(f_title, 0, 700))
		b.add_theme_font_size_override("font_size", 24)
		b.add_theme_color_override("font_color", Color(0.72, 0.64, 1.0))
		b.add_theme_color_override("font_hover_color", Color.WHITE)
		b.add_theme_color_override("font_focus_color", Color.WHITE)
		b.pressed.connect(func():
			var i: int = values.find(vs_cfg[key])
			i = (i + step + values.size()) % values.size()
			vs_cfg[key] = values[i]
			Audio.sfx("ui", 0.6)
			_vs_refresh())
		return b
	h.add_child(mk.call("◀", -1))
	h.add_child(lbl)
	h.add_child(mk.call("▶", 1))
	vs_widgets[key] = [lbl, label_of]

func _build_versus() -> void:
	var s := _screen("versus", UIRoot.radial_tex(Color(0.12, 0.05, 0.22, 0.94), Color(0.015, 0.005, 0.03, 0.99)))
	var h := _lbl("MODO VERSUS", _fv(f_title, 12, 600), 34, Color(0.72, 0.64, 1.0), HORIZONTAL_ALIGNMENT_CENTER)
	h.set_anchors_preset(Control.PRESET_CENTER_TOP)
	h.offset_left = -400; h.offset_right = 400; h.offset_top = 40; h.offset_bottom = 90
	s.add_child(h)
	var sub := _lbl("1 jogador contra a CPU", f_italic, 22, Color(0.8, 0.76, 0.9), HORIZONTAL_ALIGNMENT_CENTER)
	sub.set_anchors_preset(Control.PRESET_CENTER_TOP)
	sub.offset_left = -400; sub.offset_right = 400; sub.offset_top = 90; sub.offset_bottom = 120
	s.add_child(sub)
	var root := HBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_CENTER)
	root.offset_left = -820; root.offset_right = 820; root.offset_top = -330; root.offset_bottom = 250
	root.alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_theme_constant_override("separation", 40)
	s.add_child(root)
	for side in ["p1", "cpu"]:
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 10)
		col.alignment = BoxContainer.ALIGNMENT_CENTER
		root.add_child(col)
		var tag := _lbl("VOCÊ" if side == "p1" else "CPU", _fv(f_title, 10, 700), 20, Color(0.72, 0.64, 1.0) if side == "p1" else Color(1, 0.4, 0.5), HORIZONTAL_ALIGNMENT_CENTER)
		col.add_child(tag)
		var frame := PanelContainer.new()
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.05, 0.02, 0.08, 0.9)
		sb.border_color = Color(0.72, 0.64, 1.0, 0.8) if side == "p1" else Color(1, 0.35, 0.45, 0.8)
		sb.set_border_width_all(2)
		frame.add_theme_stylebox_override("panel", sb)
		col.add_child(frame)
		var im := TextureRect.new()
		im.custom_minimum_size = Vector2(300, 420)
		im.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		im.stretch_mode = TextureRect.STRETCH_SCALE
		frame.add_child(im)
		vs_widgets[side + "_img"] = im
		_cycler(col, side, VS_FIGHTERS, func(v): return String(Versus.fighter(v).name).to_upper(), 300.0)
		var ttl := _lbl("", f_italic, 20, Color(0.8, 0.76, 0.9), HORIZONTAL_ALIGNMENT_CENTER)
		col.add_child(ttl)
		vs_widgets[side + "_title"] = ttl
		if side == "p1":
			# centro: arena, dificuldade, rounds e LUTAR
			var mid := VBoxContainer.new()
			mid.alignment = BoxContainer.ALIGNMENT_CENTER
			mid.add_theme_constant_override("separation", 14)
			mid.custom_minimum_size = Vector2(520, 0)
			root.add_child(mid)
			var vs := _lbl("VS", _fv(f_deco_black, 4), 96, Color(1, 0.97, 1), HORIZONTAL_ALIGNMENT_CENTER)
			mid.add_child(vs)
			mid.add_child(_lbl("ARENA", _fv(f_title, 8, 600), 15, Color(0.72, 0.64, 1.0), HORIZONTAL_ALIGNMENT_CENTER))
			_cycler(mid, "arena", VS_ARENAS, func(v): return Versus.ARENAS[v].name, 420.0)
			mid.add_child(_lbl("DIFICULDADE DA CPU", _fv(f_title, 8, 600), 15, Color(0.72, 0.64, 1.0), HORIZONTAL_ALIGNMENT_CENTER))
			_cycler(mid, "diff", VS_DIFFS.map(func(x): return x[1]), _vs_name.bind(VS_DIFFS), 300.0)
			mid.add_child(_lbl("PARTIDA", _fv(f_title, 8, 600), 15, Color(0.72, 0.64, 1.0), HORIZONTAL_ALIGNMENT_CENTER))
			_cycler(mid, "rounds", VS_ROUNDS.map(func(x): return x[1]), _vs_name.bind(VS_ROUNDS), 300.0)
			var go := _btn("LUTAR!", "versus_go_btn", null, 34)
			go.alignment = HORIZONTAL_ALIGNMENT_CENTER
			go.custom_minimum_size = Vector2(0, 70)
			go.pressed.connect(func(): act.emit("versus_go", vs_cfg.duplicate()))
			mid.add_child(go)
			vs_widgets["go"] = go
	var help := _lbl("Shift: investida de chakra   ·   Espaço apanhando: Substituição   ·   Segure R: carregar chakra   ·   F: Ultimate", f_serif, 20, Color(0.82, 0.78, 0.92), HORIZONTAL_ALIGNMENT_CENTER)
	help.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	help.offset_left = -800; help.offset_right = 800; help.offset_top = -150; help.offset_bottom = -115
	s.add_child(help)
	_back_btn(s)

func _vs_name(v, table: Array) -> String:
	for x in table:
		if x[1] == v:
			return x[0]
	return str(v)

func _vs_refresh() -> void:
	for k in ["p1", "cpu", "arena", "diff", "rounds"]:
		if vs_widgets.has(k):
			var w: Array = vs_widgets[k]
			(w[0] as Label).text = String(w[1].call(vs_cfg[k]))
	for side in ["p1", "cpu"]:
		var id: String = vs_cfg[side]
		var im: TextureRect = vs_widgets[side + "_img"]
		im.texture = _vs_portrait(id)
		im.modulate = Color(0.85, 0.72, 1.0) if side == "cpu" and vs_cfg.p1 == vs_cfg.cpu else Color.WHITE
		(vs_widgets[side + "_title"] as Label).text = Versus.fighter(id).title

func show_versus_select() -> void:
	_vs_refresh()
	show_screen("versus")
	(vs_widgets.go as Button).grab_focus.call_deferred()

func _build_vs_result() -> void:
	var s := _screen("vs_result", UIRoot.radial_tex(Color(0.1, 0.03, 0.18, 0.55), Color(0, 0, 0, 0.9)))
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_CENTER)
	v.offset_left = -480; v.offset_right = 480; v.offset_top = -260; v.offset_bottom = 260
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 10)
	s.add_child(v)
	vs_result_title = _lbl("VITÓRIA", _fv(f_deco_black, 8), 96, Color(0.72, 0.64, 1.0), HORIZONTAL_ALIGNMENT_CENTER)
	v.add_child(vs_result_title)
	vs_result_score = _lbl("2 — 0", _fv(f_title, 10, 600), 30, Color("f0ecff"), HORIZONTAL_ALIGNMENT_CENTER)
	vs_result_score.custom_minimum_size = Vector2(0, 80)
	v.add_child(vs_result_score)
	var bb := VBoxContainer.new()
	bb.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var re := _btn("Revanche", "rematch_btn")
	re.pressed.connect(func(): act.emit("rematch", vs_cfg.duplicate()))
	bb.add_child(re)
	bb.add_child(_btn("Trocar lutadores", "versus_change"))
	bb.add_child(_btn("Voltar ao título", "quit"))
	v.add_child(bb)

func show_versus_result(won: bool, wins: Array, cfg: Dictionary) -> void:
	vs_cfg = cfg.duplicate()
	vs_result_title.text = "VITÓRIA" if won else "DERROTA"
	vs_result_title.add_theme_color_override("font_color", Color(0.72, 0.64, 1.0) if won else Color(0.85, 0.15, 0.25))
	var a: String = Versus.fighter(cfg.p1).name
	var b: String = Versus.fighter(cfg.cpu).name
	vs_result_score.text = "%s  %d  —  %d  %s (CPU)" % [a, wins[0], wins[1], b]
	var s: Control = screens.vs_result
	s.modulate.a = 0.0
	show_screen("vs_result")
	var tw := create_tween().set_ignore_time_scale(true)
	tw.tween_property(s, "modulate:a", 1.0, 0.6)
