extends RefCounted

# Codec manuel (decode + encode) du format binaire Variant de Godot 3.6.2
# (File.store_var), pour lire les VIEUX fichiers .save d'avant le miroir
# JSON (commit af5c081, 2026-05-03) -- FileAccess.get_var() de Godot 4 ne
# peut PAS lire ce format correctement : les identifiants numeriques de
# Variant::Type ont ete decales entre les deux versions (Godot 4 a insere
# de nouveaux types dans l'enum). En pratique, ARRAY (19 en Godot 3.6.2)
# est relu comme PROJECTION (19 en Godot 4, matrice de 16 floats) et
# DICTIONARY (18) comme TRANSFORM3D (18, 12 floats) -- d'ou les erreurs
# "ERR_INVALID_DATA... size check for 16 floats" ou, pire, un decodage
# SILENCIEUX en valeurs absurdes sans la moindre erreur (cf
# test/fixtures/save_formats_godot3/README.md pour le detail du bug
# trouve en testant une vraie sauvegarde Godot 3.6.2 sous Godot 4).
#
# encode() existe pour UNE seule raison : test_migration.gd simule des
# "vieux fichiers" en ecrivant des donnees synthetiques -- avant cette
# classe, il le faisait avec FileAccess.store_var() de Godot 4 lui-meme,
# ce qui marchait par coincidence tant que la LECTURE utilisait aussi
# l'API native (les deux etaient "faux" de la meme facon). Une fois la
# lecture corrigee pour lire du VRAI Godot 3, ces fixtures synthetiques
# doivent aussi etre au VRAI format Godot 3 pour rester representatives --
# d'ou cet encodeur, verifie par un test qui compare ses octets, byte a
# byte, a une vraie fixture produite par le vrai binaire Godot 3.6.2.
#
# Format EMPIRIQUE (verifie par hexdump sur de vraies fixtures generees
# avec le vrai binaire Godot 3.6.2, cf test/fixtures/save_formats_godot3/
# et test/unit/test_godot3_variant_decoder.gd -- ne PAS deviner depuis la
# memoire du format Godot 3, chaque type ci-dessous a ete confirme
# octet par octet) :
#
#   fichier = [4o LE uint32 : longueur totale du variant qui suit] [variant]
#   variant = [4o LE uint32 : type-tag] [payload selon le type]
#   type-tag : bits bas = identifiant Variant::Type (numerotation Godot
#              3.6.2, PAS Godot 4) ; bit 16 (0x10000) = flag "large"
#              (int64/double au lieu de int32/float32 -- toujours present
#              pour REAL car GDScript n'a que des float 64 bits ; present
#              pour INT seulement si la valeur depasse le range int32).
#
#   Types rencontres dans les sauvegardes du jeu (aucun autre type --
#   Vector2/Rect2/Object/etc -- n'est jamais ecrit par player.gd/
#   Parameters.gd) :
#     0  NIL        -- aucun payload
#     1  BOOL       -- 4o int (0 ou 1)
#     2  INT        -- 4o int32, ou 8o int64 si le flag 0x10000 est pose
#     3  REAL       -- 4o float32, ou 8o double si le flag est pose
#     4  STRING     -- 4o longueur N (en OCTETS utf8, pas en caracteres)
#                       + N octets utf8 + padding jusqu'au multiple de 4
#                       superieur ou egal (aligne le champ suivant)
#     18 DICTIONARY -- 4o nombre d'entrees, puis (cle, valeur) x N, cle
#                       et valeur chacune un variant complet recursif
#     19 ARRAY      -- 4o nombre d'elements, puis N variants complets

