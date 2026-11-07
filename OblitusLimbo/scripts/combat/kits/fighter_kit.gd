class_name FighterKit
extends RefCounted
## Kit de personagem jogável: atributos, grafo de combos, habilidades, passiva, despertar e Ultimate.
## O Player delega para o kit tudo o que é específico do personagem; Versus, CPU e HUD leem daqui.
## Cada personagem é um arquivo kit_<id>.gd que sobrescreve o que precisar.

var P              # Player dono do kit
var id := ""

func _init(player = null) -> void:
	P = player

# ---------------------------------------------------------------------
#  Dados
# ---------------------------------------------------------------------
## hp, speed, sprint, color (golpes), chakra (cor), name, title, vs_hp, fury_gain
func stats() -> Dictionary:
	return {"hp": 100.0, "speed": 5.0, "sprint": 7.6, "color": Color(1, 1, 1), "chakra": Color(0.6, 0.5, 1.0),
		"name": id.capitalize(), "title": "", "vs_hp": 420.0, "fury_gain": 1.0}

func moves() -> Dictionary:
	return MoveSet.KIANA

## [{name, cost, cd, icon, ai: {kind: ranged|close|aoe|mobility|buff|grab|trap, range, need_target}}]
func skills() -> Array:
	return []

## Nome do despertar (segurar F) e do Ultimate (tocar F).
func awaken_name() -> String:
	return "DESPERTAR"

func has_awaken() -> bool:
	return true

func ult_info() -> Dictionary:
	return {"name": "ULTIMATE", "col": Color(1, 0.3, 0.3), "rush": "Sword_Dash", "icon": "fury"}

## Ícone do slot F no HUD.
func fury_icon() -> String:
	return ult_info().get("icon", "fury")

## Pose de vitória (animação em loop).
func win_anim() -> String:
	return "Idle_Shield_Break"

# ---------------------------------------------------------------------
#  Ganchos de jogo (sobrescrever)
# ---------------------------------------------------------------------
## Depois de montar o personagem (props extras, nós próprios).
func setup() -> void:
	pass

func tick(_delta: float) -> void:
	pass

func use_skill(_i: int, _tgt) -> void:
	pass

## Ativa o despertar (depois da mini-cena). Duração em P.fury_active.
func awaken() -> void:
	pass

func awaken_tick(_delta: float) -> void:
	pass

func awaken_end() -> void:
	pass

## Multiplicador de dano do lutador (despertar, passivas).
func dmg_mul() -> float:
	return 1.0

## Sequência cinematográfica do Ultimate (U = Ultimate em andamento; use U._hit, U._place_around, U._wait).
func ult_sequence(U) -> void:
	await U._wait(0.1)

## Cor e osso do rastro do golpe.
func trail_col(_m: Dictionary) -> Color:
	return stats().color

func trail_bone(_m: Dictionary) -> String:
	return "hand_r"

func hit_col(_m: Dictionary) -> Color:
	return stats().color

## Efeitos extras de um golpe corpo a corpo (antes do dano).
func melee_fx(_m: Dictionary, _h: Dictionary, _pos: Vector3) -> void:
	pass

## Ajusta o dicionário de dano antes de aplicar (ex.: ataque furtivo, congelamento).
func modify_hit(_target, o: Dictionary, _m: Dictionary, _h: Dictionary) -> Dictionary:
	return o

## Chamado depois que um golpe meu acertou (dano já aplicado).
func on_hit_dealt(_target, _amount: float, _o: Dictionary) -> void:
	pass

## Dano recebido: devolve o multiplicador (Frio Absoluto, Sangue Quente…).
func incoming_mul(_src, _o: Dictionary) -> float:
	return 1.0

## Intercepta um golpe antes do dano (postura de contra-ataque). true = golpe anulado.
func intercept_hit(_src, _amount: float, _o: Dictionary) -> bool:
	return false

## Superarmadura: golpes não interrompem (o dano entra normalmente).
func super_armor() -> bool:
	return false

