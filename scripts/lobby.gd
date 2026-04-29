extends Control
## Lobby / 主選單
## 模式：單人 / 開房 / 加入房 / 選關
## 使用 LevelManager + NetworkManager autoload

@onready var status_label: Label = $Panel/Status
@onready var single_btn: Button = $Panel/Buttons/Single
@onready var host_btn: Button = $Panel/Buttons/Host
@onready var join_btn: Button = $Panel/Buttons/Join
@onready var ip_input: LineEdit = $Panel/JoinRow/IpInput
@onready var join_confirm_btn: Button = $Panel/JoinRow/JoinConfirm
@onready var join_row: HBoxContainer = $Panel/JoinRow
@onready var stage_list: ItemList = $Panel/Stages
@onready var play_btn: Button = $Panel/Play
@onready var reset_btn: Button = $Panel/ResetProgress
@onready var reset_dialog: ConfirmationDialog = $ResetConfirm

const MAIN_SCENE := "res://scenes/Main.tscn"

var selected_stage: int = 0

func _ready() -> void:
	join_row.visible = false
	single_btn.pressed.connect(_on_single)
	host_btn.pressed.connect(_on_host)
	join_btn.pressed.connect(_on_join_toggle)
	join_confirm_btn.pressed.connect(_on_join_confirm)
	play_btn.pressed.connect(_on_play)
	reset_btn.pressed.connect(_on_reset_pressed)
	reset_dialog.confirmed.connect(_on_reset_confirmed)

	NetworkManager.session_started.connect(_on_session_started)
	NetworkManager.connection_failed.connect(_on_connection_failed)
	NetworkManager.peer_joined.connect(_on_peer_joined)

	_refresh_stage_list()
	_set_status("選擇模式：單人 / 開房 / 加入房")

func _refresh_stage_list() -> void:
	stage_list.clear()
	for i in range(LevelManager.levels.size()):
		var lv: LevelData = LevelManager.levels[i]
		var locked: bool = i > LevelManager.highest_unlocked
		var prefix: String = "🔒 " if locked else "▶ "
		stage_list.add_item("%s%s" % [prefix, lv.display_name])
		stage_list.set_item_disabled(i, locked)
	if LevelManager.levels.size() > 0:
		stage_list.select(min(LevelManager.highest_unlocked, LevelManager.levels.size() - 1))
		selected_stage = min(LevelManager.highest_unlocked, LevelManager.levels.size() - 1)
	stage_list.item_selected.connect(func(idx: int): selected_stage = idx)

func _on_single() -> void:
	NetworkManager.start_offline()

func _on_host() -> void:
	if NetworkManager.host_game():
		_set_status("已開房 (port %d)，本機 LAN IP: %s\n等待對手加入...或直接按【開始遊戲】" % [
			NetworkManager.DEFAULT_PORT, NetworkManager.get_lan_ip()
		])

func _on_join_toggle() -> void:
	join_row.visible = not join_row.visible
	if join_row.visible:
		ip_input.grab_focus()

func _on_join_confirm() -> void:
	var addr: String = ip_input.text.strip_edges()
	if addr == "":
		addr = "127.0.0.1"
	if NetworkManager.join_game(addr):
		_set_status("連線中: %s ..." % addr)

func _on_session_started(is_host: bool) -> void:
	if NetworkManager.is_offline():
		_set_status("單人模式")
	elif is_host:
		pass  # _on_host 已 set
	else:
		_set_status("已連線到 host (我的 id=%d)\n等待 host 開始遊戲..." % multiplayer.get_unique_id())

func _on_connection_failed() -> void:
	_set_status("連線失敗，請確認 IP / port / host 已開房")

func _on_peer_joined(id: int) -> void:
	_set_status("對手加入 (id=%d)，可以按【開始遊戲】了" % id)

func _on_play() -> void:
	# client 不能主動切場景；單人/host 可以
	if NetworkManager.is_client():
		_set_status("client 不能主動切場景，等 host 開始")
		return
	# 開新遊戲：重置分數/擊殺統計 (跨關不重置，由 _advance_stage 走另一條路)
	if NetworkManager.is_offline():
		GameManager.reset_session()
		LevelManager.start_level(selected_stage)
		get_tree().change_scene_to_file(MAIN_SCENE)
	else:
		# host: RPC 給所有 peer (含自己) 一起切場景，reset_score=true
		NetworkManager.rpc_start_match.rpc(selected_stage, true)

func _on_reset_pressed() -> void:
	reset_dialog.popup_centered()

func _on_reset_confirmed() -> void:
	LevelManager.reset_progress()
	_refresh_stage_list()
	_set_status("進度已重置")

func _set_status(msg: String) -> void:
	status_label.text = msg
