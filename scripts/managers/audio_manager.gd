extends Node
class_name AudioManager

## AudioManager - Centralized sound management for the inventory system
## 
## Usage:
## 1. Add this script as an Autoload in Project Settings (Name: "AudioManager")
## 2. Call AudioManager.play_sound("pickup") from anywhere
##
## Note: Since we don't have audio assets yet, this uses debug prints.
## To enable real audio:
## 1. Add AudioStreamPlayer child nodes
## 2. Preload .wav files into the 'sounds' dictionary

# Singleton pattern (optional if used as Autoload)
static var instance: AudioManager

# Sound Library
var sounds: Dictionary = {
	"pickup": null, # preload("res://assets/audio/ui_pickup.wav"),
	"drop": null, # preload("res://assets/audio/ui_drop.wav"),
	"swap": null, # preload("res://assets/audio/ui_swap.wav"),
	"error": null, # preload("res://assets/audio/ui_error.wav"),
	"click": null, # preload("res://assets/audio/ui_click.wav"),
	"hover": null # preload("res://assets/audio/ui_hover.wav")
}

# Audio Players (Pool)
var players: Array[AudioStreamPlayer] = []
const POOL_SIZE = 5

func _ready():
	instance = self
	_init_audio_pool()
	print("[AudioManager] Initialized")

func _init_audio_pool():
	"""Create a pool of AudioStreamPlayers to allow overlapping sounds"""
	for i in range(POOL_SIZE):
		var player = AudioStreamPlayer.new()
		player.bus = "UI" # Assumes a UI audio bus exists
		add_child(player)
		players.append(player)

func play_sound(sound_name: String, pitch_randomization: float = 0.0):
	"""Play a sound by name with optional pitch randomization"""
	
	# 1. Debug Feedback (since we have no assets)
	print("[AudioManager] 🔊 Playing Sound: '%s' (Pitch: %.2f)" % [sound_name, 1.0 + randf_range(-pitch_randomization, pitch_randomization)])
	
	# 2. Actual Implementation (Uncomment when assets are ready)
	# if not sounds.has(sound_name) or sounds[sound_name] == null:
	# 	return
	# 	
	# var stream = sounds[sound_name]
	# var player = _get_available_player()
	# 
	# if player:
	# 	player.stream = stream
	# 	player.pitch_scale = 1.0 + randf_range(-pitch_randomization, pitch_randomization)
	# 	player.play()

func _get_available_player() -> AudioStreamPlayer:
	"""Find a free player in the pool"""
	for player in players:
		if not player.playing:
			return player
	
	# If all busy, steal the oldest one (or just the first one)
	return players[0]

# Static Helper (if not using Autoload)
static func play(sound_name: String, pitch_var: float = 0.0):
	if instance:
		instance.play_sound(sound_name, pitch_var)
	else:
		# Fallback if instance not found (e.g. not in scene tree)
		print("[AudioManager] (Static) 🔊 Playing Sound: '%s'" % sound_name)
