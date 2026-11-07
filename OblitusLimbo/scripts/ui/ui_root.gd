class_name UIRoot
extends CanvasLayer
## Interface do jogo (porte de ui.js + index.html): HUD desenhado em _draw (retrato em losango,
## barras, minimapa, habilidades, chefe, números de dano, avisos), diálogos com retratos,
## cartões de capítulo/diário/memória, letterbox e fade.

const GOLD := Color("b9a2ff")
const GOLD2 := Color("efe9ff")
const GOLD_LINE := Color(0.72, 0.64, 1.0)
const LILAC := Color("b9a2ff")
const WHITE := Color("f4f0ff")
const TEXT := Color("ece4d4")
const PANEL := Color(0.03, 0.025, 0.04, 0.9)

const PORTRAITS := {
	"kiana": {"img": "kiana", "pos": Vector2(0.54, 0.2), "size": 2.3, "name": "Kiana"},
	"near": {"img": "near", "pos": Vector2(0.5, 0.22), "size": 2.4, "name": "Near Shade"},
	"amnon": {"img": "amnon", "pos": Vector2(0.45, 0.28), "size": 1.9, "name": "Amnon Akmenos"},
	"darin": {"img": "darin", "pos": Vector2(0.5, 0.15), "size": 2.2, "name": "Darin Leafheart"},
	"calista": {"img": "calista", "pos": Vector2(0.42, 0.18), "size": 2.2, "name": "Calista Vanshee"},
	"viktor": {"img": "viktor", "pos": Vector2(0.5, 0.08), "size": 3.0, "name": "Viktor Vanshee"},
	"krauser": {"img": "krauser", "pos": Vector2(0.5, 0.22), "size": 2.4, "name": "Lorde Krauser"},
	"yuto": {"img": "yuto", "pos": Vector2(0.52, 0.15), "size": 2.8, "name": "Yuto"},
}
const NAMES := {"krauser": "Lorde Krauser", "darius": "Darius", "mira": "Velha Mira", "rurik": "Rurik", "presenca": "A Presença",
	"segunda": "A Segunda", "lanis": "Tia Lanis", "emma": "Emma", "gyotto": "Gyotto", "voz": "???", "mascarado": "O Mascarado",
	"capanga": "Capanga", "narr": ""}

# fontes
var f_title: Font
var f_title_b: Font
var f_deco: Font
var f_serif: Font
var f_italic: Font
var tex := {}

# nós
var hud: Control
var hud_on := false
var lb_top: ColorRect
var lb_bot: ColorRect
var fade_rect: ColorRect
var dlg_root: Control
var dlg_portrait: TextureRect
var dlg_pframe: Panel
var dlg_name: Label
var dlg_text: RichTextLabel
var dlg_hint: Label
var card_root: Control
var card_bg: TextureRect
var card_labels := {}
var card_rule: TextureRect
var card_skip: Label
var bark_lbl: RichTextLabel
var prompt_box: PanelContainer
var prompt_lbl: RichTextLabel
var quest_title: Label
var quest_obj: Label
var quest_box: Control
var quest_done_flag := false
var quest_flash := 0.0
var load_root: Control
var load_lbl: Label

# estado
var player = null
var boss_actor = null
var hp_lag := 1.0
var boss_lag := 1.0
var dn: Array = []
var toasts: Array = []
var kill_txt := ""
var flashes := [0.0, 0.0, 0.0, 0.0, 0.0]
var bark_t := 0.0
var dlg = null
var card_p = null
var cine_on := false
var skip_hold := 0.0
var skip_ui: Control
var cutin_ui: Control
var cutin_t := -1.0
var cutin_dur := 1.0
var cutin_name := ""
var cutin_kit := "kiana"
var cutin_col := Color(1, 0.1, 0.2)
var f_brush: Font
signal cutin_done
var lb_h := 0.0
var t := 0.0
# Versus: faixa de anúncio (ROUND / LUTEM! / K.O.) e rastro da vida do CPU
var vb_text := ""
var vb_sub := ""
var vb_t := -1.0
var vb_dur := 1.0
var vb_col := Color(0.72, 0.6, 1.0)
var vb_y := 0.44
var p2_lag := 1.0

signal dialogue_done
signal card_done

func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	f_title = load("res://assets/fonts/Cinzel.ttf")
	f_title_b = _fv(f_title, 0, 700)
	f_deco = load("res://assets/fonts/CinzelDecorative-Bold.ttf")
	f_serif = load("res://assets/fonts/Cormorant.ttf")
	f_italic = load("res://assets/fonts/CormorantItalic.ttf")
	for n in ["blade", "wave", "blink", "spear", "forest", "blackice", "fury", "harmonic", "punch", "potion", "skull"]:
		tex[n] = load("res://assets/icons/%s.svg" % n)
	for n in PORTRAITS:
		tex["p_" + n] = load("res://assets/portraits/%s.jpg" % n)
	_build()

static var _fv_cache := {}
static func _fv(base: Font, spacing := 0, weight := 0) -> FontVariation:
	var key := "%s|%d|%d" % [base.resource_path, spacing, weight]
	if _fv_cache.has(key):
		return _fv_cache[key]
	var f := FontVariation.new()
	_fv_cache[key] = f
	f.base_font = base
	f.spacing_glyph = spacing
	if weight > 0:
		f.variation_opentype = {"wght": weight}
	return f

func _label(text: String, font: Font, size: int, col: Color, align := HORIZONTAL_ALIGNMENT_LEFT, shadow := true) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	if shadow:
		l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
		l.add_theme_constant_override("shadow_offset_x", 0)
		l.add_theme_constant_override("shadow_offset_y", 2)
		l.add_theme_constant_override("shadow_outline_size", 6)
	l.horizontal_alignment = align
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

func _rich(size: int, align := HORIZONTAL_ALIGNMENT_LEFT) -> RichTextLabel:
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = true
	r.scroll_active = false
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.add_theme_font_override("normal_font", f_serif)
	r.add_theme_font_override("italics_font", f_italic)
	r.add_theme_font_override("bold_font", _fv(f_title, 2, 600))
	r.add_theme_font_size_override("normal_font_size", size)
	r.add_theme_font_size_override("italics_font_size", size)
	r.add_theme_font_size_override("bold_font_size", int(size * 0.72))
	r.add_theme_color_override("default_color", TEXT)
	r.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	r.add_theme_constant_override("shadow_offset_y", 2)
	r.add_theme_constant_override("shadow_outline_size", 8)
	r.horizontal_alignment = align
	return r

func _full(c: Control) -> Control:
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c

