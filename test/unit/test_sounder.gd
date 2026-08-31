extends "res://addons/gut/test.gd"


func after_each():
	Sounder.set_enabled(true)
	Sounder.stop()


func test_is_enabled_default_and_toggle():
	Sounder.set_enabled(true)
	assert_true(Sounder.is_enabled())
	Sounder.set_enabled(false)
	assert_false(Sounder.is_enabled())


func test_play_starts_a_real_sound_when_enabled():
	Sounder.set_enabled(true)
	Sounder.play('billy-pegu.mp3')
	assert_true(Sounder.player.playing)


func test_play_does_nothing_when_disabled():
	Sounder.set_enabled(false)
	Sounder.play('billy-pegu.mp3')
	assert_false(Sounder.player.playing)


func test_play_caches_the_loaded_stream():
	Sounder.set_enabled(true)
	Sounder.cache = {}  # etat propre pour ce test
	Sounder.play('billy-pegu.mp3')
	assert_true(Sounder.cache.has('billy-pegu.mp3'))
	var cached_stream = Sounder.cache['billy-pegu.mp3']
	Sounder.play('billy-pegu.mp3')  # deuxieme appel: doit reutiliser le cache
	assert_eq(Sounder.cache['billy-pegu.mp3'], cached_stream)


func test_set_enabled_false_stops_current_playback():
	Sounder.set_enabled(true)
	Sounder.play('billy-pegu.mp3')
	assert_true(Sounder.player.playing)
	Sounder.set_enabled(false)
	assert_false(Sounder.player.playing)
