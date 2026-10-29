extends Node

var dungeon_track: AudioStreamMP3 = preload("res://assets/audio/music/mtcoronet_midterm.mp3")
var boss_track: AudioStreamMP3 = preload("res://assets/audio/music/pmd_bosstheme_midterm.mp3")

var player: AudioStreamPlayer
var playback_owner: WeakRef

func _ready() -> void:
	# Runtime loop settings leave the source MP3s and import settings unchanged.
	dungeon_track.loop = true
	dungeon_track.loop_offset = 0.0
	boss_track.loop = true
	boss_track.loop_offset = 0.0
	player = AudioStreamPlayer.new()
	player.name = "MusicPlayer"
	player.bus = &"Master"
	add_child(player)

func claim(requester: Node) -> void:
	if not owns_playback(requester):
		player.stop()
		playback_owner = weakref(requester)

func owns_playback(requester: Node) -> bool:
	return playback_owner != null and playback_owner.get_ref() == requester

func play_dungeon(requester: Node, restart: bool = false) -> void:
	_play(requester, dungeon_track, restart)

func play_boss(requester: Node) -> void:
	_play(requester, boss_track, false)

func _play(requester: Node, stream: AudioStreamMP3, restart: bool) -> void:
	if not owns_playback(requester):
		return
	if not restart and player.stream == stream and player.playing:
		return
	player.stop()
	player.stream = stream
	player.play(0.0)

func stop_music(requester: Node) -> void:
	if owns_playback(requester):
		player.stop()
		player.stream = null

func release(requester: Node) -> void:
	if owns_playback(requester):
		stop_music(requester)
		playback_owner = null

func _exit_tree() -> void:
	player.stop()
	player.stream = null