func _build() -> void:
	# HUD (desenho próprio)
	hud = _full(Control.new())
	hud.draw.connect(_draw_hud)
	hud.modulate.a = 0.0
	add_child(hud)
	# rastreador de missão
	quest_box = Control.new()
	quest_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	quest_box.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	quest_box.offset_left = -390; quest_box.offset_right = -30; quest_box.offset_top = 272; quest_box.offset_bottom = 372
	hud.add_child(quest_box)
	quest_title = _label("", _fv(f_title, 1, 600), 22, GOLD)
	quest_title.position = Vector2(30, 6)
	quest_title.size = Vector2(320, 30)
	quest_box.add_child(quest_title)
	quest_obj = _label("", f_serif, 22, Color("efe7d6"))
	quest_obj.position = Vector2(54, 38)
	quest_obj.size = Vector2(300, 30)
	quest_obj.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	quest_box.add_child(quest_obj)
	quest_box.visible = false     # o objetivo é desenhado direto no HUD (canto superior esquerdo)
	# fala curta (bark)
	bark_lbl = _rich(28, HORIZONTAL_ALIGNMENT_CENTER)
	bark_lbl.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	bark_lbl.offset_left = -520; bark_lbl.offset_right = 520; bark_lbl.offset_top = -240; bark_lbl.offset_bottom = -160
	bark_lbl.modulate.a = 0.0
	add_child(bark_lbl)
	# prompt de interação
	prompt_box = PanelContainer.new()
	var ps := StyleBoxFlat.new()
	ps.bg_color = Color(0, 0, 0, 0.62)
	ps.border_color = Color(0.72, 0.64, 1.0, 0.65)
	ps.set_border_width_all(1)
	ps.content_margin_left = 22; ps.content_margin_right = 22; ps.content_margin_top = 8; ps.content_margin_bottom = 10
	prompt_box.add_theme_stylebox_override("panel", ps)
	prompt_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	prompt_box.visible = false
	add_child(prompt_box)
	prompt_lbl = _rich(22)
	prompt_lbl.add_theme_font_override("normal_font", _fv(f_title, 2, 500))
	prompt_lbl.autowrap_mode = TextServer.AUTOWRAP_OFF
	prompt_box.add_child(prompt_lbl)
	# letterbox
	lb_top = ColorRect.new(); lb_top.color = Color.BLACK; lb_top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lb_bot = ColorRect.new(); lb_bot.color = Color.BLACK; lb_bot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(lb_top); add_child(lb_bot)
	_build_dialogue()
	fade_rect = _full(ColorRect.new())
	fade_rect.color = Color.BLACK
	fade_rect.modulate.a = 0.0
	add_child(fade_rect)
	_build_card()
	cutin_ui = _full(Control.new())
	cutin_ui.draw.connect(func():
		_draw_banner()
		_draw_cutin())
	add_child(cutin_ui)
	if ResourceLoader.exists("res://assets/fonts/KaushanScript-Regular.ttf"):
		f_brush = load("res://assets/fonts/KaushanScript-Regular.ttf")
	else:
		f_brush = f_deco
	skip_ui = _full(Control.new())
	skip_ui.draw.connect(_draw_skip)
	add_child(skip_ui)
	# tela de carregamento
	load_root = _full(ColorRect.new())
	(load_root as ColorRect).color = Color.BLACK
	load_root.visible = false
	add_child(load_root)
	var sp := Control.new()
	sp.set_anchors_preset(Control.PRESET_CENTER)
	sp.draw.connect(func():
		var a := t * 2.2
		var pts := PackedVector2Array()
		for k in 5:
			var ang := a + k * PI * 0.5
			pts.append(Vector2(cos(ang), sin(ang)) * 30.0)
		sp.draw_polyline(pts, GOLD_LINE, 1.5, true))
	sp.offset_top = -20; sp.offset_bottom = -20
	load_root.add_child(sp)
	load_lbl = _label("CARREGANDO", _fv(f_title, 8), 16, GOLD, HORIZONTAL_ALIGNMENT_CENTER, false)
	load_lbl.set_anchors_preset(Control.PRESET_CENTER)
	load_lbl.offset_left = -450; load_lbl.offset_right = 450; load_lbl.offset_top = 40; load_lbl.offset_bottom = 70
	load_root.add_child(load_lbl)

func _build_dialogue() -> void:
	dlg_root = Control.new()
	dlg_root.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	dlg_root.offset_left = -620; dlg_root.offset_right = 620; dlg_root.offset_top = -330; dlg_root.offset_bottom = -30
	dlg_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dlg_root.visible = false
	add_child(dlg_root)
	dlg_pframe = Panel.new()
	var fs := StyleBoxFlat.new()
	fs.bg_color = Color(0.04, 0.035, 0.05)
	fs.border_color = GOLD_LINE
	fs.set_border_width_all(2)
	fs.shadow_color = Color(0, 0, 0, 0.7); fs.shadow_size = 16
	dlg_pframe.add_theme_stylebox_override("panel", fs)
	dlg_pframe.position = Vector2(0, 0)
	dlg_pframe.size = Vector2(220, 280)
	dlg_root.add_child(dlg_pframe)
	dlg_portrait = TextureRect.new()
	dlg_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	dlg_portrait.stretch_mode = TextureRect.STRETCH_SCALE
	dlg_portrait.position = Vector2(2, 2)
	dlg_portrait.size = Vector2(216, 276)
	dlg_pframe.add_child(dlg_portrait)
	var box := Panel.new()
	var bs := StyleBoxFlat.new()
	bs.bg_color = Color(0.03, 0.015, 0.06, 0.92)
	bs.border_color = Color(0.72, 0.64, 1.0, 0.55)
	bs.set_border_width_all(1)
	bs.shadow_color = Color(0, 0, 0, 0.7); bs.shadow_size = 24
	box.add_theme_stylebox_override("panel", bs)
	box.name = "Box"
	box.position = Vector2(248, 90)
	box.size = Vector2(992, 190)
	dlg_root.add_child(box)
	var corner := Control.new()
	corner.draw.connect(func():
		corner.draw_line(Vector2(0, 0), Vector2(44, 0), GOLD, 2)
		corner.draw_line(Vector2(0, 0), Vector2(0, 44), GOLD, 2))
	box.add_child(corner)
	dlg_name = _label("", _fv(f_title, 4, 600), 20, GOLD)
	dlg_name.position = Vector2(32, 18)
	box.add_child(dlg_name)
	dlg_text = _rich(29)
	dlg_text.position = Vector2(32, 52)
	dlg_text.size = Vector2(930, 120)
	dlg_text.fit_content = false
	dlg_text.add_theme_constant_override("line_separation", 2)
	box.add_child(dlg_text)
	dlg_hint = _label("CLIQUE OU ESPAÇO ▸", _fv(f_title, 4), 13, Color("a89a7a"), HORIZONTAL_ALIGNMENT_RIGHT, false)
	dlg_hint.position = Vector2(600, 160)
	dlg_hint.size = Vector2(370, 20)
	box.add_child(dlg_hint)

func _build_card() -> void:
	card_root = _full(Control.new())
	card_root.modulate.a = 0.0
	card_root.visible = false
	add_child(card_root)
	card_bg = _full(TextureRect.new())
	card_bg.stretch_mode = TextureRect.STRETCH_SCALE
	card_bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	card_root.add_child(card_bg)
	var vb := VBoxContainer.new()
	vb.set_anchors_preset(Control.PRESET_FULL_RECT)
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 14)
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.offset_left = 180; vb.offset_right = -180
	card_root.add_child(vb)
	card_labels.c1 = _label("", _fv(f_title, 10), 17, GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	card_labels.c2 = _label("", f_deco, 62, Color("f3e9d6"), HORIZONTAL_ALIGNMENT_CENTER)
	card_labels.c2.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	card_rule = TextureRect.new()
	var g := Gradient.new()
	g.set_color(0, Color(GOLD, 0.0)); g.set_color(1, Color(GOLD, 0.0)); g.add_point(0.5, GOLD)
	var gt := GradientTexture2D.new(); gt.gradient = g; gt.width = 256; gt.height = 2
	card_rule.texture = gt
	card_rule.custom_minimum_size = Vector2(260, 1)
	card_rule.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	card_rule.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	card_labels.c3 = _label("", f_italic, 31, Color("d6cbb6"), HORIZONTAL_ALIGNMENT_CENTER)
	card_labels.c3.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	card_labels.c4 = _label("", _fv(f_title, 4), 16, Color("8a8272"), HORIZONTAL_ALIGNMENT_CENTER)
	vb.add_child(card_labels.c1)
	vb.add_child(card_labels.c2)
	vb.add_child(card_rule)
	vb.add_child(card_labels.c3)
	vb.add_child(card_labels.c4)
	card_skip = _label("", _fv(f_title, 4), 13, Color("7a7262"), HORIZONTAL_ALIGNMENT_RIGHT, false)
	card_skip.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	card_skip.offset_left = -500; card_skip.offset_right = -60; card_skip.offset_top = -60; card_skip.offset_bottom = -40
	card_root.add_child(card_skip)

static func radial_tex(inner: Color, outer: Color) -> GradientTexture2D:
	var g := Gradient.new()
	g.set_color(0, inner); g.set_color(1, outer)
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.05, 0.5)
	gt.width = 256; gt.height = 256
	return gt

# =====================================================================
#  API
# =====================================================================
func show_hud(on: bool) -> void:
	hud_on = on
	var tw := create_tween().set_ignore_time_scale(true)
	tw.tween_property(hud, "modulate:a", 1.0 if on else 0.0, 0.5)

func cine(on: bool) -> void:
	cine_on = on
	show_hud(not on and Game.player != null and is_instance_valid(Game.player))

func set_player(p) -> void:
	player = p
	hp_lag = 1.0

func skill_flash(i: int) -> void:
	if i >= 0 and i < flashes.size():
		flashes[i] = 0.15

func quest(title, obj: String) -> void:
	if title != null:
		quest_title.text = String(title)
	quest_obj.text = obj
	quest_obj.visible = obj != ""
	quest_done_flag = false
	quest_flash = 1.4
	if obj != "":
		Audio.sfx("uiOk", 0.5)