## Golpe básico à distância (hits com "proj": true): por padrão dispara uma flecha.
func fire_hit(m: Dictionary, h: Dictionary) -> void:
	var tgt = P.auto_target(float(h.get("range", 16.0)))
	var start: Vector3 = P.global_position + Vector3(0, 1.35, 0) + P.forward() * 0.6
	var dir: Vector3 = (tgt.chest_pos() - start).normalized() if tgt else P.forward()
	if tgt:
		P.snap_face(tgt.global_position)
	proj({"kind": h.get("kind", "arrow"), "pos": start, "vel": dir * float(h.get("speed", 34.0)), "dmg": float(h.dmg) * P.dmg_mul(), "radius": float(h.get("radius", 0.35)),
		"life": 1.2, "knock": float(h.get("knock", 2.0)), "heavy": String(m.get("type", "light")) != "light", "color": h.get("color", col()), "glow": true,
		"fury_gain": 2.5, "target": tgt, "homing": float(h.get("homing", 1.5)),
		"on_hit": func(_p, t, ok): if ok: on_hit_dealt(t, 0.0, {"move_type": m.get("type", "light"), "proj": true})})
	Audio.sfx("arrow", 0.8)

func dodge_fx() -> void:
	Game.fx.afterimage(P, stats().chakra)

## Início de qualquer golpe do grafo de combos.
func on_attack_start(_m: Dictionary) -> void:
	pass

## Multiplicadores de deslocamento e de velocidade de animação dos golpes (passivas).
func move_mul() -> float:
	return 1.0

func anim_mul() -> float:
	return 1.0

## Janela de aparar (segundos desde que levantou a guarda).
func parry_window() -> float:
	return 0.22

## Aparou um golpe com perfeição.
func on_parry(_src) -> void:
	pass

func on_perfect_dodge(_src) -> void:
	pass

## Lutador saindo de cena: libera nós próprios do kit.
func cleanup() -> void:
	pass

## Novo round (Versus): volta o estado próprio do kit ao normal.
func reset() -> void:
	pass

# ---------------------------------------------------------------------
#  Utilidades para os kits
# ---------------------------------------------------------------------
func col() -> Color:
	return stats().color

func cast(dur: float, anim: String, speed := 1.0, move := 0.0, from := 0.0) -> void:
	P.set_state("cast")
	P.cast_dur = dur
	P.cast_move = move
	P.rig.play(anim, {"speed": speed, "from": from, "blend": 0.06})

## Executa `fn` no instante `t` (segundos de animação) do golpe atual, se ainda estiver nele.
func at(t: float, fn: Callable) -> void:
	var st: String = P.state
	Game.after(t, func():
		if is_instance_valid(P) and P.alive and P.state == st:
			fn.call())

func proj(o: Dictionary) -> Dictionary:
	o["team"] = P.team
	o["src"] = P
	if not o.has("pos"):
		o["pos"] = P.global_position + Vector3(0, 1.2, 0) + P.forward() * 0.6
	return Game.spawn_projectile(o)

func area(o: Dictionary) -> Dictionary:
	o["team"] = P.team
	o["src"] = P
	if not o.has("telegraph"):
		o["telegraph"] = false
	return Game.area_attack(o)

func hit(target, dmg: float, o := {}) -> bool:
	if target == null or not is_instance_valid(target) or not target.alive:
		return false
	return Game.damage(P, target, dmg * P.dmg_mul(), o)

func dir_to(target) -> Vector3:
	if target == null or not is_instance_valid(target):
		return P.forward()
	var d: Vector3 = target.global_position - P.global_position
	d.y = 0
	return d.normalized() if d.length() > 0.01 else P.forward()

func foes_in(radius: float, center = null) -> Array:
	var c: Vector3 = P.global_position if center == null else center
	var out := []
	for e in Game.enemies_of(P):
		if Game.dist2d(e.global_position, c) <= radius + e.radius:
			out.append(e)
	return out

func say(text: String, c := Color.WHITE, dur := 1.0, big := false) -> void:
	P._say(text, c, dur, big)
