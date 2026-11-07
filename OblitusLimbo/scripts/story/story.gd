class_name Story
extends Node
## ROTEIRO — adaptação de "Oblitus Limbo: Volume I" (ByGuizo). Porte de story.js.
## Cada trecho é uma corrotina; D.abort() abandona o trecho atual (reinício na morte).

const DEATH_QUOTES := [
	"“Se eu não lembrava do que tinha feito, como eu podia garantir que não faria de novo?”",
	"“A gente segue lembrando, Kiana. Não da morte... mas do que veio antes dela.”",
	"“Você não nasceu para ser odiada, mas para ser a resposta que este mundo ainda não sabe que precisa.”",
	"“O tempo não cura todas as feridas, mas nos ensina a construir algo novo sobre as cicatrizes.”",
	"“Corações pesados são lentos. Corações partidos são fáceis de esmagar.”",
]

const CHAPTERS := [
	{"num": "PRÓLOGO", "name": "A Presença", "desc": "No coração do Limbo, uma entidade recebe uma notícia.", "segments": ["prologue"]},
	{"num": "CAPÍTULO I", "name": "Um Fogo que Não Pertence a Este Mundo", "desc": "Vardun. A taverna de Darius. Mais de vinte homens.", "segments": ["c1_vardun", "c1_tavern"]},
	{"num": "CAPÍTULO II", "name": "O Vale das Flores Sangrentas", "desc": "Oito dias presos num loop. Água, vento e fogo.", "segments": ["c2_valley", "c2_creature", "c2_road"]},
	{"num": "CAPÍTULO III", "name": "Oblitus Limbo", "desc": "O salão do trono de Hikari. O verdadeiro Quinto Presságio.", "segments": ["c3_throne", "c3_viktor", "epilogue"]},
]

const CODEX := [
	{"name": "Kiana", "ep": "A bardo de Vardun · narradora e protagonista", "img": "kiana", "pos": Vector2(0.55, 0.2), "text": "Meia-orc de “beleza improvável”, cabelos brancos como neve recém-assentada e olhos vermelhos que brilham no escuro. Encontrada por Tia Lanis na orla de uma floresta proibida, única sobrevivente do ataque de Gyotto ao orfanato. Carrega o ukulele às costas e a adaga de Kael à cintura. Seu Sigilo da Alma permanece um mistério."},
	{"name": "Near Shade", "ep": "O elfo da máscara", "img": "near", "pos": Vector2(0.5, 0.25), "text": "Elfo ladino de passos fantasmagóricos e olhos impossíveis de decifrar. Aprendeu a ler aos treze anos. Três anos de amizade com Kiana — e algo que cresce em silêncio."},
	{"name": "Amnon Akmenos", "ep": "O tiefling exilado", "img": "amnon", "pos": Vector2(0.45, 0.3), "text": "Expulso da própria linhagem, acusado de roubar a Relíquia de Nostradamus. Alegria “meio quebrada”. Segurou com as mãos nuas o núcleo em chamas da criatura do Vale."},
	{"name": "Darin Leafheart", "ep": "O druida dos lobos", "img": "darin", "pos": Vector2(0.5, 0.15), "text": "Sigilo Autoformado: Instinto de Caça — aura verde-esmeralda, manoplas translúcidas em forma de garras de lobo. Certa vez virou uma porca para atrair um rebanho fugido."},
	{"name": "Viktor Vanshee", "ep": "O Pilar do Gelo · “o picolé”", "img": "viktor", "pos": Vector2(0.5, 0.1), "text": "Meio-elfo nascido com o sigilo desperto — Herança Celestial: Manipulação do Gelo. Matou Gyotto, resgatou Kiana. Segundo o Mascarado, também tirou a vida de Gauss. No fim, o Mestre do Gelo manipulou o sol."},
	{"name": "Calista Vanshee", "ep": "A arqueira de EmberFall", "img": "calista", "pos": Vector2(0.42, 0.18), "text": "Esposa de Viktor. Manipulação de Fios de Sangue canalizada pelo arco. Leu as runas do Vale, desconfiou de Krauser primeiro — e deu a vida para purificar o marido."},
	{"name": "Yuto", "ep": "O ronin de passagem", "img": "yuto", "pos": Vector2(0.5, 0.12), "text": "Ronin viajante de voz serena — “uma pedra imóvel no meio de um rio turbulento”. Duas katanas, um galho mascado no canto da boca e um curativo no nariz. Salvou Darin no ataque das sombras e percebeu antes de todos que o pesadelo vinha do castelo."},
	{"name": "Lorde Krauser", "ep": "O verdadeiro Quinto Presságio", "img": "krauser", "pos": Vector2(0.5, 0.12), "text": "Híbrido humano-Draconato. Governou Hikari por dez anos sob identidade forjada. Tentáculos do Abismo e Armadura Arcana: Frio Absoluto. Derrotado por uma canção que ele mesmo pediu."},
	{"name": "Os Presságios", "ep": "Fios da Presença", "img": "ref", "pos": Vector2(0.92, 0.1), "text": "“Almas devoradas pela própria ambição. Homens e mulheres que entregaram a única coisa que realmente possuíam: o próprio livre-arbítrio.” Numerados — o Quinto, o Sexto. A Presença os chama de Fios."},
]

func chapters() -> Array:
	return CHAPTERS

func chapters_meta() -> Array:
	return CHAPTERS

## Executa um trecho pelo nome (o main aguarda o retorno).
func run(seg: String) -> void:
	match seg:
		"prologue": await prologue()
		"c1_vardun": await c1_vardun()
		"c1_tavern": await c1_tavern()
		"c2_valley": await c2_valley()
		"c2_creature": await c2_creature()
		"c2_road": await c2_road()
		"c3_throne": await c3_throne()
		"c3_viktor": await c3_viktor()
		"epilogue": await epilogue()

# =====================================================================
#  Utilidades de cena
# =====================================================================
static func v(x: float, y: float, z: float) -> Vector3:
	return Vector3(x, y, z)

static func diff() -> float:
	return Game.difficulty

func spawn(a: Node) -> Node:
	Game.world.add_child(a)
	return a

func npc(id: String, pos: Vector3, yaw := 0.0, nm := "", o := {}) -> Npc:
	var n := Npc.new()
	var oo := {"pos": pos, "yaw": yaw, "name": nm if nm != "" else id}
	oo.merge(o, true)
	n.setup_npc(id, oo)
	spawn(n)
	return n

func ally(id: String, pos: Vector3, role: String, nm: String, ang: float) -> Ally:
	var a := Ally.new()
	a.setup_ally(id, {"pos": pos, "role": role, "name": nm, "ang": ang})
	spawn(a)
	return a

func thug(o: Dictionary) -> Thug:
	var t := Thug.new()
	t.setup_thug(o)
	spawn(t)
	return t

func archer(o: Dictionary) -> Archer:
	var a := Archer.new()
	a.setup_archer(o)
	spawn(a)
	return a

static func face(a, target) -> void:
	if typeof(target) == TYPE_OBJECT and not is_instance_valid(target):
		return
	var p: Vector3 = target.global_position if target is Node3D else target
	a.yaw = Game.yaw_to(a.global_position, p)
	a.rotation.y = a.yaw

static func put(a, p: Vector3) -> void:
	a.global_position = p
	if a is CharacterBody3D:
		(a as CharacterBody3D).velocity = Vector3.ZERO
	if a.get("move_vel") != null:
		a.move_vel = Vector3.ZERO
		a.knock = Vector3.ZERO

## Animações nomeadas do roteiro (equivalentes do UAL)
static func pose(a, kind: String, o := {}) -> void:
	var r: CharRig = a.rig
	match kind:
		"kneel": r.play("Fixing_Kneeling", {"loop": true, "blend": o.get("blend", 0.25)})
		"lie":
			if o.get("instant", true):
				r.play("Death01", {"hold": true, "blend": 0.0, "freeze_end": true})
			else:
				r.play("Death01", {"hold": true, "blend": 0.3})
		"float": r.play("Swim_Idle", {"loop": true})
		"point": r.play("Interact", {"hold": true})
		"roar": r.play("Idle_Shield_Break", {"speed": o.get("speed", 1.0)})
		"grab": r.play("Push", {"hold": true})
		"claw": r.play("Melee_Hook", {"speed": o.get("speed", 1.0)})
		"atk1": r.play("Sword_Regular_A")
		"atk3": r.play("Sword_Regular_C", {"speed": o.get("speed", 1.0)})
		"punch": r.play("Punch_Cross", {"speed": o.get("speed", 1.0)})
		"guard": r.play("Sword_Block", {"hold": true})
		"hit": r.play("Hit_Head")
		"death": r.play("Death01", {"hold": true})
		"knock": r.play("Hit_Knockback")
		"talk": r.play("Idle_Talking", {"loop": true})
		"fold": r.play("Idle_FoldArms", {"loop": true})
		"sit": r.play("Sitting_Idle", {"loop": true})
		"spell": r.play("Spell_Simple_Idle", {"loop": true})
		"stop": r.stop_action(0.25)

## Tomada orbital em torno de um ponto.
func orbit(center: Vector3, r: float, h: float, a0: float, a1: float, dur: float, look_h := 1.4) -> Dictionary:
	return {"pos": center, "look": center, "dur": dur, "blend": 0.0001, "track": func(t: float) -> Dictionary:
		var a: float = a0 + (a1 - a0) * minf(1.0, t / dur)
		return {"pos": center + Vector3(sin(a) * r, h, cos(a) * r), "look": center + Vector3(0, look_h, 0)}}

## Tomada sobre o ombro de A olhando para B.
func ots(a, b, o := {}) -> Dictionary:
	var side: float = o.get("side", 1.0)
	var dist: float = o.get("dist", 1.6)
	var h: float = o.get("h", 1.55)
	var dir: Vector3 = (b.global_position - a.global_position)
	dir.y = 0
	dir = dir.normalized()
	var right := Vector3(-dir.z, 0, dir.x) * side
	var pos: Vector3 = a.global_position - dir * dist + right * 0.7 + Vector3(0, h, 0)
	var bh: float = b.height * 0.85 if b.get("height") else 1.5
	var look: Vector3 = b.global_position + Vector3(0, bh, 0)
	return {"pos": pos, "look": look, "pos2": pos + dir * 0.25, "look2": look, "fov": o.get("fov", 42.0), "dur": o.get("dur", 4.0), "blend": o.get("blend", 0.6)}