# Prefixe GODOT3_ deliberement : les noms courts (TYPE_ARRAY, TYPE_DICTIONARY,
# ...) COLLISIONNENT avec les constantes globales de Godot 4 (TYPE_ARRAY=28,
# TYPE_DICTIONARY=27...) utilisees par typeof() dans _encode_variant() plus
# bas -- un `const TYPE_ARRAY = 19` local les MASQUERAIT silencieusement,
# faisant echouer le "match typeof(value): TYPE_ARRAY:" sans la moindre
# erreur de compilation (trouve en ecrivant les tests : exactement le genre
# de confusion entre numerotations Godot 3 vs Godot 4 que ce fichier existe
# pour résoudre).
const GODOT3_TYPE_NIL = 0
const GODOT3_TYPE_BOOL = 1
const GODOT3_TYPE_INT = 2
const GODOT3_TYPE_REAL = 3
const GODOT3_TYPE_STRING = 4
const GODOT3_TYPE_DICTIONARY = 18
const GODOT3_TYPE_ARRAY = 19
const FLAG_WIDE = 0x10000
const TYPE_MASK = 0xFFFF


# Decode le contenu BRUT d'un fichier .save Godot 3.6.2 (avec son prefixe
# de longueur de 4 octets) et renvoie la valeur GDScript correspondante.
static func decode(bytes: PackedByteArray):
	# cursor = boite mutable a 1 case (les int GDScript sont par valeur) --
	# meme idiome que les "boites" utilisees ailleurs dans ce repo
	# (combat_modificateurs.gd) pour un etat partage entre appels.
	var cursor = [4]  # on saute le prefixe de longueur globale
	return _decode_variant(bytes, cursor)


static func _decode_variant(bytes: PackedByteArray, cursor: Array):
	var type_tag = _read_u32(bytes, cursor)
	var type_id = type_tag & TYPE_MASK
	var is_wide = (type_tag & FLAG_WIDE) != 0
	match type_id:
		GODOT3_TYPE_NIL:
			return null
		GODOT3_TYPE_BOOL:
			return _read_u32(bytes, cursor) != 0
		GODOT3_TYPE_INT:
			return _read_i64(bytes, cursor) if is_wide else _read_i32(bytes, cursor)
		GODOT3_TYPE_REAL:
			return _read_f64(bytes, cursor) if is_wide else _read_f32(bytes, cursor)
		GODOT3_TYPE_STRING:
			return _read_string(bytes, cursor)
		GODOT3_TYPE_DICTIONARY:
			var count = _read_u32(bytes, cursor)
			var result = {}
			for i in range(count):
				var key = _decode_variant(bytes, cursor)
				var value = _decode_variant(bytes, cursor)
				result[key] = value
			return result
		GODOT3_TYPE_ARRAY:
			var count = _read_u32(bytes, cursor)
			var result = []
			for i in range(count):
				result.append(_decode_variant(bytes, cursor))
			return result
		_:
			push_error("Godot3VariantDecoder: type Variant Godot 3 non supporte (id=%s) -- fichier de sauvegarde avec un contenu inattendu, jamais ecrit par ce jeu" % type_id)
			return null


static func _read_u32(bytes: PackedByteArray, cursor: Array) -> int:
	var i = cursor[0]
	cursor[0] += 4
	return bytes.decode_u32(i)


static func _read_i32(bytes: PackedByteArray, cursor: Array) -> int:
	var i = cursor[0]
	cursor[0] += 4
	return bytes.decode_s32(i)


static func _read_i64(bytes: PackedByteArray, cursor: Array) -> int:
	var i = cursor[0]
	cursor[0] += 8
	return bytes.decode_s64(i)


static func _read_f32(bytes: PackedByteArray, cursor: Array) -> float:
	var i = cursor[0]
	cursor[0] += 4
	return bytes.decode_float(i)


static func _read_f64(bytes: PackedByteArray, cursor: Array) -> float:
	var i = cursor[0]
	cursor[0] += 8
	return bytes.decode_double(i)


static func _read_string(bytes: PackedByteArray, cursor: Array) -> String:
	var byte_len = _read_u32(bytes, cursor)
	var i = cursor[0]
	var raw = bytes.slice(i, i + byte_len)
	var padded_len = byte_len + ((4 - byte_len % 4) % 4)
	cursor[0] += padded_len
	return raw.get_string_from_utf8()


