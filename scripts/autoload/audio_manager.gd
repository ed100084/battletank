extends Node
## 全域音效管理器 (autoload)

const _SFX_PATH: String  = "res://audio/sfx/"
const _MUSIC_PATH: String = "res://audio/music/"
const _SFX_NAMES: Array[String] = [
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
		var path: String = _SFX_PATH + sfx_name + ".wav"
		if ResourceLoader.exists(path):
			p.stream = load(path)
		_sfx[sfx_name] = p

	_bgm = AudioStreamPlayer.new()
	_bgm.name = "BGM"
	add_child(_bgm)
	var bgm_path: String = _MUSIC_PATH + "bgm.wav"
	if ResourceLoader.exists(bgm_path):
		_bgm.stream = load(bgm_path)
	# 用 stream 的 loop 屬性循環，避免 finished → play() 競態
	if _bgm.stream and _bgm.stream is AudioStreamWAV:
		(_bgm.stream as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD

func play(sfx_name: String) -> void:
	if sfx_name in _sfx:
		var p: AudioStreamPlayer = _sfx[sfx_name]
		if p.stream:
			p.play()

## 多人模式下：authority 呼叫 → 所有 peer 同時播放
## 單人 / authority 端會在本機播放
@rpc("authority", "call_local", "unreliable")
func rpc_play(sfx_name: String) -> void:
	play(sfx_name)

func play_synced(sfx_name: String) -> void:
	if NetworkManager.is_offline():
		play(sfx_name)
	elif NetworkManager.is_authoritative():
		rpc_play.rpc(sfx_name)
	# client 不主動發音效

func play_bgm() -> void:
	if _bgm.stream and not _bgm.playing:
		_bgm.play()

func stop_bgm() -> void:
	_bgm.stop()