func closeup(a, o := {}) -> Dictionary:
	var f: Vector3 = Game.fwd(a.yaw)
	var r := Vector3(-f.z, 0, f.x)
	var head: Vector3 = a.head_pos(-0.08 + o.get("h", 0.0))
	var pos: Vector3 = head + f * o.get("dist", 1.5) + r * o.get("side", 0.4)
	return {"pos": pos, "look": head, "pos2": pos - f * 0.2, "look2": head, "fov": o.get("fov", 38.0), "dur": o.get("dur", 4.0), "blend": o.get("blend", 0.6)}

static func L(who: String, text: String, fn := Callable()) -> Dictionary:
	var d := {"who": who, "text": text}
	if fn.is_valid():
		d["fn"] = fn
	return d

func sfx(n: String, vol := 1.0, pitch := 1.0) -> void:
	Audio.sfx(n, vol, pitch)

func shake(a: float) -> void:
	Game.cam.shake(a)

func flash(a: float) -> void:
	Game.post.flash = a

func kill_enemies_except(keep) -> void:
	for a in Game.actors.duplicate():
		if is_instance_valid(a) and a != keep and a.team == "enemy" and a.alive:
			a.die()

# =====================================================================
#  TELA-TÍTULO — Vardun ao luar
# =====================================================================
func title_scene(first := false) -> void:
	await Game.main.load_level("vardun", {"label": "DESPERTANDO VARDUN" if first else "CARREGANDO"})
	var k := npc("kiana", v(0.6, 0, -18), 0.25, "Kiana")
	var n := npc("near", v(-2.8, 0, -12), 2.6, "Near")
	pose(n, "kneel")
	for i in 4:
		npc("townsfolk", v(randf_range(-3, 3), 0, randf_range(-4, 30)), randf() * TAU, "", {"rig": {"seed": i * 13 + 5}, "wander": 2.0})
	Game.ui.show_hud(false)
	Game.cam.shot({"pos": v(0, 3, -26), "look": v(0, 2, -10), "dur": 600.0, "blend": 0.0001, "track": func(t: float) -> Dictionary:
		var a: float = -0.6 + sin(t * 0.05) * 0.5
		return {"pos": v(0.6 + sin(a) * 6.5, 2.0 + sin(t * 0.07) * 0.4, -18 - cos(a) * 6.5), "look": v(0.6 + sin(t * 0.04) * 0.6, 2.3, -18)}})
	Audio.music("title", 2.0)
	Audio.stop_loops()
	Audio.loop("wind", true, 0.4)

# =====================================================================
#  PRÓLOGO — A PRESENÇA
# =====================================================================
func prologue() -> void:
	Game.ui.show_hud(false)
	await D.fade(1, 0.01)
	await D.load_level("limbo", {"label": "O LIMBO"})
	Audio.music("limbo", 2.0)
	Audio.stop_loops()
	Audio.loop("rumble", true, 0.8)
	var seg := npc("shadow", v(0, 0, 4), 0.0, "A Segunda", {"rig": {"scale": 1.05}})
	seg.flying = true
	seg.fly_height = 0.4
	pose(seg, "float")
	var tears: Dictionary = Game.fx.custom(9999.0, func(_t, _dt):
		if randf() < 0.15:
			Game.fx.burst("blood", seg.head_pos(-0.1) + Game.fwd(seg.yaw) * 0.1, {"n": 1}))
	D.cine(true)
	Game.ui.show_hud(false)
	Game.cam.shot({"pos": v(0, 2, -10), "look": v(0, 4, 30), "pos2": v(0, 2.6, -2), "look2": v(0, 4.5, 30), "dur": 14.0, "blend": 0.0001, "fov": 50.0})
	await D.fade(0, 3)
	await D.card({"c3": "No coração do Limbo, a escuridão não era o fim do dia.\nEra uma entidade viva, pulsante,\ncomo as paredes de um estômago faminto.", "dur": 6.5, "cls": "clear"})
	Game.cam.shot({"pos": v(1.6, 2.6, 1.6), "look": seg.head_pos(), "dur": 8.0, "fov": 40.0})
	await D.say([L("segunda", "Mestre... o Quinto Fio foi cortado.")], true)
	sfx("heartbeat", 1.5)
	shake(0.5)
	Game.cam.shot({"pos": v(0, 3, -1), "look": v(0, 4.5, 30), "pos2": v(0, 3.5, 6), "dur": 10.0, "fov": 45.0})
	var rumble := func():
		sfx("heartbeat", 1.4)
		shake(0.45)
	await D.say([
		L("presenca", "E a Peça Perdida?", rumble),
		L("segunda", "Continua oculta. Mas, ao perecer, ele arrastou consigo *Aquele que Sabe*... e seus companheiros."),
		L("presenca", "...", func():
			rumble.call()
			sfx("reveal", 0.5)),
		L("presenca", "Não os cace. Deixe-os vagar pelo desespero das terras esquecidas.", rumble),
		L("presenca", "Eles acham que sobreviveram a uma batalha, mas apenas entraram no matadouro por vontade própria.", rumble),
		L("presenca", "Vigie, Segunda. A caçada não acabou. Ela apenas se tornou... *doméstica*.", func():
			rumble.call()
			flash(0.3)),
	], true)
	tears.kill = true
	await D.fade(1, 2.5)
	Audio.stop_loops()
	await D.card({"c3": "Mas toda queda tem um começo.", "dur": 3.2})

# =====================================================================
#  CAPÍTULO I — UM FOGO QUE NÃO PERTENCE A ESTE MUNDO
# =====================================================================
func c1_vardun() -> void:
	await D.fade(1, 0.01)
	await D.card({"c1": "CAPÍTULO I", "c2": "Um Fogo que Não Pertence a Este Mundo", "c3": "Vardun", "dur": 5.0})
	await D.load_level("vardun", {"player": "kiana", "label": "VARDUN"})
	var Lv: LevelBase = Game.level
	Audio.music("vardun", 2.0)
	Audio.stop_loops()
	Audio.loop("wind", true, 0.35)
	var P: Player = Game.player
	var mira := npc("mira", Lv.points.mira, -1.2, "Velha Mira")
	var rurik := npc("rurik", Lv.points.rurik, PI / 2.0, "Rurik")
	var near := npc("near", Lv.points.near, PI / 2.0 + 0.4, "Near")
	pose(rurik, "fold")
	for i in 7:
		npc("townsfolk", v(randf_range(-3, 3), 0, randf_range(-20, 34)), randf() * TAU, "", {"rig": {"seed": i * 31 + 2}, "wander": 2.5})
	Game.ui.quest("A Fúria de Vardun", "")
	D.cine(true)
	D.shot({"pos": v(2, 7, 30), "look": v(0, 1, -10), "pos2": v(1.5, 2.6, -16), "look2": P.head_pos(), "dur": 8.0, "blend": 0.0001, "fov": 55.0})
	await D.fade(0, 2.5)
	await D.wait(6.5)
	D.shot(closeup(P, {"dur": 6.0, "dist": 1.7}))
	await D.say([
		L("kiana", "Três dias desde o aniversário do Viktor. Três dias desde que encontraram a Lili naquela viela."),
		L("kiana", "Ele pegou a adaga do Kael, me olhou como quem já tinha decidido tudo — “Vou acabar com isso” — e sumiu na noite."),
		L("kiana", "Ninguém em Vardun diz nada. Mas todo mundo sabe de alguma coisa."),
	])
	Game.ui.toast("WASD mover · Mouse câmera · Shift correr", Color("e8dcc0"), 3.5)
	D.objective("A Fúria de Vardun", "Despeça-se de Lili no memorial", Lv.points.memorial)
	await D.interact(mira, 2.6, "Falar com a Velha Mira")
	face(P, mira)
	face(mira, P)
	D.cine(true)
	D.shot(ots(P, mira, {"dur": 30.0}))
	pose(mira, "talk")
	await D.say([
		L("mira", "Ela gostava de morder frutas azedas demais só pra rir do próprio susto. Você lembra?"),
		L("kiana", "Lembro. Ela merecia mais do que uma viela escura e um bando de covardes."),
		L("mira", "A gente segue lembrando, Kiana. Não da morte... mas do que veio antes dela.", func(): D.shot(closeup(mira, {"dur": 8.0, "dist": 1.3}))),
		L("mira", "E você, minha menina, tem algo dentro de si que ainda não compreendeu."),
		L("mira", "*Um fogo que não pertence a este mundo.*", func():
			sfx("reveal", 0.4)
			Game.fx.burst("ember", P.global_position, {"n": 25, "r": 1.0})),
		L("kiana", "Fogo? Vovó Mira, eu mal consigo controlar o meu rubor.", func(): D.shot(closeup(P, {"dur": 6.0}))),
		L("mira", "Hehe. Vá. O Rurik sabe mais do que diz."),
	])
	pose(mira, "stop")
	Game.ui.quest_done()
	D.objective(null, "Vá até a Taverna de Rurik", Lv.points.rurik)
	var near_spoke := [false]
	D.task(func():
		await D.reach(near.global_position, 4.5)
		if not near_spoke[0]:
			near_spoke[0] = true
			Game.ui.bark("near", "Kiana. Você não dormiu de novo, né?", 3.5))
	await D.interact(rurik, 2.6, "Falar com Rurik")
	face(P, rurik)
	face(rurik, P)
	D.cine(true)
	D.shot(ots(P, rurik, {"dur": 30.0, "side": -1.0}))
	await D.say([
		L("kiana", "Três dias, Rurik. Nenhuma notícia. E você aí, polindo copo como se nada estivesse acontecendo."),
		L("rurik", "O Viktor sabe se cuidar, garota."),
		L("kiana", "Ele é SEU FILHO! Como você consegue ficar parado?!", func():
			shake(0.2)
			D.shot(closeup(rurik, {"dur": 8.0, "dist": 1.6, "h": 0.1}))),
		L("rurik", "..."),
		L("rurik", "Darius. O Viktor estava atrás do Darius."),
		L("kiana", "O maior criminoso de Vardun. Ótimo.", func(): D.shot(closeup(P, {"dur": 6.0}))),
		L("rurik", "Kiana. Não vá sozinha."),
		L("kiana", "Eu vou resolver isso. Sozinha."),
	])
	Game.ui.bark("near", "Kiana, espera—", 2.5)
	Game.ui.quest_done()
	D.objective(null, "Encontre a taverna de Darius no bairro pobre", Lv.points.darius)
	await D.reach(Lv.points.darius, 2.4)
	D.cine(true)
	D.shot({"pos": P.global_position + v(2.5, 1.4, -2.5), "look": v(0, 2.5, 41), "dur": 4.0, "fov": 45.0})
	await D.say([L("kiana", "Um tumor antigo, sufocado entre construções tortas. Combina com o dono.")], true)
	sfx("whoosh")
	await D.fade(1, 1.4)

