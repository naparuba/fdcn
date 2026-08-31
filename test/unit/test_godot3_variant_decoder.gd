extends "res://addons/gut/test.gd"

# Verrouille le decodeur manuel du format binaire Variant de Godot 3.6.2
# (godot3_variant_decoder.gd), necessaire car FileAccess.get_var() de
# Godot 4 ne peut PAS lire ce format (les identifiants numeriques de
# Variant::Type ont ete decales entre les deux versions -- cf
# test/fixtures/save_formats_godot3/README.md pour le detail du bug
# trouve en testant une vraie sauvegarde Godot 3.6.2 sous Godot 4).
#
# Chaque fixture dans test/fixtures/save_formats_godot3/probes/ a ete
# generee avec le VRAI binaire Godot 3.6.2 (File.store_var), sur une
# valeur UNIQUE et connue -- jamais regeneree avec du code Godot 4. Le
# format lui-meme (type-tags, padding des strings...) a ete reverse-
# engineered en hexdumpant ces memes fixtures, PAS devine depuis la
# memoire du format Godot 3.

var Decoder = preload('res://godot3_variant_decoder.gd')

const PROBE_DIR = "res://test/fixtures/save_formats_godot3/probes/"


func _load_fixture(fname):
	var f = FileAccess.open(PROBE_DIR + fname, FileAccess.READ)
	assert_not_null(f, "fixture manquante: %s" % fname)
	var bytes = f.get_buffer(f.get_length())
	f.close()
	return Decoder.decode(bytes)


# =========================================================================
# Scalaires
# =========================================================================

func test_int_zero():
	assert_eq(_load_fixture("int_0.bin"), 0)


func test_int_positive():
	assert_eq(_load_fixture("int_112.bin"), 112)


func test_int_negative():
	assert_eq(_load_fixture("int_neg5.bin"), -5)


func test_int_large_needs_64bit_flag():
	# > 2^31 -- force le flag "wide" (0x10000) et un payload int64 sur 8
	# octets plutot que int32 sur 4 -- si le decodeur ignorait le flag, il
	# lirait un mauvais nombre d'octets et desynchroniserait tout ce qui
	# suit dans le fichier.
	assert_eq(_load_fixture("int_large.bin"), 3000000000)


func test_bool_true():
	assert_eq(_load_fixture("bool_true.bin"), true)


func test_bool_false():
	assert_eq(_load_fixture("bool_false.bin"), false)


func test_float():
	assert_almost_eq(_load_fixture("float_314.bin"), 3.14, 0.0001)


# =========================================================================
# Strings -- attention particuliere au padding (les octets de la chaine
# sont alignes au multiple de 4 superieur, cf commentaire du decodeur)
# =========================================================================

func test_string_simple():
	assert_eq(_load_fixture("string_epee.bin"), "EPEE")


func test_string_empty():
	assert_eq(_load_fixture("string_empty.bin"), "")


func test_string_with_multibyte_utf8_and_padding():
	# "Épée d'Ytia" : 11 caracteres mais 13 octets UTF8 (É et é sur 2
	# octets chacun) -- 13 n'est pas un multiple de 4, le padding (3
	# octets) DOIT etre calcule sur le compte d'OCTETS, pas de caracteres,
	# sous peine de desynchroniser la lecture du champ suivant.
	assert_eq(_load_fixture("string_accents.bin"), "Épée d'Ytia")


# =========================================================================
# Arrays
# =========================================================================

func test_array_empty():
	assert_eq(_load_fixture("array_empty.bin"), [])


func test_array_one_int():
	assert_eq(_load_fixture("array_one_int.bin"), [1])


func test_array_three_ints():
	# le VRAI contenu attendu de all_times_already_visited-1.save
	assert_eq(_load_fixture("array_three_ints.bin"), [1, 128, 112])


func test_array_one_string():
	assert_eq(_load_fixture("array_one_string.bin"), ["EPEE"])


func test_array_two_strings_with_padding_between_elements():
	# "LANCE" (5 octets, paddes a 8) suivi directement du type-tag de
	# l'element suivant -- si le padding est mal calcule, ce test le
	# detecterait (dessynchronisation => erreur de decodage ou valeurs
	# aberrantes, jamais juste par coincidence puisque les deux chaines
	# ont des longueurs differentes).
	assert_eq(_load_fixture("array_two_strings.bin"), ["EPEE", "LANCE"])


func test_array_nested():
	assert_eq(_load_fixture("array_nested.bin"), [[1, 2], [3]])


func test_array_with_null_element():
	assert_eq(_load_fixture("array_null.bin"), [null])