func quest_done() -> void:
	quest_done_flag = true

func boss(b) -> void:
	boss_actor = b
	if b:
		boss_lag = b.hp / b.max_hp

func kill_count(txt: String) -> void:
	kill_txt = txt

func toast(text: String, col := Color.WHITE, dur := 1.2, big := false) -> void:
	toasts.append({"text": text, "col": col, "dur": dur + 0.4, "t": 0.0, "big": big})
	while toasts.size() > 3:
		toasts.pop_front()

func bark(who: String, text: String, dur := 3.0) -> void:
	var nm := _name_of(who)
	bark_lbl.text = ("[b][color=#d8b46a]%s[/color][/b]   " % nm.to_upper() if nm != "" else "") + _em(text)
	bark_lbl.modulate.a = 1.0
	bark_t = dur

func prompt(txt: String) -> void:
	if txt == "" or txt == null:
		prompt_box.visible = false
		return
	var s := txt
	if s.begins_with("[E]"):
		s = "[color=#f3e6c4][b] E [/b][/color]  " + s.substr(3).strip_edges()
	prompt_lbl.text = s
	prompt_box.visible = true

func damage_number(pos: Vector3, amount: float, crit := false, is_player := false, col = null) -> void:
	if amount <= 0.0:
		return
	dn.append({"pos": pos + Vector3(randf_range(-0.3, 0.3), 0, randf_range(-0.3, 0.3)), "t": 0.0, "vy": 1.4 + randf(), "amt": int(round(amount)), "crit": crit, "pl": is_player, "col": col})
	if dn.size() > 40:
		dn.pop_front()

func loading(on: bool, label := "CARREGANDO") -> void:
	load_root.visible = on
	load_lbl.text = label

func force_close() -> void:
	dlg = null
	dlg_root.visible = false
	card_p = null
	card_root.visible = false
	card_root.modulate.a = 0.0
	fade_rect.modulate.a = 0.0
	prompt("")

static func _name_of(who: String) -> String:
	if NAMES.has(who):
		return NAMES[who]
	if PORTRAITS.has(who):
		return PORTRAITS[who].name
	return who

static func _em(s: String) -> String:
	var out := ""
	var on := false
	for part in s.split("*"):
		out += part
		on = not on
		out += "[i][color=#ffd8a0]" if on else "[/color][/i]"
	# remove a última marcação (sobra do split)
	out = out.trim_suffix("[i][color=#ffd8a0]").trim_suffix("[/color][/i]")
	return out

# ---------- diálogo ----------
func dialogue(lines: Array) -> void:
	dlg = {"lines": lines, "i": -1, "shown": 0.0, "full": "", "plain": 0, "frame": Engine.get_process_frames()}
	dlg_root.visible = true
	_next_line()
	await dialogue_done

func _next_line() -> void:
	var d = dlg
	d.i += 1
	if d.i >= d.lines.size():
		dlg_root.visible = false
		dlg = null
		dialogue_done.emit()
		return
	var L = d.lines[d.i]
	var who: String = L.get("who", "narr") if L is Dictionary else L[0]
	var text: String = L.get("text", "") if L is Dictionary else L[1]
	if PORTRAITS.has(who):
		var pr: Dictionary = PORTRAITS[who]
		var tx: Texture2D = tex["p_" + who]
		var at := AtlasTexture.new()
		at.atlas = tx
		var ts := tx.get_size()
		var sc := maxf(216.0 / ts.x, 276.0 / ts.y) * 1.08
		var vw := 216.0 / sc
		var vh := 276.0 / sc
		var px: float = pr.pos.x
		var py: float = pr.pos.y * 0.7
		at.region = Rect2((ts.x - vw) * px, (ts.y - vh) * py, vw, vh)
		dlg_portrait.texture = at
		dlg_pframe.visible = true
		dlg_root.get_node("Box").position.x = 248
	else:
		dlg_pframe.visible = false
		dlg_root.get_node("Box").position.x = 124
	dlg_name.text = _name_of(who).to_upper()
	d.full = _em(text)
	dlg_text.text = d.full
	d.plain = dlg_text.get_total_character_count()
	d.shown = 0.0
	dlg_text.visible_characters = 0
	if L is Dictionary and L.has("fn") and L.fn is Callable and L.fn.is_valid():
		L.fn.call()
	Audio.sfx("ui", 0.35)

func _update_dialogue(rdt: float) -> void:
	if dlg == null:
		return
	if D.skipping:
		# avanço rápido: executa todas as falas restantes (efeitos de roteiro incluídos)
		while dlg != null:
			_next_line()
		return
	var d = dlg
	if d.shown < d.plain:
		d.shown = minf(d.plain, d.shown + rdt * 48.0)
		dlg_text.visible_characters = int(d.shown)
	if Input.is_action_just_pressed("advance") and not get_tree().paused and Engine.get_process_frames() > d.frame + 1:
		if d.shown < d.plain:
			d.shown = d.plain
			dlg_text.visible_characters = -1
		else:
			_next_line()

# ---------- cartões ----------
func card(o: Dictionary) -> void:
	var cls: String = o.get("cls", "")
	match cls:
		"clear":
			card_bg.texture = null
		"memory":
			card_bg.texture = radial_tex(Color(0.16, 0.14, 0.12, 0.55), Color(0, 0, 0, 0.95))
		_:
			card_bg.texture = radial_tex(Color(0.04, 0.024, 0.04, 0.82), Color(0, 0, 0, 0.97))
	for k in ["c1", "c2", "c3", "c4"]:
		var l: Label = card_labels[k]
		l.text = o.get(k, "")
		l.visible = l.text != ""
	card_labels.c3.add_theme_font_override("font", f_serif if cls == "diary" else f_italic)
	card_labels.c3.add_theme_font_size_override("font_size", 33 if cls == "diary" else 31)
	card_labels.c3.add_theme_color_override("font_color", Color("e8dcc4") if cls == "memory" else Color("d6cbb6"))
	card_rule.visible = o.get("c2", "") != "" and (o.get("c3", "") != "" or o.get("c1", "") != "")
	card_skip.text = "CLIQUE PARA CONTINUAR ▸" if o.get("wait", false) else ""
	card_root.visible = true
	var tw := create_tween().set_ignore_time_scale(true)
	tw.tween_property(card_root, "modulate:a", 1.0, 1.1)
	card_p = {"t": 0.0, "dur": o.get("dur", 4.0), "wait": o.get("wait", false), "min_t": o.get("min_t", 1.2), "closing": false}
	await card_done

func _update_card(rdt: float) -> void:
	if card_p == null or card_p.closing:
		return
	var p = card_p
	p.t += rdt
	if D.skipping:
		p.t = 999.0
		p.min_t = 0.0
	var skip: bool = p.t > p.min_t and (Input.is_action_just_pressed("advance")) and not get_tree().paused
	if (not p.wait and p.t >= p.dur) or skip:
		p.closing = true
		var tw := create_tween().set_ignore_time_scale(true)
		tw.tween_property(card_root, "modulate:a", 0.0, 0.05 if D.skipping else 0.9)
		tw.tween_callback(func():
			if card_p == p:
				card_root.visible = false
				card_p = null
				card_done.emit())

func fade(to: float, dur := 1.0) -> void:
	if D.skipping:
		dur = 0.01
	var tw := create_tween().set_ignore_time_scale(true)
	tw.tween_property(fade_rect, "modulate:a", to, maxf(dur, 0.01))
	await tw.finished

