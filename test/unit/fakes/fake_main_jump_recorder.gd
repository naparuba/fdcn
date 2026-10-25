extends Node

# Double minimal pour verifier que bread.gd / d'autres widgets appellent
# bien main.jump_back(chapter_id) sans avoir a instancier tout main.tscn.

var jump_back_calls = []

func jump_back(chapter_id):
	self.jump_back_calls.append(chapter_id)