# Encode une valeur au format Godot 3.6.2 (miroir exact de decode() ci-
# dessus) -- usage UNIQUE : simuler un vrai vieux fichier .save dans les
# tests (cf test_migration.gd), jamais utilise par le jeu en fonctionnement
# normal (on ne re-ecrit qu'en JSON depuis la migration du 2026-07-09).
static func encode(value) -> PackedByteArray:
	var payload = PackedByteArray()
	_encode_variant(value, payload)
	var out = PackedByteArray()
	out.append_array(_u32_bytes(payload.size()))
	out.append_array(payload)
	return out


static func _encode_variant(value, buf: PackedByteArray):
	# Les labels de ce "match" (TYPE_NIL, TYPE_ARRAY, ...) sont les
	# constantes GLOBALES de Godot 4 (typeof() les renvoie) -- ne pas les
	# confondre avec les GODOT3_TYPE_* ecrites dans le buffer ci-dessous,
	# qui elles sont la numerotation Godot 3 attendue sur le DISQUE.
	match typeof(value):
		TYPE_NIL:
			buf.append_array(_u32_bytes(GODOT3_TYPE_NIL))
		TYPE_BOOL:
			buf.append_array(_u32_bytes(GODOT3_TYPE_BOOL))
			buf.append_array(_u32_bytes(1 if value else 0))
		TYPE_INT:
			if value > 2147483647 or value < -2147483648:
				buf.append_array(_u32_bytes(GODOT3_TYPE_INT | FLAG_WIDE))
				buf.append_array(_i64_bytes(value))
			else:
				buf.append_array(_u32_bytes(GODOT3_TYPE_INT))
				buf.append_array(_i32_bytes(value))
		TYPE_FLOAT:
			# GDScript n'a qu'un type flottant 64 bits -- toujours le flag
			# "large" (cf commentaire d'en-tete, meme comportement observe
			# empiriquement sur les vraies fixtures Godot 3.6.2).
			buf.append_array(_u32_bytes(GODOT3_TYPE_REAL | FLAG_WIDE))
			buf.append_array(_f64_bytes(value))
		TYPE_STRING:
			buf.append_array(_u32_bytes(GODOT3_TYPE_STRING))
			var str_bytes = (value as String).to_utf8_buffer()
			buf.append_array(_u32_bytes(str_bytes.size()))
			buf.append_array(str_bytes)
			var pad = (4 - str_bytes.size() % 4) % 4
			for i in range(pad):
				buf.append(0)
		TYPE_ARRAY:
			buf.append_array(_u32_bytes(GODOT3_TYPE_ARRAY))
			buf.append_array(_u32_bytes(value.size()))
			for item in value:
				_encode_variant(item, buf)
		TYPE_DICTIONARY:
			buf.append_array(_u32_bytes(GODOT3_TYPE_DICTIONARY))
			buf.append_array(_u32_bytes(value.size()))
			for k in value.keys():
				_encode_variant(k, buf)
				_encode_variant(value[k], buf)
		_:
			push_error("Godot3VariantDecoder.encode: type GDScript non supporte (typeof=%s)" % typeof(value))


static func _u32_bytes(v: int) -> PackedByteArray:
	var b = PackedByteArray()
	b.resize(4)
	b.encode_u32(0, v)
	return b


static func _i32_bytes(v: int) -> PackedByteArray:
	var b = PackedByteArray()
	b.resize(4)
	b.encode_s32(0, v)
	return b


static func _i64_bytes(v: int) -> PackedByteArray:
	var b = PackedByteArray()
	b.resize(8)
	b.encode_s64(0, v)
	return b


static func _f64_bytes(v: float) -> PackedByteArray:
	var b = PackedByteArray()
	b.resize(8)
	b.encode_double(0, v)
	return b
