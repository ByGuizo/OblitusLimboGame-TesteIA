class_name MoveSet
## Golpes e grafo de combo por personagem (dados). Tempos em segundos da animação (antes de `speed`),
## medidos a partir de `from`.
##   hits:    [{t, dmg, range, arc, knock, launch, reaction, hitstop, shake, slash, area, ice}]
##   combo:   a partir de quando o próximo golpe (leve/pesado) pode sair
##   cancel:  a partir de quando esquiva/defesa/habilidade cancelam (0 = a qualquer momento)
##   recover: a partir de quando mover o direcional interrompe a recuperação
##   end:     fim do golpe (volta à locomoção)
##   next:    {light: id, heavy: id}
##   type:    light | heavy | finisher | dash | counter

const KIANA := {
	"start": {"light": "L1", "heavy": "H1", "dash": "DASH", "counter": "CTR"},
	"L1": {"anim": "Sword_Regular_A", "speed": 1.45, "type": "light", "lunge": 5.0,
		"hits": [{"t": 0.13, "dmg": 11.0, "range": 2.3, "arc": 2.2, "knock": 2.0, "reaction": "flinch", "slash": {"roll": -0.25}}],
		"combo": 0.17, "cancel": 0.0, "recover": 0.3, "end": 0.42, "next": {"light": "L2", "heavy": "L1H"}},
	"L2": {"anim": "Sword_Regular_B", "speed": 1.4, "type": "light", "lunge": 5.0,
		"hits": [{"t": 0.19, "dmg": 12.0, "range": 2.3, "arc": 2.2, "knock": 2.0, "reaction": "flinch", "slash": {"roll": 0.75, "flip": true}}],
		"combo": 0.23, "cancel": 0.0, "recover": 0.38, "end": 0.52, "next": {"light": "L3", "heavy": "L2H"}},
	"L3": {"anim": "Sword_Regular_C", "from": 0.3, "speed": 1.55, "type": "light", "lunge": 7.0,
		"hits": [{"t": 0.28, "dmg": 16.0, "range": 2.6, "arc": 1.6, "knock": 4.0, "reaction": "stagger", "slash": {"roll": 1.45, "big": true}}],
		"combo": 0.34, "cancel": 0.0, "recover": 0.55, "end": 0.8, "next": {"light": "L4", "heavy": "L3H"}},
	"L4": {"anim": "Sword_Heavy_Combo", "from": 0.4, "speed": 1.6, "type": "finisher", "lunge": 6.0,
		"hits": [
			{"t": 0.3, "dmg": 10.0, "range": 2.6, "arc": 3.0, "knock": 1.0, "reaction": "flinch", "slash": {"roll": 0.2}},
			{"t": 0.6, "dmg": 10.0, "range": 2.6, "arc": 3.0, "knock": 1.0, "reaction": "flinch", "slash": {"roll": -0.6, "flip": true}},
			{"t": 0.95, "dmg": 26.0, "range": 3.0, "arc": 6.3, "knock": 11.0, "reaction": "knockback", "slash": {"roll": 0.0, "big": true}, "finisher": true}],
		"combo": 99.0, "cancel": 1.0, "recover": 1.15, "end": 1.4, "next": {}},
	"H1": {"anim": "Sword_Attack", "from": 0.15, "speed": 1.35, "type": "heavy", "lunge": 7.0,
		"hits": [{"t": 0.42, "dmg": 24.0, "range": 2.8, "arc": 2.0, "knock": 8.0, "reaction": "knockback", "slash": {"roll": 1.5, "big": true}}],
		"combo": 0.55, "cancel": 0.45, "recover": 0.7, "end": 1.0, "next": {"light": "L2", "heavy": "L2H"}},
	# L → P: estocada ascendente que lança o inimigo
	"L1H": {"anim": "Sword_Regular_C", "from": 0.35, "speed": 1.5, "type": "heavy", "lunge": 9.0,
		"hits": [{"t": 0.25, "dmg": 18.0, "range": 2.7, "arc": 1.6, "knock": 3.0, "launch": 7.5, "reaction": "launch", "slash": {"roll": 1.57, "big": true}}],
		"combo": 0.32, "cancel": 0.3, "recover": 0.55, "end": 0.75, "next": {"light": "L2", "heavy": "L3H"}},
	# L L → P: giro de área
	"L2H": {"anim": "Sword_Heavy_Combo", "from": 2.5, "speed": 1.5, "type": "heavy", "lunge": 3.0,
		"hits": [
			{"t": 0.3, "dmg": 14.0, "range": 3.1, "arc": 6.3, "knock": 3.0, "reaction": "stagger", "slash": {"roll": 0.0, "big": true}},
			{"t": 0.7, "dmg": 16.0, "range": 3.1, "arc": 6.3, "knock": 7.0, "reaction": "knockback", "slash": {"roll": 3.14, "big": true}}],
		"combo": 0.8, "cancel": 0.75, "recover": 0.9, "end": 1.1, "next": {"light": "L3", "heavy": "L3H"}},
	# L L L → P: FINALIZADOR — salto e golpe descendente com onda de choque
	"L3H": {"anim": "NinjaJump_Land", "speed": 1.15, "type": "finisher", "lunge": 4.0, "jump": 6.5,
		"hits": [{"t": 0.32, "dmg": 34.0, "range": 3.4, "arc": 6.3, "knock": 13.0, "launch": 4.0, "reaction": "knockback", "area": true, "finisher": true, "slash": {"roll": 1.57, "big": true}}],
		"combo": 99.0, "cancel": 0.45, "recover": 0.7, "end": 1.0, "next": {}},
	"DASH": {"anim": "Sword_Dash", "from": 0.2, "speed": 1.65, "type": "dash", "lunge": 11.0, "lunge_t": 0.22,
		"hits": [{"t": 0.22, "dmg": 16.0, "range": 2.6, "arc": 2.0, "knock": 6.0, "reaction": "stagger", "slash": {"roll": 1.5, "big": true}}],
		"combo": 0.3, "cancel": 0.28, "recover": 0.55, "end": 0.75, "next": {"light": "L2", "heavy": "L2H"}},
	"CTR": {"anim": "Sword_Regular_B", "speed": 1.7, "type": "counter", "lunge": 9.0,
		"hits": [{"t": 0.19, "dmg": 22.0, "range": 2.6, "arc": 2.4, "knock": 6.0, "reaction": "stagger", "slash": {"roll": 0.75, "flip": true, "big": true}}],
		"combo": 0.22, "cancel": 0.0, "recover": 0.35, "end": 0.5, "next": {"light": "L3", "heavy": "L2H"}},
}

