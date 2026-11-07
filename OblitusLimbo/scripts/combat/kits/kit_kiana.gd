extends FighterKit
## Kiana — a bardo de Vardun: adaga de Kael + ukulele. Apagão (fúria amnésica) e Manifestação Harmônica.

func stats() -> Dictionary:
	return {"hp": 100.0, "speed": 5.1, "sprint": 7.8, "color": Color(0.75, 0.9, 1.0), "chakra": Color(0.62, 0.42, 1.0),
		"name": "Kiana", "title": "A Bardo de Vardun", "vs_hp": 420.0, "fury_gain": 1.0}

func moves() -> Dictionary:
	return MoveSet.KIANA

func skills() -> Array:
	return [
		{"name": "Acorde Cortante", "cost": 18.0, "cd": 1.4, "icon": "blade", "ai": {"kind": "ranged", "range": 14.0}},
		{"name": "Ressonância", "cost": 35.0, "cd": 7.0, "icon": "wave", "ai": {"kind": "aoe", "range": 5.5}},
		{"name": "Passo Sombrio", "cost": 25.0, "cd": 4.5, "icon": "blink", "ai": {"kind": "mobility", "range": 14.0, "need_target": true}}]

func _harmonic() -> bool:
	return Game.flags.get("harmonic", false)

func awaken_name() -> String:
	return "MANIFESTAÇÃO HARMÔNICA" if _harmonic() else "APAGÃO"

func ult_info() -> Dictionary:
	if Game and _harmonic():
		return {"name": "ACORDE FINAL", "col": Color(0.4, 0.9, 1.0), "rush": "Sword_Dash", "icon": "harmonic"}
	return {"name": "RÉQUIEM DO APAGÃO", "col": Color(1.0, 0.08, 0.18), "rush": "Sword_Dash", "icon": "fury"}

func win_anim() -> String:
	return "Spell_Simple_Idle"

func use_skill(i: int, tgt) -> void:
	P._kiana_skill(i, tgt)

func awaken() -> void:
	if _harmonic():
		P.start_ult()
	else:
		P.apagao_start()

func awaken_tick(_delta: float) -> void:
	if randf() < 0.6:
		Game.fx.burst("shadow", P.global_position + Vector3(0, 0.5, 0), {"n": 1, "r": 0.35, "color": Color(0.1, 0, 0.03)})

func awaken_end() -> void:
	Game.flags["apagao"] = false
	P.rig.set_eye_glow(Color(1.4, 0.1, 0.05))
	P.rig.set_face(false)

func dmg_mul() -> float:
	return 1.6 if P.fury_active > 0.0 else 1.0

func trail_col(_m: Dictionary) -> Color:
	return Color(1, 0.2, 0.25) if P.fury_active > 0.0 else Color(0.72, 0.6, 1.0)

func hit_col(_m: Dictionary) -> Color:
	return Color(1, 0.16, 0.16) if P.fury_active > 0.0 else stats().color

func modify_hit(_target, o: Dictionary, _m: Dictionary, _h: Dictionary) -> Dictionary:
	if P.fury_active > 0.0:
		o["spark"] = Color(1, 0.4, 0.4)
		o["spark2"] = Color(0.4, 0, 0)
	return o

func on_hit_dealt(_target, _amount: float, _o: Dictionary) -> void:
	if P.fury_active > 0.0:
		P.hp = minf(P.max_hp, P.hp + 2.0)

func dodge_fx() -> void:
	Game.fx.afterimage(P, Color(0.55, 0.3, 1.0))
	Game.fx.burst("shadow", P.global_position + Vector3(0, 0.8, 0), {"n": 8, "r": 0.3, "color": Color(0.08, 0.04, 0.1)})

func ult_sequence(U) -> void:
	if _harmonic():
		await U._seq_harmonic()
	else:
		await U._seq_kiana()
