class_name PostFX
extends CanvasLayer
## Pós-processamento de tela (Game.post): flash, dano, Apagão, memória, Manifestação, vinheta.

var hurt := 0.0
var flash := 0.0
var red := 0.0
var desat := 0.0
var desat_target := 0.0
var harmonic := 0.0
var harm_v := 0.0
var vig := 0.0
var impact := 0.0
var impact_frame_t := 0.0
var speed_lines := 0.0
var speed_target := 0.0

## Quadros de impacto (preto e branco invertido) por `sec` segundos reais.
func impact_frames(sec := 0.07, col := Color(0.92, 0.88, 1.0)) -> void:
	impact_frame_t = maxf(impact_frame_t, sec)
	mat.set_shader_parameter("impact_col", col)
var rect: ColorRect
var mat: ShaderMaterial

func _ready() -> void:
	layer = 1
	process_mode = Node.PROCESS_MODE_ALWAYS
	rect = ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mat = ShaderMaterial.new()
	mat.shader = preload("res://shaders/post_grade.gdshader")
	rect.material = mat
	add_child(rect)

func reset() -> void:
	hurt = 0.0; flash = 0.0; desat_target = 0.0; harmonic = 0.0; vig = 0.0; impact = 0.0
	impact_frame_t = 0.0; speed_target = 0.0; speed_lines = 0.0

func _process(_delta: float) -> void:
	var rdt: float = Game.real_dt()
	if get_tree().paused:
		rdt = 0.0
	var k := minf(1.0, rdt * 4.0)
	hurt = maxf(0.0, hurt - rdt * 1.4)
	impact = maxf(0.0, impact - rdt * 5.0)
	impact_frame_t = maxf(0.0, impact_frame_t - Game.real_dt())
	speed_lines = move_toward(speed_lines, speed_target, rdt * 6.0)
	flash = maxf(0.0, flash - rdt * 2.2)
	red += ((1.0 if Game.flags.get("apagao", false) else 0.0) - red) * k
	desat += (desat_target - desat) * minf(1.0, rdt * 1.5)
	harm_v += (harmonic - harm_v) * k
	var low := 0.0
	var P = Game.player
	if P and is_instance_valid(P) and P.alive and P.hp / P.max_hp < 0.25:
		low = 0.25 + sin(Game.real_time * 6.0) * 0.1
	mat.set_shader_parameter("hurt", hurt + low)
	mat.set_shader_parameter("red", red)
	mat.set_shader_parameter("desat", desat)
	mat.set_shader_parameter("flash", minf(1.0, flash))
	mat.set_shader_parameter("harm", harm_v)
	mat.set_shader_parameter("vig", vig)
	mat.set_shader_parameter("impact", impact)
	mat.set_shader_parameter("impact_frame", 1.0 if impact_frame_t > 0.0 else 0.0)
	mat.set_shader_parameter("speed_lines", speed_lines)
	var pt := 0.12
	if Game.level and is_instance_valid(Game.level) and Game.level.get("purple") != null:
		pt = Game.level.purple
	mat.set_shader_parameter("purple_tone", pt)
	mat.set_shader_parameter("time", Game.real_time)
	# glow extra no Apagão / Manifestação
	if Game.level and is_instance_valid(Game.level) and Game.level.env:
		Game.level.env.glow_intensity = Game.level.get_meta("glow_base", Game.level.env.glow_intensity) + red * 0.3 + harm_v * 0.4
		if not Game.level.has_meta("glow_base"):
			Game.level.set_meta("glow_base", Game.level.env.glow_intensity)