func c1_tavern() -> void:
	await D.fade(1, 0.01)
	await D.load_level("tavern", {"player": "kiana", "label": "A TAVERNA DE DARIUS"})
	var Lv: LevelBase = Game.level
	Audio.music("silence", 1.0)
	Audio.stop_loops()
	Audio.loop("fire", true, 0.5)
	Audio.loop("tavern", true, 0.3)
	var P: Player = Game.player
	Game.ui.quest("A Fúria de Vardun", "Confronte Darius")
	var dar := npc("darius", Lv.points.darius, PI, "Darius")
	pose(dar, "fold")
	var spots := [[-3.5, 1.5], [3.5, 2.0], [-5.5, -1.5], [5.5, -2.0], [-2.0, 5.2], [2.5, 5.6]]
	var thugs := []
	for i in spots.size():
		var t := thug({"pos": v(spots[i][0], 0, spots[i][1]), "seed": i * 7 + 3})
		face(t, P)
		t.ai = "spawn"
		thugs.append(t)
	D.cine(true)
	D.shot({"pos": v(2.2, 1.9, -9.4 + 1.0), "look": v(0, 1.3, 3), "pos2": v(1.6, 1.7, -6.6), "dur": 6.0, "blend": 0.0001, "fov": 50.0})
	await D.fade(0, 2)
	sfx("step_wood")
	await D.wait(1.5)
	D.shot(closeup(dar, {"dur": 10.0, "dist": 2.2, "side": 0.6, "fov": 40.0}))
	await D.say([
		L("darius", "Ora, ora. A aberração de estimação do Vanshee."),
		L("kiana", "Onde ele está, Darius?", func(): D.shot(ots(P, dar, {"dur": 20.0}))),
		L("darius", "Eu só fiz o trabalho sujo, menina. Um mascarado apareceu do nada... obrigou meus rapazes a caçar aqueles tieflings."),
		L("darius", "E o mestre desse mascarado queria o seu Viktor. *Vivo*."),
		L("kiana", "O que vocês fizeram com ele?!"),
		L("darius", "Rapazes... façam o que quiserem com ela.", func():
			dar.snap_face(0.0)
			sfx("grunt")),
	], true)
	var awaken_aura := [null]
	D.shot(closeup(P, {"dur": 8.0, "dist": 1.0, "fov": 34.0, "roll": -0.15}))
	Game.post.vig = 0.5
	await D.say([
		L("kiana", "Todo mundo sempre machuca quem eu amo. E eu nunca consigo fazer nada. Nunca consigo proteger ninguém."),
		L("kiana", "Já que vocês machucaram ele...", func(): sfx("heartbeat", 1.5)),
		L("kiana", "*VOU MATAR TODOS VOCÊS!*", func():
			Game.flags["apagao"] = true
			sfx("fury")
			shake(0.6)
			P.rig.set_face(true)
			P.rig.set_eye_glow(Color(1.0, 0.1, 0.1))
			awaken_aura[0] = Game.fx.aura(P, Color(0.9, 0.02, 0.08), Color(0.1, 0.0, 0.03), 2.2)
			Game.fx.shockwave(P.global_position, Color(1, 0.06, 0.12), 6.0, {"glow": Color(1.0, 0.05, 0.1)})
			Game.post.impact_frames(0.08, Color(1.0, 0.85, 0.88))),
	], true)
	Game.fx.aura_end(awaken_aura[0])
	Game.flags["apagao"] = false
	Game.post.vig = 0.0
	P.rig.set_eye_glow(Color.BLACK)
	dar.queue_free()
	D.cine(false)
	Game.in_combat = true
	Audio.music("battle", 0.5)
	Audio.intensity(0.5)
	P.fury = 100.0
	Game.ui.toast("A FÚRIA TRANSBORDA — SEGURE [F]: APAGÃO · [F]: ULTIMATE", Color("ff3030"), 3.5)
	Game.ui.bark("narr", "Clique esq.: leve · Clique dir.: pesado (L L P = finalização) · Espaço: esquiva (cancela golpes) · C: defender · Q: travar alvo", 9.0)
	# ---- ondas ----
	var killed := [0]
	var total := 19
	var upd := func(): Game.ui.kill_count("HOMENS DE DARIUS · %d / %d" % [killed[0], total])
	upd.call()
	D.listen("kill", func(e):
		if e is Thug or e is Archer:
			killed[0] += 1
			upd.call())
	D.objective(null, "Sobreviva aos homens de Darius", null)
	for t in thugs:
		t.ai = "approach"
		t.cd = randf_range(0.2, 1.5)
	await D.until(func(): return thugs.all(func(t): return not is_instance_valid(t) or not t.alive))
	var doors := [Lv.points.doorBack, Lv.points.doorRight, Lv.points.doorLeft, Lv.points.stairs]
	Game.ui.bark("darius", "Que diabos estão esperando?! PEGUEM ELA!", 3.0)
	Audio.intensity(0.7)
	var w := await _spawn_wave(["thug", "thug", "archer", "thug", "thug", "archer"], doors)
	await D.until(func(): return w.all(func(t): return not is_instance_valid(t) or not t.alive))
	await D.wait(1)
	Game.ui.bark("capanga", "Ela... ela não é humana!", 2.5)
	w = await _spawn_wave(["heavy", "thug", "archer", "thug", "heavy", "thug", "archer"], doors)
	await D.until(func(): return w.all(func(t): return not is_instance_valid(t) or not t.alive))
	Game.ui.kill_count("")
	# ---- Darius ----
	await D.wait(0.8)
	D.cine(true)
	var boss := Darius.new()
	boss.setup_darius({"pos": v(0, 0, 6.5), "yaw": PI, "hp": roundf(720.0 * diff())})
	spawn(boss)
	face(boss, P)
	D.shot({"pos": v(1.5, 1.2, 3.5), "look": boss.head_pos(), "pos2": v(1.0, 1.0, 4.2), "dur": 4.0, "fov": 40.0})
	pose(boss, "roar")
	sfx("roar")
	await D.say([L("darius", "Inúteis. Todos vocês. Eu mesmo faço isso.")], true)
	D.cine(false)
	Game.ui.boss(boss)
	Audio.music("boss_darius", 0.6)
	D.objective(null, "Derrote Darius", null)
	boss.min_hp = 1.0
	D.listen("bossPhase", func(e):
		if e.boss != boss:
			return
		Game.ui.bark("darius", "ACABEM COM ESSA ABERRAÇÃO!", 3.0)
		_spawn_wave(["thug", "archer", "thug", "heavy"], doors))
	await D.until(func(): return boss.hp <= 1.0)
	# ---- golpe final ----
	boss.invulnerable = true
	boss.clear_pending()
	boss.busy = true
	kill_enemies_except(boss)
	D.cine(true)
	Game.ui.boss(null)
	Game.slow(2.5, 0.25)
	Game.flags["apagao"] = true
	put(P, boss.global_position + Game.fwd(boss.yaw) * 1.3)
	face(P, boss)
	Game.fx.burst("shadow", P.global_position + v(0, 1, 0), {"n": 40, "r": 0.5, "speed": 2.0})
	D.shot({"pos": boss.global_position + v(2.4, 1.3, 0.4), "look": P.global_position.lerp(boss.global_position, 0.5) + v(0, 1.4, 0), "dur": 3.0, "fov": 36.0, "cut": true})
	pose(P, "atk3", {"speed": 0.8})
	sfx("blink")
	await D.wait(0.25)
	sfx("crit")
	shake(0.7)
	flash(0.3)
	Game.post.impact_frames(0.09, Color(1.0, 0.85, 0.88))
	Game.fx.impact(boss.chest_pos(), Color(1, 0.2, 0.25), 4.0)
	Game.fx.shockwave(boss.global_position, Color(1, 0.1, 0.15), 4.0, {"glow": Color(1.0, 0.1, 0.12)})
	Game.fx.burst("blood", boss.chest_pos(), {"n": 30})
	Game.fx.burst("spark", boss.chest_pos(), {"n": 30, "color": Color.WHITE})
	pose(boss, "kneel")
	await D.wait(0.6)
	Game.ui.toast("Darius morreu sem entender como morreu tão rápido.", Color("e8dcc0"), 3.0)
	boss.min_hp = -1.0
	boss.invulnerable = false
	boss.hp = 0.0
	boss.die(P)
	await D.wait(0.7)
	Game.flags["apagao"] = false
	P.rig.set_face(false)
	Audio.music("silence", 2.0)
	await D.fade(1, 2)
	await D.card({"cls": "memory", "c3": "“Minha memória daquela noite não era um borrão. Era um buraco.\nUm abismo negro onde o tempo tinha sumido.”", "dur": 6.0})
	await D.card({"cls": "memory", "c3": "“Eu lembrava de entrar na taverna...\ne depois, lembrava de estar parada no meio de corpos mutilados.\nO meio — o grito, o corte, a fúria — tinha sido roubado de mim.”", "dur": 7.0})
	# Near chega
	pose(P, "kneel")
	Game.in_combat = false
	var near := npc("near", Lv.points.doorBack + v(0, 0, 1), 0.0, "Near")
	face(near, P)
	D.shot({"pos": P.global_position + v(-2.2, 1.0, -1.6), "look": P.head_pos(-0.5), "dur": 8.0, "blend": 0.0001, "fov": 40.0})
	await D.fade(0, 2)
	await D.say([
		L("near", "Kiana...?"),
		L("kiana", "...Near? O que... o que aconteceu aqui?"),
		L("near", "...", func(): D.shot(closeup(near, {"dur": 6.0}))),
		L("near", "Você não lembra."),
		L("kiana", "Tem uma carta. Debaixo dele. Ensanguentada.", func(): D.shot(closeup(P, {"dur": 6.0, "h": -0.3}))),
	], true)
	await D.fade(1, 1.5)
	Audio.stop_loops()
	await D.card({"cls": "diary", "c1": "A CARTA ENSANGUENTADA", "c3": "“...Calista retorna de EmberFall...\n...a cidade murada de Hikari...\n...algum dos presságios está escondido...”", "dur": 7.0})
	await D.card({"c3": "O sangue seco sob as unhas levou três dias para sair.\nE uma certeza muda ficou no peito:\nalgo dentro dela sabia exatamente como matar.\nE esse algo estava acordado.", "dur": 8.0})

