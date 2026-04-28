extends Node
## 全域音效管理器 (autoload)

const _SFX_PATH  := "res://audio/sfx/"
const _MUSIC_PATH := "res://audio/music/"
const _SFX_NAMES := [
	"shoot", "hit_brick", "hit_steel",
	"explosion_enemy", "explosion_player",
	"stage_clear", "game_over", "boss_warning", "powerup"
]

var _sfx: Dictionary = {}
var _bgm: AudioStreamPlayer

func _ready() -> void:
	for sfx_name in _SFX_NAMES:
		var p := AudioStreamPlayer.new()
		p.name = sfx_name
		add_child(p)
		var path := _SFX_PATH + sfx_name + ".wav"
		if ResourceLoader.exists(path):
			p.stream = load(path)
		_sfx[sfx_name] = p

	_bgm = AudioStreamPlayer.new()
	_bgm.name = "BGM"
	add_child(_bgm)
	var bgm_path := _MUSIC_PATH + "bgm.wav"
	if ResourceLoader.exists(bgm_path):
		_bgm.stream = load(bgm_path)
	_bgm.finished.connect(_bgm.play)

func play(sfx_name: String) -> void:
	if sfx_name in _sfx:
		var p: AudioStreamPlayer = _sfx[sfx_name]
		if p.stream:
			p.play()

func play_bgm() -> void:
	if _bgm.stream and not _bgm.playing:
		_bgm.play()

func stop_bgm() -> void:
	_bgm.stop()