# =====================================================================
#  Atualização
# =====================================================================
func _process(_delta: float) -> void:
	var rdt: float = Game.real_dt()
	var paused := get_tree().paused
	t += rdt
	if load_root.visible:
		load_root.get_child(0).queue_redraw()
	_update_dialogue(rdt)
	_update_card(rdt)
	_update_skip(rdt, paused)
	_update_cutin(rdt)
	if vb_t >= 0.0:
		vb_t += rdt
		if vb_t >= vb_dur:
			vb_t = -1.0
		cutin_ui.queue_redraw()
	# letterbox
	var vs := get_viewport().get_visible_rect().size
	lb_h = move_toward(lb_h, (0.11 if cine_on else 0.0), rdt * 0.11 / 0.7)
	lb_top.position = Vector2.ZERO; lb_top.size = Vector2(vs.x, vs.y * lb_h)
	lb_bot.position = Vector2(0, vs.y * (1.0 - lb_h)); lb_bot.size = Vector2(vs.x, vs.y * lb_h + 1)
	# bark
	if bark_t > 0.0:
		bark_t -= rdt
		if bark_t <= 0.0:
			var tw := create_tween().set_ignore_time_scale(true)
			tw.tween_property(bark_lbl, "modulate:a", 0.0, 0.3)
	# prompt
	if prompt_box.visible:
		prompt_box.reset_size()
		prompt_box.position = Vector2((vs.x - prompt_box.size.x) * 0.5, vs.y * 0.62)
	if paused:
		return
	for i in flashes.size():
		flashes[i] = maxf(0.0, flashes[i] - rdt)
	quest_flash = maxf(0.0, quest_flash - rdt)
	quest_box.modulate = Color(1, 1, 1) * (1.0 + quest_flash * 1.1)
	quest_box.modulate.a = 1.0
	for i in range(dn.size() - 1, -1, -1):
		var n = dn[i]
		n.t += rdt
		n.pos.y += n.vy * rdt
		n.vy *= 0.94
		if n.t > 1.1:
			dn.remove_at(i)
	for i in range(toasts.size() - 1, -1, -1):
		toasts[i].t += rdt
		if toasts[i].t > toasts[i].dur:
			toasts.remove_at(i)
	var P = player
	if P and is_instance_valid(P):
		var hp: float = P.hp / P.max_hp
		hp_lag = hp if hp > hp_lag else hp_lag - (hp_lag - hp) * minf(1.0, rdt * 2.0)
	var V = Game.versus
	if V and is_instance_valid(V) and V.cpu and is_instance_valid(V.cpu):
		var f2: float = maxf(0.0, V.cpu.hp / V.cpu.max_hp)
		p2_lag = f2 if f2 > p2_lag else p2_lag - (p2_lag - f2) * minf(1.0, rdt * 2.0)
	if boss_actor and is_instance_valid(boss_actor):
		var f: float = maxf(0.0, boss_actor.hp / boss_actor.max_hp)
		boss_lag = f if f > boss_lag else boss_lag - (boss_lag - f) * minf(1.0, rdt * 1.5)
	hud.queue_redraw()

# ---------- cut-in de Ultimate ----------
func cutin(kit: String, name: String, col: Color, dur := 1.05) -> void:
	cutin_kit = kit if PORTRAITS.has(kit) else "kiana"
	cutin_name = name
	cutin_col = col
	cutin_dur = dur
	cutin_t = 0.0
	Audio.sfx("whoosh", 0.8)
	await cutin_done

func _update_cutin(rdt: float) -> void:
	if cutin_t < 0.0:
		return
	cutin_t += rdt
	cutin_ui.queue_redraw()
	if cutin_t >= cutin_dur:
		cutin_t = -1.0
		cutin_ui.queue_redraw()
		cutin_done.emit()

func _draw_cutin() -> void:
	if cutin_t < 0.0:
		return
	var vs := cutin_ui.size
	var k := cutin_t / cutin_dur
	var inn := 1.0 - pow(1.0 - clampf(k / 0.18, 0.0, 1.0), 3.0)
	var out := clampf((k - 0.85) / 0.15, 0.0, 1.0)
	var slide := (1.0 - inn) * vs.x * 1.1 - out * vs.x * 1.1
	var h := vs.y * 0.36
	var cy := vs.y * 0.5
	var skew := h * 0.55
	# escurece o fundo
	cutin_ui.draw_rect(Rect2(Vector2.ZERO, vs), Color(0.02, 0.0, 0.05, 0.55 * inn * (1.0 - out)))
	# faixas diagonais (sombra colorida + faixa principal)
	var band := func(off: float, hh: float, col: Color):
		var pts := PackedVector2Array([Vector2(-200 + slide + off, cy - hh * 0.5 + skew * 0.5), Vector2(vs.x + 200 + slide + off, cy - hh * 0.5 - skew * 0.5),
			Vector2(vs.x + 200 + slide + off, cy + hh * 0.5 - skew * 0.5), Vector2(-200 + slide + off, cy + hh * 0.5 + skew * 0.5)])
		cutin_ui.draw_colored_polygon(pts, col)
	band.call(40.0, h * 1.18, Color(cutin_col.r, cutin_col.g, cutin_col.b, 0.9))
	band.call(0.0, h, Color(0.06, 0.02, 0.1, 0.97))
	# linhas de velocidade dentro da faixa
	var rr := RandomNumberGenerator.new()
	rr.seed = int(cutin_t * 30.0)
	for i in 26:
		var yy := cy + rr.randf_range(-h * 0.45, h * 0.45)
		var xx := rr.randf_range(0, vs.x) + slide
		var ln := rr.randf_range(120, 420)
		cutin_ui.draw_line(Vector2(xx, yy - (xx - vs.x * 0.5) / vs.x * skew), Vector2(xx + ln, yy - (xx + ln - vs.x * 0.5) / vs.x * skew), Color(1, 1, 1, rr.randf_range(0.08, 0.3)), rr.randf_range(1.0, 3.0))
	# retrato (recorte do rosto) na faixa
	var pr: Dictionary = PORTRAITS[cutin_kit]
	var txp: Texture2D = tex["p_" + cutin_kit]
	var ts := txp.get_size()
	var pw := h * 1.45
	var ph := h * 1.05
	var src := Rect2(ts.x * (pr.pos.x - 0.3), ts.y * maxf(0.0, pr.pos.y - 0.08), ts.x * 0.6, ts.x * 0.6 * ph / pw)
	var drift := cutin_t * 40.0
	var dst := Rect2(vs.x * 0.56 + slide - drift, cy - ph * 0.5, pw, ph)
	cutin_ui.draw_texture_rect_region(txp, dst, src, Color(1, 1, 1, inn))
	# nome do golpe em pincel
	var fs := int(vs.y * 0.085)
	var nx := vs.x * 0.08 + slide * 0.6 + drift * 0.5
	cutin_ui.draw_string_outline(f_brush, Vector2(nx + 4, cy + fs * 0.35 + 4), cutin_name, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 14, Color(0, 0, 0, 0.9))
	cutin_ui.draw_string_outline(f_brush, Vector2(nx, cy + fs * 0.35), cutin_name, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 6, cutin_col)
	cutin_ui.draw_string(f_brush, Vector2(nx, cy + fs * 0.35), cutin_name, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 0.97, 0.94))

# ---------- pular cutscene (segurar Enter/Espaço) ----------
func _update_skip(rdt: float, paused: bool) -> void:
	var can: bool = (Game.cine or card_p != null) and not paused and not prompt_box.visible and not D.skipping
	if can and Input.is_action_pressed("advance") and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		skip_hold += rdt
		if skip_hold >= 1.0:
			skip_hold = 0.0
			D.request_skip()
	else:
		skip_hold = maxf(0.0, skip_hold - rdt * 3.0)
	skip_ui.queue_redraw()

func _draw_skip() -> void:
	var vs := skip_ui.size
	var c := Vector2(vs.x - 70, vs.y - 64)
	if D.skipping:
		_text_on(skip_ui, c + Vector2(-260, 6), "PULANDO CENA ▸▸", 14, Color(0.95, 0.88, 0.7, 0.9))
		return
	if skip_hold <= 0.02:
		return
	var a := clampf(skip_hold * 3.0, 0.0, 1.0)
	skip_ui.draw_arc(c, 18, 0, TAU, 40, Color(0, 0, 0, 0.5 * a), 5.0, true)
	skip_ui.draw_arc(c, 18, -PI / 2, -PI / 2 + TAU * clampf(skip_hold, 0, 1), 40, Color(GOLD, a), 4.0, true)
	_text_on(skip_ui, c + Vector2(-270, 6), "SEGURE PARA PULAR", 14, Color(0.95, 0.9, 0.8, a))

func _text_on(ctl: Control, pos: Vector2, s: String, size: int, col: Color) -> void:
	var f := _fv(f_title, 3, 600)
	ctl.draw_string_outline(f, pos + Vector2(0, 2), s, HORIZONTAL_ALIGNMENT_RIGHT, 240, size, 5, Color(0, 0, 0, col.a * 0.8))
	ctl.draw_string(f, pos, s, HORIZONTAL_ALIGNMENT_RIGHT, 240, size, col)

# =====================================================================
#  Desenho do HUD
# =====================================================================
static func _poly_area(p: PackedVector2Array) -> float:
	var a := 0.0
	for i in p.size():
		a += p[i].cross(p[(i + 1) % p.size()])
	return a * 0.5

