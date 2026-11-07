class_name Kits
## Registro dos personagens jogáveis (Versus, história em modo de teste, CPU e HUD).

const IDS := ["kiana", "viktor", "near", "darin", "amnon", "calista", "krauser", "yuto"]

static var _info := {}

static func make(id: String, p) -> FighterKit:
	var path := "res://scripts/combat/kits/kit_%s.gd" % id
	if not ResourceLoader.exists(path):
		path = "res://scripts/combat/kits/kit_kiana.gd"
	var k: FighterKit = load(path).new(p)
	k.id = id
	return k

## Atributos sem precisar de um Player (menus, HUD).
static func info(id: String) -> Dictionary:
	if not _info.has(id):
		var k := make(id, null)
		var st := k.stats()
		st["ult"] = k.ult_info()
		st["awaken"] = k.awaken_name()
		_info[id] = st
	return _info[id]

## Ficha do CharFactory usada pelo personagem.
static func model(id: String) -> String:
	return id