func _spawn_wave(defs: Array, doors: Array) -> Array:
	var tok := D.token
	var list := []
	for i in defs.size():
		if tok != D.token:
			return list
		var d: String = defs[i]
		var at: Vector3 = doors[i % doors.size()] + v(randf_range(-0.6, 0.6), 0, randf_range(-0.6, 0.6))
		Game.fx.burst("dust", at, {"n": 8})
		var e
		if d == "archer":
			e = archer({"pos": at, "seed": 4 + i})
		else:
			e = thug({"pos": at, "seed": i * 11 + (2 if d == "heavy" else 1), "weapon": "axe_A" if d == "heavy" else "", "hp": 80.0 if d == "heavy" else 42.0})
		if Game.player:
			face(e, Game.player)
		list.append(e)
		if i % 2 == 1:
			await D.wait(0.9)
	return list

# =====================================================================
#  CAPÍTULO II — O VALE DAS FLORES SANGRENTAS
# =====================================================================
func c2_valley() -> void:
	await D.fade(1, 0.01)
	await D.card({"c1": "CAPÍTULO II", "c2": "O Vale das Flores Sangrentas", "c3": "Entre Vardun e Hikari", "dur": 5.0})
	Audio.music("valley", 2.0)
	await D.card({"cls": "diary", "c1": "DIÁRIO DE KIANA — DIA 1", "c3": "Near, Amnon e Darin estavam no portão de Vardun, mochilas nas costas.\nNinguém perguntou nada. Eu também não expliquei.", "dur": 6.0})
	await D.card({"cls": "diary", "c1": "DIA 3", "c3": "A comida acabou.", "dur": 3.0})
	await D.card({"cls": "diary", "c1": "DIA 5", "c3": "As árvores são as mesmas. Eu juro que são as mesmas árvores.", "dur": 4.0})
	await D.card({"cls": "diary", "c1": "DIA 7", "c3": "Amnon tentou morder o braço do Darin durante a vigília.\n“Só um pedacinho”, ele disse.", "dur": 5.0})
	await D.load_level("valley", {"player": "kiana", "label": "O VALE DAS FLORES SANGRENTAS"})
	var Lv = Game.level
	Audio.stop_loops()
	Audio.loop("wind", true, 0.5)
	Audio.loop("fire", true, 0.3)
	var P: Player = Game.player
	var near := npc("near", v(-2.2, 0, 1.4), 2.2, "Near")
	pose(near, "kneel")
	var amnon := npc("amnon", v(1.9, 0, -2.0), -0.5, "Amnon")
	pose(amnon, "lie", {"instant": true})
	var darin := npc("darin", Lv.points.tree + v(-0.6, 0, -0.9), 0.0, "Darin")
	face(darin, v(5, 0, 9))
	Game.ui.quest("O Vale das Flores Sangrentas", "")
	D.cine(true)
	D.shot({"pos": v(-9, 5, -9), "look": v(0, 1, 0), "pos2": v(-4, 2.4, -6), "look2": P.head_pos(), "dur": 7.0, "blend": 0.0001, "fov": 50.0})
	await D.fade(0, 2.5)
	await D.wait(5)
	D.shot(closeup(P, {"dur": 8.0}))
	await D.say([
		L("kiana", "Dia oito. As flores têm um cheiro doce e ferroso..."),
		L("kiana", "O mesmo cheiro que impregnava as minhas roupas quando acordei naquela taverna."),
		L("amnon", "Se eu morrer aqui, fico devendo dez pratas pro Darin no outro mundo. Inaceitável.", func(): D.shot(closeup(amnon, {"dur": 6.0, "dist": 1.6, "h": -0.6}))),
		L("darin", "Kiana... vem cá. Olha essa casca."),
	])
	D.objective(null, "Examine a árvore com Darin", Lv.points.tree)
	# o loop espacial
	var loops := [0]
	var loop_fx: Dictionary = Game.fx.custom(99999.0, func(_t, _dt):
		var p := P.global_position
		var d := Vector2(p.x, p.z).length()
		if d > 20.5 and not Game.cine:
			put(P, v(-p.x * 0.92, p.y, -p.z * 0.92))
			Game.cam.snap_to_player()
			flash(0.35)
			sfx("whoosh", 0.5)
			loops[0] += 1
			Game.ui.toast("...as mesmas árvores." if loops[0] < 2 else "O vale te devolve ao mesmo lugar.", Color("c0a0b0"), 2.0))
	await D.interact(darin, 2.4, "Examinar a árvore")
	loop_fx.kill = true
	D.cine(true)
	face(darin, v(5, 0, 9))
	D.shot({"pos": v(2.6, 1.8, 6.2), "look": v(5, 1.6, 9), "dur": 8.0, "fov": 42.0})
	pose(darin, "point")
	await D.say([L("darin", "Tem alguma coisa aqui. Debaixo da madeira...")], true)
	sfx("magic", 1.0, 0.75)
	sfx("reveal", 0.5)
	Game.fx.custom(2.0, func(t, _dt): Lv.set_runes(minf(1.0, t / 1.5)), func(): Lv.set_runes(1.0))
	Game.fx.burst("magic", v(5, 1.6, 9), {"n": 40, "color": Color(0.38, 0.69, 1.0)})
	await D.wait(1.5)
	pose(darin, "stop")
	await D.say([
		L("darin", "Runas. Escondidas na própria árvore. Despertaram quando eu toquei."),
		L("amnon", "Ótimo. Alguém aqui lê árvore?"),
		L("near", "...Tem alguém atrás de você, Kiana.", func(): D.shot(closeup(near, {"dur": 4.0}))),
	], true)
	# Calista surge e desarma Kiana
	var cal := npc("calista", P.global_position - Game.fwd(P.yaw) * 1.6, 0.0, "Encapuzada")
	face(cal, P)
	face(P, cal)
	Game.fx.burst("smoke", cal.global_position, {"n": 15, "r": 0.6})
	D.shot(ots(P, cal, {"dur": 5.0, "fov": 40.0, "blend": 0.3}))
	pose(P, "atk1")
	await D.wait(0.15)
	pose(cal, "claw")
	sfx("parry")
	shake(0.3)
	if P.rig.weapon:
		P.rig.weapon.visible = false
	var blade := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.03, 0.35, 0.06)
	blade.mesh = bm
	var gm := StandardMaterial3D.new()
	gm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	gm.albedo_color = Color(0.62, 0.88, 1.0) * 1.5
	blade.material_override = gm
	Game.world.add_child(blade)
	var from := P.chest_pos()
	var land := P.global_position + Game.fwd(P.yaw) * 3.0 + v(0, 0.15, 0)
	Game.fx.custom(0.7, func(t, _dt):
		var f: float = t / 0.7
		blade.global_position = from.lerp(land, f) + v(0, sin(f * PI) * 1.5, 0)
		blade.rotation.z += 0.5)
	await D.wait(0.8)
	await D.say([
		L("calista", "Lenta demais, pequena."),
		L("kiana", "...Calista?!", func(): D.shot(closeup(P, {"dur": 4.0}))),
		L("calista", "Oito dias andando em círculos. O Viktor teria vergonha de vocês.", func(): D.shot(closeup(cal, {"dur": 10.0, "dist": 1.4}))),
		L("calista", "Eu sei ler runas. Não tanto quanto o Viktor, claro."),
		L("calista", "Isto é uma *barreira do infinito*. A criatura que mantém este loop vive do outro lado. Há uns vinte anos."),
		L("kiana", "Então a gente atravessa."),
		L("calista", "Fiquem juntos. E não morram. Eu não vou explicar pro Viktor que perdi os filhotes dele."),
	], true)
	blade.queue_free()
	if P.rig.weapon:
		P.rig.weapon.visible = true
	D.shot({"pos": v(1.2, 2.2, 3.2), "look": v(5, 1.6, 9), "dur": 5.0, "fov": 50.0})
	sfx("portal")
	Game.fx.custom(3.0, func(_t, _dt): Game.fx.burst("magic", v(5 + randf_range(-1, 1), randf_range(0.5, 3), 9 + randf_range(-1, 1)), {"n": 3, "color": Color(0.38, 0.69, 1.0), "speed": 2.0}))
	await D.wait(2)
	flash(1.0)
	await D.fade(1, 1)
	Game.post.flash = 0.0

