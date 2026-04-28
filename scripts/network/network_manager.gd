extends Node
## 多人連線管理 (autoload: NetworkManager)
## MVP: ENet listen-server，host 同時也是玩家
## 支援單人 (offline) 模式：peer_id 0 視為單人

signal session_started(is_host: bool)
signal session_ended
signal peer_joined(peer_id: int)
signal peer_left(peer_id: int)
signal connection_failed

const DEFAULT_PORT: int = 7000
const MAX_PLAYERS: int = 2

enum Mode { OFFLINE, HOST, CLIENT }

var mode: int = Mode.OFFLINE
var peer: ENetMultiplayerPeer = null
var players: Dictionary = {}  # peer_id -> { "name": String, ... }

func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)

func is_offline() -> bool:
	return mode == Mode.OFFLINE

func is_host() -> bool:
	return mode == Mode.HOST

func is_client() -> bool:
	return mode == Mode.CLIENT

func is_authoritative() -> bool:
	# 單人 + host 都是權威端 (跑 AI、發動敵人 spawn)
	return mode != Mode.CLIENT

# ---------- session 控制 ----------
func start_offline() -> void:
	_cleanup()
	mode = Mode.OFFLINE
	session_started.emit(true)

func host_game(port: int = DEFAULT_PORT) -> bool:
	_cleanup()
	peer = ENetMultiplayerPeer.new()
	var err: int = peer.create_server(port, MAX_PLAYERS)
	if err != OK:
		push_error("[NetworkManager] create_server failed: %d" % err)
		return false
	multiplayer.multiplayer_peer = peer
	mode = Mode.HOST
	players[1] = {"name": "HOST"}
	print("[NetworkManager] hosting on port %d" % port)
	session_started.emit(true)
	return true

func join_game(address: String, port: int = DEFAULT_PORT) -> bool:
	_cleanup()
	peer = ENetMultiplayerPeer.new()
	var err: int = peer.create_client(address, port)
	if err != OK:
		push_error("[NetworkManager] create_client failed: %d" % err)
		return false
	multiplayer.multiplayer_peer = peer
	mode = Mode.CLIENT
	print("[NetworkManager] connecting to %s:%d" % [address, port])
	return true

func leave_session() -> void:
	_cleanup()
	mode = Mode.OFFLINE
	session_ended.emit()

func _cleanup() -> void:
	if peer != null:
		peer.close()
		peer = null
	multiplayer.multiplayer_peer = null
	players.clear()

# ---------- 內建事件 ----------
func _on_peer_connected(id: int) -> void:
	print("[NetworkManager] peer joined: %d" % id)
	players[id] = {"name": "P%d" % id}
	peer_joined.emit(id)

func _on_peer_disconnected(id: int) -> void:
	print("[NetworkManager] peer left: %d" % id)
	players.erase(id)
	peer_left.emit(id)

func _on_connected_to_server() -> void:
	print("[NetworkManager] connected to server (my id=%d)" % multiplayer.get_unique_id())
	session_started.emit(false)

func _on_connection_failed() -> void:
	push_warning("[NetworkManager] connection failed")
	_cleanup()
	mode = Mode.OFFLINE
	connection_failed.emit()

func _on_server_disconnected() -> void:
	print("[NetworkManager] server disconnected")
	_cleanup()
	mode = Mode.OFFLINE
	session_ended.emit()

# ---------- 場景切換 RPC ----------
## host 呼叫 → 所有 peer (含 host) 切到 Main 場景並載入指定關卡
@rpc("authority", "call_local", "reliable")
func rpc_start_match(level_index: int) -> void:
	LevelManager.start_level(level_index)
	get_tree().change_scene_to_file("res://scenes/Main.tscn")

@rpc("authority", "call_local", "reliable")
func rpc_return_to_lobby() -> void:
	get_tree().change_scene_to_file("res://scenes/Lobby.tscn")

# ---------- 工具 ----------
static func get_lan_ip() -> String:
	for ip in IP.get_local_addresses():
		if ip.begins_with("192.168.") or ip.begins_with("10.") or ip.begins_with("172."):
			return ip
	return "127.0.0.1"