# =========================================================================
# Dictionary
# =========================================================================

func test_dict_empty():
	assert_eq(_load_fixture("dict_empty.bin"), {})


func test_dict_simple_matches_parameters_shape():
	# forme exacte de Parameters.gd::parameters (le VRAI contenu de
	# parameters.save) -- cles String, valeurs melangeant bool et int.
	var result = _load_fixture("dict_simple.bin")
	assert_eq(result, {"billy": "guerrier", "spoils": true, "sound": true, "current_book": 1})


# =========================================================================
# Fixture REELLE (scenario complet, cf test/fixtures/save_formats_godot3/
# README.md) -- verifie le decodeur sur les VRAIS fichiers produits par
# player.gd/Parameters.gd, pas seulement des cas isoles synthetiques.
# =========================================================================

func test_vraie_fixture_current_node_id():
	var f = FileAccess.open("res://test/fixtures/save_formats_godot3/current_node_id-1.save", FileAccess.READ)
	var bytes = f.get_buffer(f.get_length())
	f.close()
	assert_eq(Decoder.decode(bytes), 112)


func test_vraie_fixture_all_times_already_visited():
	var f = FileAccess.open("res://test/fixtures/save_formats_godot3/all_times_already_visited-1.save", FileAccess.READ)
	var bytes = f.get_buffer(f.get_length())
	f.close()
	assert_eq(Decoder.decode(bytes), [1, 128, 112])


func test_vraie_fixture_session_visited_nodes():
	var f = FileAccess.open("res://test/fixtures/save_formats_godot3/session_visited_nodes-1.save", FileAccess.READ)
	var bytes = f.get_buffer(f.get_length())
	f.close()
	assert_eq(Decoder.decode(bytes), [1, 128, 112])


func test_vraie_fixture_possessed_items():
	var f = FileAccess.open("res://test/fixtures/save_formats_godot3/possessed_item-1.save", FileAccess.READ)
	var bytes = f.get_buffer(f.get_length())
	f.close()
	assert_eq(Decoder.decode(bytes), ["PALAIS DES PLAISIRS D'YTIA", "EPEE"])


func test_vraie_fixture_parameters():
	var f = FileAccess.open("res://test/fixtures/save_formats_godot3/parameters.save", FileAccess.READ)
	var bytes = f.get_buffer(f.get_length())
	f.close()
	var result = Decoder.decode(bytes)
	# "pegu" (pas "guerrier") : vrai contenu du fichier, choix de personnage
	# par defaut applique par le jeu lors de la generation de la fixture.
	assert_eq(result, {"billy": "pegu", "spoils": true, "sound": true, "current_book": 1})


# =========================================================================
# encode() -- usage unique : simuler un vrai vieux fichier dans les tests
# de migration (cf test_migration.gd). Verifie ICI par comparaison OCTET
# PAR OCTET avec une vraie fixture ecrite par le vrai binaire Godot 3.6.2
# -- pas juste un aller-retour encode(decode(x))==x, qui masquerait deux
# bugs symetriques qui s'annulent (cf le meme piege qui a fait paraitre
# FileAccess.get_var() fonctionnel avant cette revue).
# =========================================================================

func test_encode_matches_real_godot3_bytes_for_array_of_ints():
	var f = FileAccess.open(PROBE_DIR + "array_three_ints.bin", FileAccess.READ)
	var real_bytes = f.get_buffer(f.get_length())
	f.close()
	assert_eq(Decoder.encode([1, 128, 112]), real_bytes)


func test_encode_matches_real_godot3_bytes_for_string():
	var f = FileAccess.open(PROBE_DIR + "string_epee.bin", FileAccess.READ)
	var real_bytes = f.get_buffer(f.get_length())
	f.close()
	assert_eq(Decoder.encode("EPEE"), real_bytes)


func test_encode_matches_real_godot3_bytes_for_string_needing_padding():
	var f = FileAccess.open(PROBE_DIR + "array_two_strings.bin", FileAccess.READ)
	var real_bytes = f.get_buffer(f.get_length())
	f.close()
	assert_eq(Decoder.encode(["EPEE", "LANCE"]), real_bytes)


func test_encode_matches_real_godot3_bytes_for_int():
	var f = FileAccess.open(PROBE_DIR + "int_112.bin", FileAccess.READ)
	var real_bytes = f.get_buffer(f.get_length())
	f.close()
	assert_eq(Decoder.encode(112), real_bytes)


func test_encode_decode_roundtrip_on_dict():
	var original = {"billy": "pegu", "spoils": true, "sound": false, "current_book": 2}
	assert_eq(Decoder.decode(Decoder.encode(original)), original)