func c2_creature() -> void:
	await D.fade(1, 0.01)
	await D.load_level("domain", {"player": "kiana", "pos": v(0, 0, -9), "yaw": 0.0, "label": "A BARREIRA DO INFINITO"})
	Audio.music("silence", 1.0)
	Audio.stop_loops()
	Audio.loop("wind", true, 0.3)
	var P: Player = Game.player
	var near := ally("near", v(-2, 0, -10), "melee", "Near", 3.6)
	near.down_text = "Ngh—!"
	var amnon := ally("amnon", v(2, 0, -10.5), "ranged", "Amnon", 5.2)
	var darin := ally("darin", v(-3.5, 0, -8), "melee", "Darin", 0.6)
	var cal := ally("calista", v(3.5, 0, -8.5), "ranged", "Calista", 2.2)
	var allies := [near, amnon, darin, cal]
	for a in allies:
		a.scripted = true
	var boss := Elemental.new()
	boss.setup_elemental({"pos": v(0, 0, 6), "yaw": PI, "hp": roundf(1700.0 * diff())})
	spawn(boss)
	boss.invulnerable = true
	boss.rig.position.y = -5.0
	Game.ui.quest("O Vale das Flores Sangrentas", "Derrote a criatura do vale")
	D.cine(true)
	D.shot({"pos": v(0, 1.6, -13), "look": v(0, 1.2, 6), "dur": 6.0, "blend": 0.0001, "fov": 50.0})
	await D.fade(0, 2)
	sfx("splash")
	sfx("roar", 1.0, 0.6)
	shake(0.6)
	D.shot(orbit(v(0, 0, 6), 9.0, 2.2, -2.6, -3.6, 5.0, 3.0))
	Game.fx.custom(2.5, func(t, _dt):
		boss.rig.position.y = -5.0 + minf(1.0, t / 2.2) * 5.0
		Game.fx.burst("water", v(randf_range(-1.5, 1.5), 0.2, 6 + randf_range(-1.5, 1.5)), {"n": 3}), func(): boss.rig.position.y = 0.0)
	await D.wait(2.6)
	pose(boss, "roar")
	await D.say([
		L("calista", "Água, vento e fogo... é uma essência mutável. Cada forma tem um núcleo — mirem no coração!"),
		L("amnon", "Claro. Mirar no coração do monstro de água gigante. Por que eu não pensei nisso."),
	], true)
	D.cine(false)
	Game.in_combat = true
	for a in allies:
		a.scripted = false
	boss.invulnerable = false
	Game.ui.boss(boss)
	Audio.music("boss_elemental", 0.6)
	Game.ui.bark("narr", "Seus companheiros lutam ao seu lado. A criatura também os ataca.", 4.0)
	# Near derrubado
	D.task(func():
		await D.until(func(): return boss.hp < boss.max_hp * 0.86 and near.downed <= 0.0)
		near.knock_down(9.0)
		Game.fx.burst("water", near.chest_pos(), {"n": 20})
		await D.wait(0.4)
		Game.ui.bark("kiana", "NEAR!", 2.0))
	# fases
	D.listen("bossPhase", func(e):
		if e.boss != boss:
			return
		if e.get("form", "") == "wind":
			_calista_wind(cal, boss)
		elif e.get("form", "") == "fire":
			_darin_fire(darin, boss))
	# QTE — Amnon segura o núcleo
	while true:
		await D.until(func(): return boss.min_hp > 0.0 and boss.hp <= boss.min_hp + 1.0 and not boss.invulnerable)
		boss.invulnerable = true
		boss.busy = true
		boss.clear_pending()
		boss.move_vel = Vector3.ZERO
		pose(boss, "roar", {"speed": 0.5})
		amnon.scripted = true
		amnon.downed = 0.0
		amnon.untargetable = false
		put(amnon, boss.global_position + Game.fwd(boss.yaw) * 1.9)
		face(amnon, boss)
		pose(amnon, "grab")
		sfx("fire")
		shake(0.5)
		D.shot({"pos": amnon.global_position + v(1.8, 1.6, 0) - Game.fwd(amnon.yaw) * 1.2, "look": boss.chest_pos(), "dur": 3.0, "fov": 40.0, "cut": true})
		Game.ui.bark("amnon", "AGORA! EU SEGURO ESSA COISA!", 3.0)
		Game.slow(99.0, 0.18)
		var burn: Dictionary = Game.fx.custom(99.0, func(_t, _dt): Game.fx.burst("fire", amnon.rig.bone_world("hand_l"), {"n": 2, "size": 0.8, "r": 0.05}))
		await D.wait(0.25)
		Game.cam.release(0.4)
		Game.ui.bark("calista", "Kiana! O NÚCLEO!", 3.0)
		Game.ui.prompt("[E]  GOLPEIE O NÚCLEO")
		P.lock_target = boss
		var t0 := Game.real_time
		await D.until(func(): return Input.is_action_just_pressed("interact") or Game.real_time - t0 > 4.5)
		Game.ui.prompt("")
		var hit := Game.real_time - t0 <= 4.5
		Game.slow(0.0, 1.0)
		burn.kill = true
		if hit:
			D.cine(true)
			put(P, boss.global_position + Game.fwd(boss.yaw) * 2.2 + v(0.8, 0, 0))
			face(P, boss)
			Game.fx.burst("shadow", P.global_position + v(0, 1, 0), {"n": 20, "r": 0.4})
			D.shot({"pos": boss.global_position + v(4, 2.5, 0) + Game.fwd(boss.yaw) * 3.0, "look": boss.chest_pos(), "dur": 4.0, "fov": 45.0, "cut": true})
			pose(P, "atk3", {"speed": 0.7})
			sfx("blink")
			Game.slow(2.0, 0.3)
			await D.wait(0.35)
			sfx("shatter")
			sfx("explosion")
			shake(1.0)
			flash(0.5)
			Game.post.impact_frames(0.1, Color(1.0, 0.92, 0.75))
			Game.fx.impact(boss.chest_pos(), Color(1, 0.8, 0.4), 5.0)
			Game.fx.shockwave(boss.global_position, Color(1, 0.6, 0.2), 8.0, {"glow": Color(1.0, 0.5, 0.15)})
			Game.fx.sphere(boss.chest_pos(), {"color": Color(1, 0.82, 0.5), "r1": 6.0, "life": 0.8, "intensity": 3.0})
			Game.fx.burst("fire", boss.chest_pos(), {"n": 80, "r": 1.5, "size": 1.6})
			Game.fx.burst("spark", boss.chest_pos(), {"n": 60})
			boss.core.visible = false
			break
		else:
			Game.ui.toast("Amnon foi arremessado!", Color("ff9060"), 2.0)
			amnon.scripted = false
			amnon.knock_down(5.0)
			amnon.knock += Game.fwd(boss.yaw) * 10.0
			boss.hp = minf(boss.max_hp, boss.hp + boss.max_hp * 0.08)
			boss.invulnerable = false
			boss.busy = false
			boss.ai = "chase"
			await D.wait(6)
	# vitória
	Game.ui.boss(null)
	Audio.music("silence", 1.0)
	boss.min_hp = -1.0
	boss.invulnerable = false
	boss.hp = 0.0
	boss.die(P)
	Game.fx.custom(1.6, func(t, _dt):
		Game.fx.burst("smoke", boss.global_position + v(0, randf_range(0.5, 4), 0), {"n": 3, "r": 1.2, "color": Color(0.23, 0.16, 0.16)})
		boss.rig.scale = Vector3.ONE * maxf(0.01, 1.0 - t / 1.5), func(): boss.visible = false)
	await D.wait(2.2)
	for a in allies:
		a.scripted = true
		a.downed = 0.0
		a.untargetable = false
		pose(a, "stop")
	pose(amnon, "kneel")
	var away: Vector3 = amnon.global_position - boss.global_position
	away.y = 0
	away = away.normalized()
	face(amnon, amnon.global_position + away)
	D.shot({"pos": amnon.global_position + away * 2.4 + v(0.6, 1.3, 0), "look": amnon.head_pos(-0.4), "dur": 10.0, "fov": 42.0})
	Audio.music("valley", 2.0)
	await D.say([
		L("amnon", "Ai. Ai, ai, ai. Alguém tem gelo?"),
		L("darin", "Só o Viktor."),
		L("calista", "Então vamos buscá-lo. Hikari fica a dois dias de carroça."),
		L("near", "...Bom trabalho, Amnon."),
		L("amnon", "Anota isso, Darin. O Near me elogiou. Isso vale pelo menos as dez pratas."),
	], true)
	await D.fade(1, 2)

func _calista_wind(cal: Ally, boss: Elemental) -> void:
	Game.ui.bark("calista", "Deixa o vento comigo!", 3.0)
	cal.scripted = true
	cal.flying = true
	cal.fly_height = 3.2
	pose(cal, "float")
	var shots := [0]
	Game.fx.custom(7.0, func(t, _dt):
		Game.fx.burst("wind", cal.global_position - v(0, 1.2, 0), {"n": 1, "r": 0.8, "h": 1.0})
		if is_instance_valid(boss):
			face(cal, boss)
		if t > shots[0] * 0.35 + 0.6 and t < 6.0 and is_instance_valid(boss) and boss.alive:
			shots[0] += 1
			var s := cal.chest_pos()
			var dir := (boss.chest_pos() - s).normalized()
			sfx("arrow", 0.5)
			Game.spawn_projectile({"kind": "arrow", "pos": s, "vel": dir * 32.0, "team": "player", "dmg": 12.0, "radius": 0.5, "life": 1.5, "src": cal, "glow": true,
				"color": Color(1, 0.12, 0.19), "fury_gain": 0.0, "knock": 0.0,
				"trail": func(p, _d): Game.fx.burst("magic", p.pos, {"n": 1, "color": Color(1, 0.12, 0.19), "speed": 0.1, "size": 0.6})}), func():
		cal.flying = false
		cal.fly_height = 0.0
		pose(cal, "stop")
		cal.scripted = false)

func _darin_fire(darin: Ally, boss: Elemental) -> void:
	boss.min_hp = roundf(boss.max_hp * 0.05)
	darin.extra = func(_d):
		if randf() < 0.3:
			Game.fx.burst("magic", darin.rig.bone_world("hand_r"), {"n": 1, "color": Color(0.25, 1.0, 0.63), "speed": 0.5})
			Game.fx.burst("magic", darin.rig.bone_world("hand_l"), {"n": 1, "color": Color(0.25, 1.0, 0.63), "speed": 0.5})
	Game.ui.bark("darin", "*INSTINTO DE CAÇA!*", 3.0)
	sfx("roar", 0.5, 1.6)
	Game.fx.ring(darin.global_position, {"color": Color(0.25, 1.0, 0.63), "r1": 4.0, "life": 0.6})
	var tok := D.token
	await D.wait(3.5)
	if tok == D.token:
		Game.ui.bark("amnon", "Eu odeio fogo. Eu odeio muito fogo.", 3.0)