func _diamond(c: Vector2, r: float) -> PackedVector2Array:
	return PackedVector2Array([c + Vector2(0, -r), c + Vector2(r, 0), c + Vector2(0, r), c + Vector2(-r, 0)])

func _text(pos: Vector2, s: String, font: Font, size: int, col: Color, align := HORIZONTAL_ALIGNMENT_LEFT, width := -1.0, outline := 6) -> void:
	if outline > 0:
		hud.draw_string_outline(font, pos + Vector2(0, 2), s, align, width, size, outline, Color(0, 0, 0, 0.75 * col.a))
	hud.draw_string(font, pos, s, align, width, size, col)

func _bar(pos: Vector2, w: float, h: float, frac: float, c_top: Color, c_bot: Color, border := Color(0.72, 0.64, 1.0, 0.5), lag := -1.0, horiz := false, c3 := Color(0, 0, 0, 0)) -> void:
	var slant := w * 0.03
	var bg := PackedVector2Array([pos, pos + Vector2(w, 0), pos + Vector2(w - slant, h), pos + Vector2(0, h)])
	hud.draw_colored_polygon(bg, Color(0, 0, 0, 0.65))
	if lag > 0.0 and w * clampf(lag, 0, 1) > 1.5:
		var lw := w * clampf(lag, 0, 1)
		hud.draw_colored_polygon(PackedVector2Array([pos, pos + Vector2(lw, 0), pos + Vector2(maxf(0, lw - slant * lw / w), h), pos + Vector2(0, h)]), Color(1.0, 0.92, 0.95, 0.75))
	var fw := w * clampf(frac, 0, 1)
	if fw > 1.5:
		var pts := PackedVector2Array([pos, pos + Vector2(fw, 0), pos + Vector2(maxf(0, fw - slant * fw / w), h), pos + Vector2(0, h)])
		var cols := PackedColorArray([c_top, c_bot if horiz else c_top, c_bot, c_top if horiz else c_bot])
		if horiz and c3.a > 0.0:
			cols = PackedColorArray([c_top, c3.lerp(c_bot, frac), c3.lerp(c_bot, frac), c_top])
		hud.draw_polygon(pts, cols)
	bg.append(pos)
	hud.draw_polyline(bg, border, 1.2, true)

func _draw_hud() -> void:
	var vs := hud.size
	var P = player
	# números de dano e avisos (sempre)
	_draw_damage_numbers()
	_draw_toasts(vs)
	var V = Game.versus
	if V and is_instance_valid(V) and V.p1 and is_instance_valid(V.p1) and V.cpu and is_instance_valid(V.cpu):
		_draw_versus(vs, V)
		_draw_skills(vs, V.p1)
		return
	# ---------- chefe: topo, centro ----------
	if boss_actor and is_instance_valid(boss_actor):
		var b = boss_actor
		var w := minf(760.0, vs.x * 0.42)
		var bp := Vector2(vs.x * 0.5 - w * 0.5, 58)
		_text(bp + Vector2(0, -12), String(b.display_name).to_upper(), _fv(f_title, 6, 600), 19, WHITE, HORIZONTAL_ALIGNMENT_LEFT, w)
		var ttl: String = b.get("title") if b.get("title") else ""
		_text(bp + Vector2(0, -12), ttl, f_italic, 17, Color(LILAC, 0.9), HORIZONTAL_ALIGNMENT_RIGHT, w, 4)
		_bar(bp, w, 9, maxf(0.0, b.hp / b.max_hp), Color("ff4a5c"), Color("8a0f22"), Color(LILAC, 0.55), boss_lag)
		if b.get("poise_max") and b.poise_max > 0.0:
			var pf: float = clampf(b.poise_cur / b.poise_max, 0.0, 1.0)
			_bar(bp + Vector2(w * 0.25, 14), w * 0.5, 3, pf, Color(WHITE, 0.9), LILAC, Color(LILAC, 0.25), -1.0, true)
		var res := ""
		var rc := Color("9ef3ff")
		if b.get("resonance") and b.resonance > 0:
			res = "RESSONÂNCIA ×%d" % b.resonance
		elif b.get("armor"):
			res = "FRIO ABSOLUTO — IMUNE A GELO"
			rc = Color("8fb2ff")
		if res != "":
			_text(bp + Vector2(0, 36), res, _fv(f_title, 3), 12, rc, HORIZONTAL_ALIGNMENT_CENTER, w, 4)
	if kill_txt != "":
		_text(Vector2(0, 130 if boss_actor else 52), kill_txt, _fv(f_title, 4), 15, Color(WHITE, 0.85), HORIZONTAL_ALIGNMENT_CENTER, vs.x)
	# ---------- objetivo: topo, esquerda ----------
	if quest_obj.text != "":
		var qp := Vector2(46, 52)
		var dd := _diamond(qp + Vector2(6, -6), 6)
		if quest_done_flag:
			hud.draw_colored_polygon(dd, LILAC)
		dd.append(dd[0])
		hud.draw_polyline(dd, LILAC, 1.6, true)
		var qa := 1.0
		_text(qp + Vector2(22, 0), quest_obj.text, f_serif, 22, Color(WHITE, qa))
		if quest_flash > 0.0 and quest_title.text != "":
			_text(qp + Vector2(22, -26), quest_title.text.to_upper(), _fv(f_title, 4, 600), 13, Color(LILAC, minf(1.0, quest_flash)))
	if P == null or not is_instance_valid(P):
		return
	# ---------- personagem: embaixo, esquerda ----------
	var C := Vector2(96, vs.y - 104)
	var R := 60.0
	var pid: String = P.kit
	hud.draw_colored_polygon(_diamond(C, R + 7), Color(0.04, 0.02, 0.07, 0.75))
	var ring := _diamond(C, R + 3); ring.append(ring[0])
	hud.draw_polyline(ring, Color(1, 0.25, 0.3) if P.fury_active > 0.0 else LILAC, 2.2, true)
	var pr: Dictionary = PORTRAITS.get(pid, PORTRAITS.kiana)
	var tx: Texture2D = tex["p_" + pid]
	var ts := tx.get_size()
	var fw: float = 1.6 / pr.size
	var fh: float = fw * ts.x / ts.y
	var cx: float = pr.pos.x * (1.0 - fw) + fw * 0.5
	var cy: float = pr.pos.y * (1.0 - fh) + fh * 0.5
	var uvs := PackedVector2Array([Vector2(cx, cy - fh * 0.5), Vector2(cx + fw * 0.5, cy), Vector2(cx, cy + fh * 0.5), Vector2(cx - fw * 0.5, cy)])
	hud.draw_polygon(_diamond(C, R), PackedColorArray([Color.WHITE, Color.WHITE, Color.WHITE, Color.WHITE]), uvs, tx)
	var bx := C.x + R + 24.0
	var by := C.y - 34.0
	_text(Vector2(bx, by - 8), String(P.K.name).to_upper(), _fv(f_title, 5, 600), 15, WHITE)
	var hpf: float = P.hp / P.max_hp
	_bar(Vector2(bx, by), 330, 11, hpf, Color("ff4a5c"), Color("8a0f22"), Color(LILAC, 0.5), hp_lag)
	_text(Vector2(bx, by - 8), "%d" % ceili(P.hp), _fv(f_title, 1, 600), 13, Color(WHITE, 0.85), HORIZONTAL_ALIGNMENT_RIGHT, 326, 4)
	_bar(Vector2(bx, by + 17), 290, 6, P.energy / P.max_energy, Color("8f6bff"), Color("6fe9ff"), Color(LILAC, 0.35), -1.0, true)
	var full: bool = P.fury >= 100.0 and P.fury_active <= 0.0 and P.ult == null
	var fb := Color(1, 0.3, 0.35, 0.45)
	if full:
		var pulse := 0.5 + 0.5 * sin(t * 7.8)
		hud.draw_rect(Rect2(bx - 3, by + 27, 256, 12), Color(1, 0.15, 0.25, 0.12 + pulse * 0.25))
		fb = Color(1, 0.5, 0.55, 1.0)
	_bar(Vector2(bx, by + 30), 250, 6, P.fury / 100.0, Color("3a0010"), Color("ffd0a0"), fb, -1.0, true, Color("ff2a44"))
	var fname := String(P.fury_name()) if P.awakened else ("MANIFESTAÇÃO" if P.ult != null else "FÚRIA")
	_text(Vector2(bx + 258, by + 38), fname + (" ▸ F" if full else ""), _fv(f_title, 2, 600), 11, Color(1, 0.75, 0.75) if full else Color(WHITE, 0.6), HORIZONTAL_ALIGNMENT_LEFT, -1, 4)
	if P.stamina < P.max_stamina - 0.5:
		var sa := clampf((P.max_stamina - P.stamina) / 20.0, 0.0, 1.0)
		_bar(Vector2(bx, by + 42), 210, 3, P.stamina / P.max_stamina, Color(WHITE, sa), Color(LILAC, sa), Color(LILAC, 0.2 * sa), -1.0, true)
	# ---------- habilidades: embaixo, direita ----------
	_draw_skills(vs, P)
	# ---------- trava ----------
	var lt = P.lock_target
	if lt and is_instance_valid(lt) and lt.alive and Game.cam:
		var cp: Vector3 = lt.chest_pos()
		var cam3: Camera3D = Game.cam.cam
		if not cam3.is_position_behind(cp):
			var sp := cam3.unproject_position(cp)
			sp = sp * (vs / get_viewport().get_visible_rect().size)
			var ld := _diamond(sp, 16); ld.append(ld[0])
			hud.draw_polyline(ld, Color(1, 0.2, 0.35, 0.35), 6.0, true)
			hud.draw_polyline(ld, Color("ff5a7a"), 2.0, true)

