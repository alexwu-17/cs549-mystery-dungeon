extends Node

var dungeon_track: AudioStreamOggVorbis = preload("res://assets/audio/music/temporal_tower_dungeon.ogg")
var boss_track: AudioStreamOggVorbis = preload("res://assets/audio/music/Boss_Battle_Orchestral.ogg")

var player: AudioStreamPlayer
var playback_owner: WeakRef

func _ready() -> void:
	# Match the authored Ogg import; begin fresh playback at zero, then loop here.
	dungeon_track.loop = true
	dungeon_track.loop_offset = 17.450
	boss_track.loop = true
	boss_track.loop_offset = 22.540
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

func _play(requester: Node, stream: AudioStream, restart: bool) -> void:
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