func c2_road() -> void:
	Game.ui.show_hud(false)
	Audio.music("vardun", 2.0)
	Audio.stop_loops()
	await D.card({"c1": "NA CARROÇA, A CAMINHO DE HIKARI", "c2": "A Lenda de Kynare e o Corvo Celeste", "c3": "Kynare era um homem consumido pela própria fome de poder.\nO Corvo Celeste lhe ofereceu força, domínio e glória eterna\nem troca de uma única coisa: seguir o caminho que o Corvo apontasse.", "dur": 9.0})
	await D.card({"c3": "Kynare aceitou. Aceitou rápido demais.\nCorrentes surgiram sob seus pés — finas como fios de cabelo,\nbrilhantes como estrelas distantes — e ele nem percebeu.", "dur": 8.0})
	await D.card({"c3": "“Nada é mais fácil de controlar\ndo que alguém que acha que está no comando.”", "c4": "— CALISTA VANSHEE", "dur": 6.0})
	await D.card({"c3": "“Viktor carrega algo singular... mas essa mesma dádiva é a fresta na armadura.\nA força dele é, também, a sua maldição.”", "c4": "— CALISTA VANSHEE", "dur": 7.0})
	await D.card({"c1": "HIKARI", "c3": "Uma cidade murada, dominada por um castelo hipnótico.\nUma estátua de balança quebrada chamada Justiça Desequilibrada.\nUm Lorde Draconato adorado pelo povo — Krauser.", "dur": 8.0})
	await D.card({"c3": "Uma anciã chamada Matilde, uma pulseira de ouro velho.\nUm livro chamado “O Inventor do Tempo”.\nUm encapuzado de sorriso impossível, uma caverna de tieflings acorrentados.\nE Krauser, sozinho no centro do símbolo, absorvendo a poeira negra pela pele.", "dur": 9.0})
	Audio.music("title", 1.5)
	await D.card({"c1": "O FESTIVAL DE HONRA", "c2": "O Alvorecer da Ausência", "c3": "O gigante ensinou o sol a caminhar,\nMoldou o ferro antes do fogo se apagar.\nErgueu um farol onde o abismo era lar,\nE jurou que a sombra nunca iria nos alcançar.", "dur": 11.0})
	await D.card({"c3": "A luz que se foi ainda queima no olhar,\nUm vazio dourado que insiste em brilhar.\nSe o forte sucumbe ao peso de lutar,\nEu serei o eco que o silêncio vai quebrar.", "c4": "— KIANA", "dur": 11.0})
	Audio.music("silence", 0.5)
	sfx("gong")
	await D.card({"c3": "A praça permaneceu em silêncio absoluto por três segundos eternos\nantes de explodir em aplausos.\n\nKiana procurou Calista na plateia.\nO lugar dela estava vazio.", "dur": 8.0})
	sfx("roar", 1.0, 0.5)
	await D.card({"c3": "Minutos depois, as sombras atacaram.", "dur": 4.0})

# =====================================================================
#  CAPÍTULO III — OBLITUS LIMBO
# =====================================================================
func _krauser(pos: Vector3, hp: float) -> Krauser:
	var kr := Krauser.new()
	kr.setup_krauser({"pos": pos, "yaw": PI, "hp": roundf(hp * diff())})
	spawn(kr)
	return kr

## Correntes do salão presas às mãos de Viktor (atualizadas a cada quadro).
func _chain_viktor(vik: Actor) -> Dictionary:
	var Lv = Game.level
	var anchors := [v(-3.5, 4.5, 12.7), v(-5.4, 4.5, 12.7)]
	var it: Dictionary = Game.fx.custom(99999.0, func(_t, _dt):
		if not is_instance_valid(vik) or Lv.chains.size() < 2:
			return
		for i in 2:
			var hand: Vector3 = vik.rig.bone_world("hand_l" if i == 0 else "hand_r")
			Lv.set_chain(i, anchors[i], hand))
	return it