func _skill_tex(icon: String) -> Texture2D:
	var k := "skill_" + icon
	if not tex.has(k):
		var p := "res://assets/icons/skills/%s.png" % icon
		tex[k] = load(p) if ResourceLoader.exists(p) else tex.get(icon, tex.get("fury"))
	return tex[k]

func _draw_skills(vs: Vector2, P) -> void:
	var items := []
	for i in P.skills.size():
		items.append({"icon": P.skills[i].icon, "num": str(i + 1), "cd": P.cd[i], "cdmax": P.skills[i].cd, "nores": P.energy < P.skills[i].cost, "flash": flashes[i], "big": false})
	var fic: String = P.fk.fury_icon()
	items.append({"icon": fic, "num": "F", "cd": 0.0, "cdmax": 1.0, "nores": P.fury < 100.0, "flash": flashes[3], "big": true,
		"ready": P.fury >= 100.0 and P.fury_active <= 0.0 and P.ult == null})
	if P.versus:
		items.append({"icon": "chakra", "num": "R", "cd": 0.0, "cdmax": 1.0, "nores": P.energy >= P.max_energy - 0.5, "flash": 0.12 if P.charging else 0.0, "big": false})
	else:
		items.append({"icon": "potion", "num": "R", "cd": 0.0, "cdmax": 1.0, "nores": P.potions <= 0, "flash": flashes[4], "big": false, "cnt": P.potions})
	var px := vs.x - 44.0
	var y := vs.y - 76.0
	var centers := []
	for i in range(items.size() - 1, -1, -1):
		var s := 92.0 if items[i].big else 70.0
		centers.push_front(Vector2(px - s * 0.5, y - (8.0 if items[i].big else 0.0)))
		px -= s + 14.0
	for i in items.size():
		var it: Dictionary = items[i]
		var c: Vector2 = centers[i]
		var r := (92.0 if it.big else 70.0) * 0.5
		var border := Color(1, 0.35, 0.45) if it.big else LILAC
		if it.get("ready", false):
			var pulse := 0.5 + 0.5 * sin(t * 7.0)
			hud.draw_colored_polygon(_diamond(c, r + 8 + pulse * 4), Color(1, 0.2, 0.35, 0.2 + pulse * 0.2))
		hud.draw_colored_polygon(_diamond(c, r + 3), Color(0.03, 0.01, 0.06, 0.8))
		# ícone renderizado recortado no losango
		var ic: Texture2D = _skill_tex(it.icon)
		var mod := Color(1, 1, 1, 1)
		if it.nores:
			mod = Color(0.45, 0.42, 0.5, 1)
		if it.flash > 0.0:
			mod = Color(2.2, 2.2, 2.2, 1)
		var uv := PackedVector2Array([Vector2(0.5, 0.0), Vector2(1.0, 0.5), Vector2(0.5, 1.0), Vector2(0.0, 0.5)])
		hud.draw_polygon(_diamond(c, r), PackedColorArray([mod, mod, mod, mod]), uv, ic)
		if it.cd > 0.0:
			# varredura radial da recarga
			var frac: float = clampf(it.cd / it.cdmax, 0, 1)
			var pts := PackedVector2Array([c])
			var steps := 24
			for k in steps + 1:
				var a := -PI / 2 + TAU * (1.0 - frac) + TAU * frac * k / steps
				pts.append(c + Vector2(cos(a), sin(a)) * r * 1.5)
			if frac > 0.97:
				hud.draw_colored_polygon(_diamond(c, r), Color(0.02, 0.0, 0.05, 0.72))
			elif frac > 0.03:
				for poly in Geometry2D.intersect_polygons(_diamond(c, r), pts):
					if poly.size() >= 3 and absf(_poly_area(poly)) > 2.0:
						hud.draw_colored_polygon(poly, Color(0.02, 0.0, 0.05, 0.72))
			_text(c + Vector2(-40, 8), str(ceili(it.cd)), f_title_b, 21, WHITE, HORIZONTAL_ALIGNMENT_CENTER, 80, 6)
		var dd := _diamond(c, r); dd.append(dd[0])
		hud.draw_polyline(dd, border, 2.0, true)
		_text(c + Vector2(-20, r + 22), it.num, _fv(f_title, 0, 700), 13, Color(WHITE, 0.75), HORIZONTAL_ALIGNMENT_CENTER, 40, 4)
		if it.has("cnt"):
			_text(c + Vector2(r * 0.25, r * 0.85), "×%d" % it.cnt, _fv(f_title, 0, 700), 13, WHITE, HORIZONTAL_ALIGNMENT_LEFT, -1, 4)