const VIKTOR := {
	"start": {"light": "L1", "heavy": "H1", "dash": "DASH", "counter": "CTR"},
	"L1": {"anim": "Punch_Jab", "speed": 1.6, "type": "light", "lunge": 5.0, "ice": true,
		"hits": [{"t": 0.2, "dmg": 15.0, "range": 2.3, "arc": 1.8, "knock": 2.0, "reaction": "flinch"}],
		"combo": 0.24, "cancel": 0.0, "recover": 0.4, "end": 0.6, "next": {"light": "L2", "heavy": "L1H"}},
	"L2": {"anim": "Punch_Cross", "speed": 1.6, "type": "light", "lunge": 5.0, "ice": true,
		"hits": [{"t": 0.26, "dmg": 16.0, "range": 2.3, "arc": 1.8, "knock": 2.5, "reaction": "flinch"}],
		"combo": 0.3, "cancel": 0.0, "recover": 0.48, "end": 0.7, "next": {"light": "L3", "heavy": "L2H"}},
	"L3": {"anim": "Melee_Hook", "speed": 1.05, "type": "light", "lunge": 6.0, "ice": true,
		"hits": [{"t": 0.2, "dmg": 22.0, "range": 2.6, "arc": 2.0, "knock": 5.0, "reaction": "stagger"}],
		"combo": 0.24, "cancel": 0.0, "recover": 0.36, "end": 0.47, "next": {"light": "L4", "heavy": "L3H"}},
	"L4": {"anim": "Shield_Dash", "speed": 1.35, "type": "finisher", "lunge": 9.0, "lunge_t": 0.25, "ice": true,
		"hits": [{"t": 0.35, "dmg": 34.0, "range": 3.0, "arc": 6.3, "knock": 12.0, "reaction": "knockback", "area": true, "finisher": true}],
		"combo": 99.0, "cancel": 0.5, "recover": 0.7, "end": 1.0, "next": {}},
	"H1": {"anim": "OverhandThrow", "speed": 1.45, "type": "heavy", "lunge": 4.0, "ice": true,
		"hits": [{"t": 0.55, "dmg": 26.0, "range": 3.2, "arc": 1.4, "knock": 8.0, "reaction": "knockback", "spikes": 4}],
		"combo": 0.65, "cancel": 0.6, "recover": 0.85, "end": 1.1, "next": {"light": "L2", "heavy": "L2H"}},
	"L1H": {"anim": "Melee_Hook", "speed": 0.95, "type": "heavy", "lunge": 7.0, "ice": true,
		"hits": [{"t": 0.2, "dmg": 20.0, "range": 2.5, "arc": 1.8, "knock": 2.0, "launch": 8.0, "reaction": "launch"}],
		"combo": 0.24, "cancel": 0.24, "recover": 0.38, "end": 0.47, "next": {"light": "L2", "heavy": "L3H"}},
	"L2H": {"anim": "Shield_OneShot", "speed": 1.25, "type": "heavy", "lunge": 2.0, "ice": true,
		"hits": [{"t": 0.3, "dmg": 24.0, "range": 3.2, "arc": 6.3, "knock": 7.0, "reaction": "stagger", "area": true}],
		"combo": 0.4, "cancel": 0.36, "recover": 0.55, "end": 0.8, "next": {"light": "L3", "heavy": "L3H"}},
	"L3H": {"anim": "OverhandThrow", "speed": 1.3, "type": "finisher", "lunge": 3.0, "ice": true,
		"hits": [{"t": 0.55, "dmg": 38.0, "range": 7.0, "arc": 0.9, "knock": 12.0, "launch": 4.0, "reaction": "knockback", "spikes": 9, "finisher": true}],
		"combo": 99.0, "cancel": 0.7, "recover": 0.9, "end": 1.2, "next": {}},
	"DASH": {"anim": "Shield_Dash", "from": 0.1, "speed": 1.6, "type": "dash", "lunge": 11.0, "lunge_t": 0.22, "ice": true,
		"hits": [{"t": 0.22, "dmg": 18.0, "range": 2.6, "arc": 2.0, "knock": 6.0, "reaction": "stagger"}],
		"combo": 0.3, "cancel": 0.28, "recover": 0.5, "end": 0.75, "next": {"light": "L2", "heavy": "L2H"}},
	"CTR": {"anim": "Punch_Cross", "speed": 1.9, "type": "counter", "lunge": 9.0, "ice": true,
		"hits": [{"t": 0.26, "dmg": 24.0, "range": 2.6, "arc": 2.2, "knock": 6.0, "reaction": "stagger"}],
		"combo": 0.3, "cancel": 0.0, "recover": 0.45, "end": 0.65, "next": {"light": "L3", "heavy": "L2H"}},
}

## Perfis de impacto por tipo de golpe (hitstop, tremor, zoom, impacto de tela, câmera lenta)
const FEEL := {
	"light": {"hitstop": 0.05, "shake": 0.12, "kick": 1.5, "impact": 0.0, "slow": 0.0},
	"counter": {"hitstop": 0.08, "shake": 0.25, "kick": 4.0, "impact": 0.35, "slow": 0.0},
	"dash": {"hitstop": 0.06, "shake": 0.2, "kick": 3.0, "impact": 0.2, "slow": 0.0},
	"heavy": {"hitstop": 0.09, "shake": 0.3, "kick": 5.0, "impact": 0.5, "slow": 0.0},
	"finisher": {"hitstop": 0.14, "shake": 0.55, "kick": 9.0, "impact": 1.0, "slow": 0.35},
}

static func get_set(kit: String) -> Dictionary:
	return VIKTOR if kit == "viktor" else KIANA