func c3_throne() -> void:
	await D.fade(1, 0.01)
	await D.card({"c1": "CAPÍTULO III", "c2": "Oblitus Limbo", "c3": "O Castelo de Hikari", "dur": 5.0})
	await D.load_level("throne", {"player": "kiana", "pos": v(0, 0, -9), "yaw": 0.0, "label": "O SALÃO DO TRONO"})
	var Lv = Game.level
	Audio.music("throne", 2.0)
	Audio.stop_loops()
	Audio.loop("rumble", true, 0.3)
	var P: Player = Game.player
	var kr := _krauser(v(0, 0, 7.5), 1900.0)
	kr.tentacles_on = false
	var vik := npc("viktor", Lv.points.viktor, PI, "Viktor")
	pose(vik, "kneel")
	vik.rig.set_tint(0.45, Color(0.8, 0.75, 1.0))
	var chains := _chain_viktor(vik)
	var veins: Dictionary = Game.fx.custom(99999.0, func(_t, _dt):
		if randf() < 0.4:
			Game.fx.burst("shadow", vik.chest_pos() + v(randf_range(-0.3, 0.3), randf_range(-0.5, 0.5), randf_range(-0.3, 0.3)), {"n": 1, "r": 0.1, "size": 0.5}))
	var cal := npc("calista", Lv.points.calista, 2.5, "Calista")
	pose(cal, "lie", {"instant": true})
	Game.ui.quest("Oblitus Limbo", "")
	D.cine(true)
	D.shot({"pos": v(0, 1.6, -12), "look": v(0, 2.5, 8), "pos2": v(0, 1.8, -7), "dur": 7.0, "blend": 0.0001, "fov": 50.0})
	await D.fade(0, 2)
	await D.wait(3)
	D.shot(closeup(kr, {"dur": 12.0, "dist": 2.4, "side": 0.5, "fov": 38.0}))
	await D.say([
		L("krauser", "Bem-vinda, pequena loba. Você chegou bem a tempo do último ato."),
		L("kiana", "Krauser... foi você. O tempo todo.", func(): D.shot(ots(P, kr, {"dur": 20.0}))),
		L("krauser", "Dez anos usando a máscara de Lorde heroico. O encapuzado da caverna? Um peão. Uma distração encenada para ganhar a confiança de vocês."),
		L("krauser", "Eu sou o verdadeiro *Quinto Presságio*.", func():
			sfx("reveal")
			shake(0.3)),
		L("kiana", "Viktor...!", func(): D.shot({"pos": vik.global_position + v(1.5, 1.6, -2.2), "look": vik.head_pos(-0.2), "dur": 6.0, "fov": 40.0})),
	], true)
	# Calista
	pose(cal, "stop")
	put(cal, vik.global_position + v(1.1, 0, -0.6))
	face(cal, vik)
	pose(cal, "kneel")
	D.shot({"pos": vik.global_position + v(-1.4, 1.3, -2.8), "look": vik.global_position.lerp(cal.global_position, 0.5) + v(0, 1.0, 0), "dur": 20.0, "fov": 40.0})
	Audio.music("flashback", 2.0)
	await D.say([
		L("calista", "Kiana... fica longe dele..."),
		L("calista", "Viktor. Eu... nunca te disse."),
		L("calista", "Eu nunca soube caminhar sem ter você como norte."),
		L("calista", "Agora, Viktor, por favor... *salve todo mundo. Salve a Kiana.*"),
	], true)
	# o beijo — a corrupção migra
	sfx("portal", 0.5)
	Game.fx.custom(3.0, func(t, _dt):
		var a := vik.chest_pos()
		var b := cal.chest_pos()
		for k in 4:
			Game.fx.burst("shadow", a.lerp(b, randf()), {"n": 1, "r": 0.05, "size": 0.6})
		var f: float = minf(1.0, t / 3.0)
		vik.rig.set_tint(0.45 + 0.55 * f, Color(0.8, 0.75, 1.0).lerp(Color.WHITE, f))
		cal.rig.set_tint(1.0 - 0.55 * f, Color.WHITE.lerp(Color(0.8, 0.75, 1.0), f)), func():
		vik.rig.set_tint(1.0)
		veins.kill = true)
	await D.wait(3.3)
	pose(cal, "lie", {"instant": false})
	sfx("heartbeat")
	Game.after(0.9, func(): sfx("heartbeat", 0.5))
	await D.wait(1.5)
	D.shot(closeup(P, {"dur": 4.0, "dist": 1.2, "fov": 34.0}))
	flash(0.2)
	await D.say([L("kiana", "*CALISTA!*", func():
		shake(0.5)
		sfx("fury"))], true)
	Audio.music("silence", 0.5)
	D.shot(ots(P, kr, {"dur": 20.0}))
	await D.say([
		L("krauser", "Dez anos acumulando poder para ser desafiado por uma arqueira moribunda e uma criança."),
		L("krauser", "Você luta com o coração, Kiana, e é por isso que vai perder! Corações pesados são lentos! Corações partidos são fáceis de esmagar!"),
		L("kiana", "O meu coração não está partido, Krauser.", func(): D.shot(closeup(P, {"dur": 8.0, "dist": 1.3}))),
		L("kiana", "Ele arde. *Como um acorde sustentado até doer.*", func():
			Game.flags["apagao"] = true
			sfx("heartbeat", 1.5)),
	], true)
	# o soco
	put(P, kr.global_position + Game.fwd(kr.yaw) * 1.4)
	face(P, kr)
	Game.fx.burst("shadow", P.global_position + v(0, 1, 0), {"n": 30, "r": 0.4})
	D.shot({"pos": kr.global_position + v(3, 1.4, -1.5), "look": kr.chest_pos(), "dur": 3.0, "fov": 40.0, "cut": true})
	pose(P, "punch", {"speed": 0.7})
	sfx("blink")
	await D.wait(0.2)
	sfx("crit")
	shake(0.8)
	flash(0.25)
	Game.post.impact_frames(0.08, Color(1.0, 0.85, 0.88))
	Game.fx.impact(kr.chest_pos(), Color(1, 0.2, 0.3), 3.5)
	pose(kr, "knock")
	kr.knock = Game.fwd(P.yaw) * 14.0
	Game.fx.burst("blood", kr.chest_pos(), {"n": 20})
	Game.fx.burst("spark", kr.chest_pos(), {"n": 25})
	await D.wait(1.3)
	Game.flags["apagao"] = false
	Game.ui.toast("Krauser sangrou. Pela primeira vez.", Color("e8dcc0"), 2.5)
	await D.wait(0.8)
	D.shot(closeup(kr, {"dur": 6.0, "dist": 2.6, "fov": 42.0}))
	pose(kr, "roar")
	sfx("roar", 1.0, 0.8)
	sfx("tentacle")
	kr.tentacles_on = true
	Game.fx.burst("shadow", kr.chest_pos(), {"n": 60, "r": 0.8, "speed": 3.0, "size": 1.4})
	shake(0.6)
	await D.say([L("krauser", "Sua insolente... *TENTÁCULOS DO ABISMO!*")], true)
	D.cine(false)
	Game.in_combat = true
	Game.ui.boss(kr)
	Audio.music("boss_krauser", 0.5)
	Audio.loop("rumble", false)
	D.objective(null, "Derrote Lorde Krauser", null)
	kr.min_hp = roundf(kr.max_hp * 0.6)
	D.listen("summonShadows", func(n):
		for i in int(n):
			var a := randf() * TAU
			var p := v(cos(a) * 8.0, 0, sin(a) * 8.0)
			Game.fx.burst("shadow", p + v(0, 0.6, 0), {"n": 25, "r": 0.6, "speed": 2.0})
			var s := thug({"pos": p, "shadow": true, "hp": 30.0, "dmg": 8.0, "speed": 4.0, "seed": i})
			face(s, P)
		Game.ui.bark("krauser", "Levantem-se, filhos da sombra.", 2.5))
	# ---- limiar 1: o cristal ----
	await D.until(func(): return kr.phase_lock and kr.phase == 1)
	kr.clear_pending()
	kr.busy = true
	kr.invulnerable = true
	kill_enemies_except(kr)
	D.cine(true)
	put(P, kr.global_position + Game.fwd(kr.yaw) * 4.0)
	face(P, kr)
	face(kr, P)
	D.shot(closeup(kr, {"dur": 6.0, "dist": 2.2, "fov": 38.0, "blend": 0.5}))
	pose(kr, "point")
	await D.say([L("krauser", "Chega de brincadeira. Vamos ver o que você esconde dentro dessa cabeça, aberração.")], true)
	sfx("reveal")
	sfx("portal", 0.4)
	var crystal: Node3D = kr.rig.get_meta("crystal") if kr.rig.has_meta("crystal") else null
	var cpos := func() -> Vector3: return crystal.global_position if crystal else kr.chest_pos()
	Game.fx.beam(cpos.call(), P.head_pos(), {"color": Color(1, 0.06, 0.19), "width": 0.08, "life": 2.5})
	Game.fx.custom(2.5, func(_t, _dt): Game.fx.beam(cpos.call(), P.head_pos(), {"color": Color(1, 0.06, 0.19), "width": 0.05, "life": 0.1}))
	pose(P, "hit")
	shake(0.5)
	flash(0.6)
	await D.wait(1.5)
	pose(kr, "stop")
	# ---- FLASHBACK: o orfanato ----
	Game.post.desat_target = 1.0
	Audio.music("flashback", 1.5)
	await D.card({"cls": "memory", "c1": "O ORFANATO", "c3": "Paredes cinzas. Janelas altas.\nUm sino de jantar metálico e impessoal.", "dur": 6.0})
	await D.card({"cls": "memory", "c1": "TIA LANIS", "c3": "“Não aperte tanto as cordas, Kiana.\nTrate o instrumento como um amigo, não como uma arma.”", "dur": 7.0})
	await D.card({"cls": "memory", "c1": "TYLER", "c3": "“Aqui é um lugar para gente normal, Kiana.\nNão é um lugar para monstros ou aberrações como você.”\n\nO ukulele partido contra o rosto. O nariz quebrado.\nE a mentira para proteger quem a machucou.", "dur": 9.0})
	await D.card({"cls": "memory", "c1": "EMMA", "c3": "“Eu gosto de você. E a Tia Lanis também.”", "dur": 5.0})
	sfx("heartbeat", 1.5)
	await D.card({"cls": "memory", "c3": "E então, numa noite de tinta negra e fogo...\num garoto magro, de olhos como globos de escuridão absoluta.", "dur": 7.0})
	await D.card({"cls": "memory", "c1": "GYOTTO, O SEXTO PRESSÁGIO", "c3": "“Todos dormiram... menos você.\nSerá porque você não é humana?”", "dur": 7.0})
	await D.card({"cls": "memory", "c1": "TIA LANIS", "c3": "“Enquanto eles viam uma praga, eu sempre acreditei no contrário:\nque você é a cura de algo muito maior.\nVocê não nasceu para ser odiada,\nmas para ser a resposta que este mundo ainda não sabe que precisa.”", "dur": 10.0})
	await D.card({"cls": "memory", "c3": "Um homem de branco e azul, chegando tarde demais.\nUma estaca de gelo cristalino.\nMãos cheias de cicatrizes erguendo-a do chão.\n\nViktor.", "dur": 9.0})
	Game.post.desat_target = 0.0
	D.shot(closeup(P, {"dur": 10.0, "dist": 1.4, "fov": 36.0, "blend": 0.0001}))
	Audio.music("silence", 0.3)
	await D.say([
		L("kiana", "Eu lembro."),
		L("kiana", "Eu lembro de *TUDO*.", func():
			shake(0.4)
			sfx("reveal")),
		L("krauser", "Impossível... o cristal deveria te quebrar!", func(): D.shot(closeup(kr, {"dur": 5.0}))),
		L("kiana", "Posso não ter despertado meu sigilo ainda, Krauser...", func(): D.shot(closeup(P, {"dur": 8.0, "dist": 1.6}))),
		L("kiana", "...mas tenho habilidades que só eu sei usar."),
	], true)
	# arranca o colar
	put(P, kr.global_position + Game.fwd(kr.yaw) * 1.2)
	face(P, kr)
	pose(P, "claw")
	sfx("blink")
	sfx("shatter")
	if crystal:
		crystal.visible = false
	Game.ui.toast("— AGORA ESTÁ COMIGO! —", Color("ff4060"), 2.0, true)
	flash(1.0)
	await D.wait(0.8)
	# ---- dentro da mente de Krauser ----
	Game.post.desat_target = 0.7
	Audio.music("limbo", 1.0)
	await D.card({"cls": "memory", "c1": "DENTRO DA MENTE DE KRAUSER", "c3": "“Eu não sou pai de um monstro... de um dragão!”\nUma mulher chamada Layla, estrangulada diante do próprio filho.\nUm menino que incinerou o pai vivo.\nCriado no ódio. Batizado no fogo.", "dur": 10.0})
	await D.card({"cls": "memory", "c3": "Um adulto que encontrou numa floresta uma criança rejeitada,\ncom poderes de tinta negra — e a corrompeu,\nreproduzindo sem hesitar o ciclo que o formara.", "dur": 8.0})
	await D.card({"cls": "memory", "c1": "O CONSELHO, SOB A LUA QUE SORRI", "c3": "“O nome dele é Viktor Vanshee!\nO mesmo homem que tirou a vida de Gauss.”", "c4": "— O MASCARADO", "dur": 8.0})
	await D.card({"cls": "memory", "c3": "“Você vai para Hikari, Largato. Mate o Lorde, tome o lugar dele...\ne apodreça lá.”", "c4": "— O MASCARADO", "dur": 7.0})
	Game.post.desat_target = 0.0
	flash(0.8)
	D.shot(closeup(kr, {"dur": 4.0, "dist": 1.8, "blend": 0.0001}))
	await D.say([L("krauser", "*SAI DA MINHA CABEÇA!*", func():
		shake(1.0)
		sfx("roar"))], true)
	# ---- fase 2 ----
	Game.flags["harmonic"] = true
	P.fury = 100.0
	kr.phase = 2
	kr.phase_lock = false
	kr.busy = false
	kr.invulnerable = false
	kr.ai = "chase"
	kr.min_hp = roundf(kr.max_hp * 0.12)
	kr.cd_base = 1.1
	kr.move_speed *= 1.15
	D.cine(false)
	Audio.music("boss_krauser", 0.4)
	Game.ui.toast("MANIFESTAÇÃO HARMÔNICA — SEGURE [F]", Color("ffe08a"), 3.0, true)
	Game.ui.bark("narr", "A Manifestação Harmônica consome toda a sua energia. Cada acorde deixa um veneno estrutural no inimigo.", 6.0)
	await D.until(func(): return kr.phase_lock and kr.phase == 2)
	# ---- Kiana cai ----
	kr.clear_pending()
	kr.busy = true
	kr.invulnerable = true
	kill_enemies_except(kr)
	if P.ult != null:
		P.end_ult()
	D.cine(true)
	put(P, kr.global_position + Game.fwd(kr.yaw) * 2.2)
	face(P, kr)
	face(kr, P)
	D.shot({"pos": kr.global_position + v(2.8, 1.5, 0.5), "look": P.chest_pos().lerp(kr.chest_pos(), 0.5), "dur": 3.0, "fov": 40.0, "cut": true})
	pose(P, "guard")
	await D.say([L("kiana", "Meus reflexos... estão lentos... como se eu estivesse submersa em breu...")], true)
	pose(kr, "claw", {"speed": 0.6})
	await D.wait(0.5)
	Game.slow(1.5, 0.2)
	sfx("crit")
	shake(1.0)
	flash(0.3)
	Game.post.impact_frames(0.12, Color(0.85, 0.75, 1.0))
	Game.fx.impact(P.chest_pos(), Color(0.6, 0.2, 1.0), 3.5)
	Game.fx.burst("blood", P.chest_pos(), {"n": 40})
	pose(P, "death")
	await D.wait(1.2)
	Audio.music("silence", 0.2)
	await D.fade(1, 1.5)
	chains.kill = true
	await D.card({"cls": "memory", "c3": "A dor veio antes do som.\nO chão de mármore estava frio.\nE do outro lado do salão, algo se levantou.", "dur": 7.0})