func _draw_minimap(c: Vector2, R: float) -> void:
	var P = player
	var L = Game.level
	hud.draw_circle(c, R + 5, Color(0.79, 0.7, 0.48, 0.5))
	hud.draw_circle(c, R + 3, Color(0.04, 0.035, 0.05))
	hud.draw_circle(c, R, Color(0.1, 0.1, 0.11))
	hud.draw_circle(c, R * 0.6, Color(0.13, 0.13, 0.14, 0.6))
	if L == null or not is_instance_valid(L):
		return
	var circle := PackedVector2Array()
	for i in 40:
		circle.append(c + Vector2(cos(TAU * i / 40.0), sin(TAU * i / 40.0)) * R)
	var b: Dictionary = L.bounds
	var narrow: bool = b.type == "circle" or (b.max.x - b.min.x) < 30.0
	var s := 4.4 if narrow else 3.3
	var yaw: float = Game.cam.yaw if Game.cam else 0.0
	var pp: Vector3 = P.global_position
	var right := Vector2(-cos(yaw), sin(yaw))
	var fwd := Vector2(sin(yaw), cos(yaw))
	var tx := func(x: float, z: float) -> Vector2:
		var d := Vector2(x - pp.x, z - pp.z)
		return c + Vector2(d.dot(right), -d.dot(fwd)) * s
	var fill := Color(0.31, 0.27, 0.23, 0.38)
	var edge := Color(0.78, 0.7, 0.55, 0.45)
	var shape := PackedVector2Array()
	if b.type == "box":
		shape = PackedVector2Array([tx.call(b.min.x, b.min.y), tx.call(b.max.x, b.min.y), tx.call(b.max.x, b.max.y), tx.call(b.min.x, b.max.y)])
	else:
		var bc: Vector2 = b.get("c", Vector2.ZERO)
		for i in 48:
			var a := TAU * i / 48.0
			shape.append(tx.call(bc.x + cos(a) * b.r, bc.y + sin(a) * b.r))
	for poly in Geometry2D.intersect_polygons(shape, circle):
		hud.draw_colored_polygon(poly, fill)
		var pl: PackedVector2Array = poly.duplicate(); pl.append(poly[0])
		hud.draw_polyline(pl, edge, 2.0, true)
	for m in L.map_shapes:
		var poly := PackedVector2Array()
		if m.type == "rect":
			var half: Vector2 = m.s * 0.5
			var rb := Transform2D(m.r, Vector2.ZERO)
			for k in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
				var o: Vector2 = rb * (half * k)
				poly.append(tx.call(m.c.x + o.x, m.c.y + o.y))
		else:
			for i in 12:
				var a := TAU * i / 12.0
				poly.append(tx.call(m.c.x + cos(a) * m.r, m.c.y + sin(a) * m.r))
		for cp in Geometry2D.intersect_polygons(poly, circle):
			hud.draw_colored_polygon(cp, Color(0.12, 0.1, 0.09, 0.85))
	for a in Game.actors:
		if a == P or not is_instance_valid(a) or not a.alive:
			continue
		var q: Vector2 = tx.call(a.global_position.x, a.global_position.z)
		if q.distance_to(c) > R - 4:
			continue
		var col := Color("d83030") if a.team == "enemy" else (Color("50e090") if a.team == "player" else Color("e8c870"))
		if a.boss:
			col = Color("ff2020")
		hud.draw_circle(q, 6.0 if a.boss else (3.5 if a.team == "neutral" else 4.0), col)
		if a.boss:
			hud.draw_arc(q, 6.0, 0, TAU, 16, Color("ffb0a0"), 1.5)
	if Game.objective != null:
		var o: Vector3 = Game.objective
		var q: Vector2 = tx.call(o.x, o.z)
		var dv := q - c
		if dv.length() > R - 10:
			q = c + dv.normalized() * (R - 10)
		var od := _diamond(q, 7)
		hud.draw_colored_polygon(od, Color("ffd060"))
		od.append(od[0])
		hud.draw_polyline(od, Color.BLACK, 1.5)
	# seta do jogador
	var rel: float = P.yaw - yaw
	var tr := Transform2D(-rel, c)
	var arrow := PackedVector2Array([tr * Vector2(0, -9), tr * Vector2(6.5, 7), tr * Vector2(0, 3.5), tr * Vector2(-6.5, 7)])
	hud.draw_colored_polygon(arrow, Color.WHITE)
	hud.draw_arc(c, R - 1, 0, TAU, 64, Color(0.79, 0.7, 0.48, 0.6), 2.5, true)
	# selo (caveira) no topo
	var n := c + Vector2(0, -R - 2)
	hud.draw_colored_polygon(_diamond(n, 18), Color(0.04, 0.04, 0.05))
	var nd := _diamond(n, 18); nd.append(nd[0])
	hud.draw_polyline(nd, GOLD_LINE, 1.5, true)
	hud.draw_texture_rect(tex.skull, Rect2(n - Vector2(9, 9), Vector2(18, 18)), false)

func _draw_damage_numbers() -> void:
	if not Game.cam or dn.is_empty():
		return
	var cam3: Camera3D = Game.cam.cam
	var ratio := hud.size / get_viewport().get_visible_rect().size
	for n in dn:
		if cam3.is_position_behind(n.pos):
			continue
		var sp := cam3.unproject_position(n.pos) * ratio
		var a := clampf(1.0 - maxf(0.0, n.t - 0.5) * 2.0, 0, 1)
		var sc: float = 1.6 - n.t * 6.0 if n.t < 0.1 else 1.0
		var size := int((30 if n.crit else 21) * sc)
		var col: Color = n.col if n.col != null else (Color("ff5050") if n.pl else (Color("ffd060") if n.crit else Color.WHITE))
		col.a = a
		var s := str(n.amt)
		var w := f_title_b.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		hud.draw_string_outline(f_title_b, sp + Vector2(-w * 0.5, size * 0.35 + 2), s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 5, Color(0, 0, 0, a))
		hud.draw_string(f_title_b, sp + Vector2(-w * 0.5, size * 0.35), s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)

func _draw_toasts(vs: Vector2) -> void:
	var y := vs.y * 0.3
	for to in toasts:
		var k: float = to.t / to.dur
		var a := 1.0
		var sc := 1.0
		var dy := 0.0
		if k < 0.12:
			a = k / 0.12
			sc = 1.4 - 0.4 * (k / 0.12)
		elif k > 0.75:
			a = 1.0 - (k - 0.75) / 0.25
			dy = -20.0 * (k - 0.75) / 0.25
		var font: Font = f_deco if to.big else _fv(f_title, 6, 700)
		var size := int((44 if to.big else 22) * sc)
		var col: Color = to.col
		col.a = a
		var w := font.get_string_size(to.text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		y += (44 if to.big else 22) * 1.15
		var p := Vector2(vs.x * 0.5 - w * 0.5, y + dy)
		hud.draw_string_outline(font, p, to.text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 14, Color(col.r, col.g, col.b, 0.3 * a))
		hud.draw_string_outline(font, p + Vector2(0, 2), to.text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 6, Color(0.03, 0, 0.06, 0.85 * a))
		# miolo claro (legível sobre cenários vermelhos), brilho na cor do aviso
		var fill := col.lerp(Color(1, 0.97, 1), 0.55)
		fill.a = a
		hud.draw_string(font, p, to.text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, fill)
		y += (44 if to.big else 22) * 0.55

# =====================================================================
#  Modo Versus: faixa de anúncio e HUD de duas barras (estilo Storm)
# =====================================================================
func versus_banner(text: String, sub := "", dur := 1.2, col := Color(0.72, 0.6, 1.0), y := 0.44) -> void:
	vb_y = y
	vb_text = text
	vb_sub = sub
	vb_dur = dur
	vb_col = col
	vb_t = 0.0
	await get_tree().create_timer(dur, false, false, true).timeout

func _draw_banner() -> void:
	if vb_t < 0.0 or vb_text == "":
		return
	var vs := cutin_ui.size
	var inn := 1.0 - pow(1.0 - clampf(vb_t / 0.16, 0.0, 1.0), 3.0)
	var out := clampf((vb_t - (vb_dur - 0.22)) / 0.22, 0.0, 1.0)
	var a := inn * (1.0 - out)
	var cy := vs.y * vb_y
	var h := vs.y * 0.17 * (0.4 + 0.6 * inn)
	var skew := h * 0.35
	var slide := out * vs.x * 0.15
	# faixas inclinadas: brilho colorido + faixa escura
	for band in [[h * 1.25, Color(vb_col.r, vb_col.g, vb_col.b, 0.55 * a)], [h, Color(0.04, 0.01, 0.08, 0.88 * a)]]:
		var hh: float = band[0]
		cutin_ui.draw_colored_polygon(PackedVector2Array([Vector2(-50 + slide, cy - hh * 0.5 + skew * 0.5), Vector2(vs.x + 50 + slide, cy - hh * 0.5 - skew * 0.5),
			Vector2(vs.x + 50 + slide, cy + hh * 0.5 - skew * 0.5), Vector2(-50 + slide, cy + hh * 0.5 + skew * 0.5)]), band[1])
	# linhas de velocidade
	var rr := RandomNumberGenerator.new()
	rr.seed = int(vb_t * 24.0) + 7
	for i in 18:
		var yy := cy + rr.randf_range(-h * 0.42, h * 0.42)
		var xx := rr.randf_range(0, vs.x)
		var ln := rr.randf_range(80, 300)
		cutin_ui.draw_line(Vector2(xx, yy - (xx - vs.x * 0.5) / vs.x * skew), Vector2(xx + ln, yy - (xx + ln - vs.x * 0.5) / vs.x * skew), Color(1, 1, 1, rr.randf_range(0.05, 0.2) * a), rr.randf_range(1.0, 2.5))
	# texto em pincel com "soco" de escala
	var sc := 1.0 + (1.0 - inn) * 0.6
	var fs := int(vs.y * 0.1 * sc)
	var w := f_brush.get_string_size(vb_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var tp := Vector2(vs.x * 0.5 - w * 0.5 + slide, cy + fs * 0.32 - (8.0 if vb_sub != "" else 0.0))
	cutin_ui.draw_string_outline(f_brush, tp + Vector2(5, 5), vb_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 16, Color(0, 0, 0, 0.9 * a))
	cutin_ui.draw_string_outline(f_brush, tp, vb_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 8, Color(vb_col.r, vb_col.g, vb_col.b, a))
	cutin_ui.draw_string(f_brush, tp, vb_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 0.98, 1, a))
	if vb_sub != "":
		var sf := _fv(f_title, 8, 600)
		var sw := sf.get_string_size(vb_sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
		var sp := Vector2(vs.x * 0.5 - sw * 0.5 + slide, cy + h * 0.38)
		cutin_ui.draw_string_outline(sf, sp + Vector2(0, 2), vb_sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, 6, Color(0, 0, 0, 0.8 * a))
		cutin_ui.draw_string(sf, sp, vb_sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(WHITE, a))

## Barra espelhável: com `mirror` cresce da direita para a esquerda (lado do CPU).
func _vbar(x: float, y: float, w: float, h: float, frac: float, lag: float, c1: Color, c2: Color, mirror: bool, border := Color(0.72, 0.64, 1.0, 0.55)) -> void:
	var sl := h * 0.9
	var sgn := -1.0 if mirror else 1.0
	var shape := func(f: float) -> PackedVector2Array:
		var ww := w * clampf(f, 0.0, 1.0)
		return PackedVector2Array([Vector2(x, y), Vector2(x + sgn * ww, y), Vector2(x + sgn * maxf(0.0, ww - sl), y + h), Vector2(x, y + h)])
	var bg: PackedVector2Array = shape.call(1.0)
	hud.draw_colored_polygon(bg, Color(0.02, 0.0, 0.05, 0.7))
	if lag > frac and w * lag > sl + 2.0:
		hud.draw_colored_polygon(shape.call(lag), Color(1.0, 0.92, 0.95, 0.7))
	if w * frac > sl + 2.0:
		var pts: PackedVector2Array = shape.call(frac)
		hud.draw_polygon(pts, PackedColorArray([c1, c1, c2, c2]))
	bg.append(bg[0])
	hud.draw_polyline(bg, border, 1.4, true)

func _draw_fighter(vs: Vector2, P, mirror: bool, lag: float, wins: int, need: int) -> void:
	var V = Game.versus
	var sgn := -1.0 if mirror else 1.0
	var R := 46.0
	var C := Vector2(vs.x - 78.0 if mirror else 78.0, 74.0)
	var accent := Color(1, 0.35, 0.45) if mirror else LILAC
	# retrato em losango
	hud.draw_colored_polygon(_diamond(C, R + 7), Color(0.04, 0.02, 0.07, 0.8))
	var pid: String = P.kit
	var pr: Dictionary = PORTRAITS.get(pid, PORTRAITS.kiana)
	var tx: Texture2D = tex["p_" + pid]
	var ts := tx.get_size()
	var fw: float = 1.6 / pr.size
	var fh: float = fw * ts.x / ts.y
	var cx: float = pr.pos.x * (1.0 - fw) + fw * 0.5
	var cy: float = pr.pos.y * (1.0 - fh) + fh * 0.5
	var uvs := PackedVector2Array([Vector2(cx, cy - fh * 0.5), Vector2(cx + fw * 0.5, cy), Vector2(cx, cy + fh * 0.5), Vector2(cx - fw * 0.5, cy)])
	var tint := Color(0.85, 0.72, 1.0) if mirror and V.cfg.p1 == V.cfg.cpu else Color.WHITE
	hud.draw_polygon(_diamond(C, R), PackedColorArray([tint, tint, tint, tint]), uvs, tx)
	var ring := _diamond(C, R + 3)
	ring.append(ring[0])
	hud.draw_polyline(ring, Color(1, 0.25, 0.3) if P.fury_active > 0.0 else accent, 2.2, true)
	# nome
	var w := minf(600.0, vs.x * 0.33)
	var x0 := C.x + sgn * (R + 22.0)
	var nm: String = String(Versus.fighter(pid).name).to_upper()
	if mirror:
		nm = "CPU · " + nm
	_text(Vector2(x0 - (w if mirror else 0.0), 52), nm, _fv(f_title, 5, 600), 17, WHITE, HORIZONTAL_ALIGNMENT_RIGHT if mirror else HORIZONTAL_ALIGNMENT_LEFT, w)
	# vida, chakra e fúria
	_vbar(x0, 60, w, 16, maxf(0.0, P.hp / P.max_hp), lag, Color("ff5a6a"), Color("9a1028"), mirror)
	_vbar(x0, 81, w * 0.78, 7, P.energy / P.max_energy, -1.0, Color("7fd8ff"), Color("6a5cff"), mirror, Color(0.6, 0.8, 1.0, 0.45))
	var full: bool = P.fury >= 100.0 and P.fury_active <= 0.0 and P.ult == null
	var fcol := Color(1, 0.35, 0.3)
	if full:
		fcol = Color(1, 0.55 + 0.35 * sin(t * 8.0), 0.4)
	_vbar(x0, 92, w * 0.55, 5, P.fury / 100.0, -1.0, fcol, Color("ffb070"), mirror, Color(1, 0.5, 0.45, 0.4))
	if full:
		var lbl := "ULTIMATE" if mirror else "ULTIMATE ▸ F"
		var lx := x0 + sgn * (w * 0.55 + 10.0)
		if mirror:
			_text(Vector2(lx - 160.0, 99), lbl, _fv(f_title, 2, 700), 11, Color(1, 0.8, 0.7), HORIZONTAL_ALIGNMENT_RIGHT, 160.0, 4)
		else:
			_text(Vector2(lx, 99), lbl, _fv(f_title, 2, 700), 11, Color(1, 0.8, 0.7), HORIZONTAL_ALIGNMENT_LEFT, -1.0, 4)
	# Substituição: 4 losangos
	for i in 4:
		var c := Vector2(x0 + sgn * (10.0 + i * 20.0), 116.0)
		var fill := clampf(P.subs - i, 0.0, 1.0)
		hud.draw_colored_polygon(_diamond(c, 7), Color(0.02, 0.0, 0.05, 0.7))
		if fill >= 1.0:
			hud.draw_colored_polygon(_diamond(c, 6), Color(0.85, 0.75, 1.0))
		elif fill > 0.1:
			hud.draw_colored_polygon(_diamond(c, 6.0 * fill), Color(0.6, 0.5, 0.85, 0.8))
		var dd := _diamond(c, 7)
		dd.append(dd[0])
		hud.draw_polyline(dd, Color(0.8, 0.7, 1.0, 0.6), 1.0, true)
	# vitórias: losangos ao lado do cronômetro
	for i in need:
		var c := Vector2(vs.x * 0.5 - sgn * (64.0 + i * 22.0), 104.0)
		hud.draw_colored_polygon(_diamond(c, 8), accent if i < wins else Color(0.03, 0.01, 0.06, 0.75))
		var dd := _diamond(c, 8)
		dd.append(dd[0])
		hud.draw_polyline(dd, accent, 1.4, true)
	# contador de golpes do combo (do lado de quem está batendo)
	var foe = P.opponent
	if foe and is_instance_valid(foe) and foe.combo_hits >= 2 and foe.state == "hit":
		var txt := "%d" % foe.combo_hits
		var al := HORIZONTAL_ALIGNMENT_RIGHT if mirror else HORIZONTAL_ALIGNMENT_LEFT
		var bx := vs.x - 290.0 if mirror else 70.0
		var by := vs.y * 0.36
		hud.draw_string_outline(f_brush, Vector2(bx, by), txt, al, 220, 52, 10, Color(0, 0, 0, 0.85))
		hud.draw_string(f_brush, Vector2(bx, by), txt, al, 220, 52, Color(1, 0.95, 0.75))
		_text(Vector2(bx, by + 26), "GOLPES", _fv(f_title, 4, 700), 14, Color(1, 0.85, 0.6), al, 220, 4)

func _draw_versus(vs: Vector2, V) -> void:
	var need: int = V.cfg.rounds
	_draw_fighter(vs, V.p1, false, hp_lag, V.wins[0], need)
	_draw_fighter(vs, V.cpu, true, p2_lag, V.wins[1], need)
	# cronômetro
	var c := Vector2(vs.x * 0.5, 66)
	hud.draw_colored_polygon(_diamond(c, 42), Color(0.03, 0.01, 0.07, 0.85))
	var dd := _diamond(c, 42)
	dd.append(dd[0])
	hud.draw_polyline(dd, LILAC, 2.0, true)
	var tt := ceili(V.timer)
	var col := WHITE if tt > 10 or not V.fighting else Color(1, 0.4 + 0.3 * sin(t * 10.0), 0.4)
	_text(c + Vector2(-60, 14), "%d" % tt, f_title_b, 36, col, HORIZONTAL_ALIGNMENT_CENTER, 120, 6)