func c3_viktor() -> void:
	await D.fade(1, 0.01)
	await D.load_level("throne", {"player": "viktor", "pos": v(-3.2, 0, 8.4), "yaw": PI * 0.9, "label": "O PILAR DO GELO"})
	var Lv = Game.level
	Audio.music("silence", 1.0)
	Audio.stop_loops()
	var P: Player = Game.player
	var kr := _krauser(v(0, 0, 0), 1100.0)
	kr.phase = 3
	kr.cd_base = 1.0
	kr.move_speed *= 1.2
	if kr.rig.has_meta("crystal"):
		kr.rig.get_meta("crystal").visible = false
	var kiana := npc("kiana", v(0.5, 0, 2.5), 0.5, "Kiana")
	pose(kiana, "lie", {"instant": true})
	var cal := npc("calista", v(-2.2, 0, 9.8), 2.5, "Calista")
	pose(cal, "lie", {"instant": true})
	face(kr, P)
	for ch in Lv.chains:
		ch.visible = false
	D.cine(true)
	pose(P, "kneel", {"blend": 0.0})
	D.shot({"pos": P.global_position + v(1.2, 0.9, -1.8), "look": P.head_pos(-0.5), "dur": 8.0, "blend": 0.0001, "fov": 38.0})
	await D.fade(0, 2)
	Audio.music("flashback", 2.0)
	await D.say([L("viktor", "...Calista."), L("viktor", "Kiana.")], true)
	pose(P, "stop")
	sfx("shatter")
	sfx("reveal")
	shake(0.8)
	flash(0.6)
	Game.fx.shockwave(P.global_position, Color(0.62, 0.88, 1.0), 12.0, {"glow": Color(0.5, 0.85, 1.0), "life": 1.0})
	Game.post.impact_frames(0.08, Color(0.85, 0.95, 1.0))
	var vik_aura = Game.fx.aura(P, Color(0.45, 0.8, 1.0), Color(0.95, 0.98, 1.0), 2.0)
	Game.after(6.0, func(): Game.fx.aura_end(vik_aura))
	for k in 24:
		var a := k * TAU / 24.0
		var pp := P.global_position + v(cos(a) * randf_range(1.5, 4.0), 0, sin(a) * randf_range(1.5, 4.0))
		Game.after(k * 0.02, func(): Game.fx.ice_spike(pp, {"h": randf_range(1.0, 2.6), "life": 3.0}))
	D.shot({"pos": P.global_position + v(0, 1.0, -3.5), "look": P.head_pos(), "pos2": P.global_position + v(0, 1.4, -2.6), "dur": 6.0, "fov": 40.0})
	Audio.music("boss_krauser", 1.0)
	Audio.set_layer("viktor", true)
	await D.wait(1.2)
	await D.say([
		L("viktor", "Você se acha forte porque esmaga os fracos."),
		L("viktor", "Mas diante de quem realmente conhece o desespero, você não passa de um ruído incômodo."),
		L("krauser", "O picolé acordou! *Armadura Arcana: Frio Absoluto!*", func():
			D.shot(closeup(kr, {"dur": 6.0, "dist": 2.4}))
			kr.set_armor(true)
			sfx("fire")
			Game.fx.burst("fire", kr.global_position, {"n": 60, "color": Color(0.82, 0.9, 1.0), "size": 1.5, "up": 2.0, "r": 0.6})),
		L("krauser", "Você não pode congelar o que já é o próprio zero!"),
	], true)
	D.cine(false)
	Game.in_combat = true
	kr.title = "Frio Absoluto"
	Game.ui.boss(kr)
	D.objective("Oblitus Limbo", "Derrote Krauser — o gelo não basta", null)
	Game.ui.bark("narr", "O Frio Absoluto anula o gelo. Encha a CHAMA e libere o PUNHO FLAMEJANTE [F] para quebrar a armadura.", 7.0)
	P.fury = 40.0
	kr.min_hp = 1.0
	var finale := [false]
	D.listen("punho", func(t):
		if t == kr and kr.hp <= kr.max_hp * 0.32:
			finale[0] = true
		else:
			Game.ui.bark("krauser", "Arg...! Essa chama... de onde?!", 2.5))
	D.task(func():
		await D.until(func(): return kr.hp <= kr.max_hp * 0.32)
		Game.ui.toast("ELE ESTÁ VULNERÁVEL", Color("fff0b0"), 2.5, true)
		Game.ui.bark("viktor", "Acabou, Krauser.", 3.0)
		P.fury = 100.0)
	await D.until(func(): return finale[0])
	# ---- final ----
	kr.clear_pending()
	kr.busy = true
	kr.invulnerable = true
	kill_enemies_except(kr)
	await D.wait(0.6)
	D.cine(true)
	Game.ui.boss(null)
	kr.set_armor(false)
	pose(kr, "kneel")
	kr.tentacles_on = false
	face(P, kr)
	var melt: Dictionary = Game.fx.custom(99999.0, func(_t, _dt):
		if randf() < 0.8:
			Game.fx.burst("shadow", kr.global_position + v(randf_range(-0.4, 0.4), randf_range(0.3, 1.8), randf_range(-0.4, 0.4)), {"n": 1, "r": 0.1, "size": 0.7, "color": Color(0.06, 0.03, 0.06)})
		if randf() < 0.3:
			Game.fx.burst("magic", kr.chest_pos(), {"n": 1, "color": Color(0.5, 0.94, 1.0), "speed": 0.8}))
	D.shot(closeup(kr, {"dur": 10.0, "dist": 1.8, "fov": 38.0, "h": -0.4}))
	Audio.music("silence", 1.0)
	await D.say([
		L("krauser", "O que... o que vocês fizeram comigo...? Eu estou... derretendo... por dentro..."),
		L("krauser", "...A música...", func(): Audio.chord(0)),
		L("viktor", "Eu não fiz nada.", func(): D.shot(closeup(P, {"dur": 8.0, "dist": 1.5}))),
		L("viktor", "*Foi a Kiana quem te derrotou.*"),
		L("krauser", "Hah... hahaha... então... se eu cair...", func(): D.shot(closeup(kr, {"dur": 6.0, "dist": 2.2}))),
		L("krauser", "...VOCÊS CAEM COMIGO!"),
	], true)
	# o ritual
	sfx("portal")
	Audio.loop("rumble", true, 1.0)
	pose(kr, "roar", {"speed": 0.4})
	var portal := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(11, 11)
	portal.mesh = qm
	var pm := ShaderMaterial.new()
	pm.shader = preload("res://shaders/portal.gdshader")
	portal.material_override = pm
	portal.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	Game.world.add_child(portal)
	portal.global_position = v(0, 4.2, 0)
	var plight := OmniLight3D.new()
	plight.light_color = Color(1, 0.1, 0.2)
	plight.omni_range = 18.0
	portal.add_child(plight)
	Game.fx.custom(30.0, func(t, _dt):
		var f: float = minf(1.0, t / 7.0)
		pm.set_shader_parameter("t", t)
		pm.set_shader_parameter("open", 0.05 + f * 0.9)
		plight.light_energy = 1.0 + f * 5.0
		for k in 3:
			var a := randf() * TAU
			var r := randf_range(4, 12)
			Game.fx.burst("shadow", v(cos(a) * r, randf_range(0, 6), sin(a) * r), {"n": 1, "r": 0.1, "size": 0.5})
		if randf() < 0.5:
			Game.fx.burst("ember", v(0, 0, 0), {"n": 1, "r": 6.0, "color": Color(1, 0.12, 0.25)})
		Game.cam.shake(0.05 * f), func(): portal.queue_free())
	D.shot({"pos": v(6, 2, -9), "look": v(0, 3.5, 0), "pos2": v(4, 1.6, -7), "dur": 16.0, "fov": 48.0})
	for c in ["Sanguis pro limine, anima pro vana...", "In tenebris aeternis, mundus dissolvitur.", "Aperi portam limbi, ubi lux moritur..."]:
		await D.say([L("krauser", "*%s*" % c, func(): sfx("heartbeat", 1.5))], true)
	D.shot(closeup(kr, {"dur": 3.0, "dist": 1.4, "fov": 32.0, "blend": 0.0001}))
	await D.say([L("krauser", "*OBLITUS LIMBO!*", func():
		shake(1.0)
		sfx("explosion")
		sfx("roar", 1.0, 0.4)
		Game.post.impact_frames(0.12, Color(0.9, 0.7, 1.0))
		flash(0.6))], true)
	Game.post.speed_target = 0.8
	melt.kill = true
	kr.visible = false
	kr.tentacles_on = false
	D.shot({"pos": v(0, 1.2, -10), "look": v(0, 4, 0), "pos2": v(0, 2.5, -3), "dur": 5.0, "fov": 70.0})
	# todos são sugados
	for a in [P, kiana, cal]:
		a.set_physics_process(false)
		a.collision_layer = 0
	Game.fx.custom(4.0, func(t, dt):
		for a in [P, kiana]:
			if is_instance_valid(a):
				var d: Vector3 = v(0, 4, 0) - a.global_position
				a.global_position += d * dt * (0.3 + t * 0.5)
				a.rig.rotation.z += dt * 3.0)
	await D.wait(2.5)
	flash(1.0)
	await D.fade(1, 1.2)
	Audio.stop_loops()
	Audio.set_layer("viktor", false)

func epilogue() -> void:
	Game.post.speed_target = 0.0
	Game.ui.show_hud(false)
	await D.load_level("limbo", {"label": "O LIMBO"})
	var Lv = Game.level
	Audio.music("limbo", 2.0)
	Audio.loop("rumble", true, 0.8)
	D.cine(true)
	Game.ui.show_hud(false)
	Game.cam.shot({"pos": v(0, 1.5, -8), "look": v(0, 4, 30), "pos2": v(0, 2.5, 8), "look2": v(0, 5, 34), "dur": 25.0, "blend": 0.0001, "fov": 50.0})
	await D.fade(0, 3)
	await D.card({"cls": "clear", "c3": "Kiana. Viktor. Near. Amnon. Darin.\nArrastados para dentro do Limbo —\no mesmo lugar onde esta história começou.", "dur": 7.0})
	Lv.eye.visible = true
	Game.post.impact_frames(0.1, Color(0.95, 0.8, 1.0))
	sfx("reveal")
	await D.say([
		L("presenca", "...", func():
			sfx("heartbeat", 1.5)
			shake(0.4)),
		L("voz", "Krauser foi uma decepção, admito. Mas o encerramento da sua história superou minhas expectativas."),
		L("voz", "Conheço cada hesitação sua, Vanshee."),
		L("voz", "Afinal... quem te entenderia melhor do que *o melhor amigo que você julgou ter deixado para trás?*", func():
			shake(0.6)
			sfx("gong")),
	], true)
	await D.fade(1, 3)
	Audio.stop_loops()
	Audio.music("title", 2.0)
	await D.card({"c2": "OBLITUS LIMBO", "c3": "Continua em\nOBLITUS LIMBO: Volume II", "c4": "OBRIGADO POR JOGAR A DEMO", "dur": 9.0})
