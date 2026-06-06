extends Node


# ============================================
# 公开方法 —— 供各节点调用
# ============================================

## 请求射击（Player.shoot() 调用）
## p_dir: 射击方向（世界空间）
## p_pos: 子弹生成位置（世界空间）
func request_shoot(p_dir: Vector3, p_pos: Vector3) -> void:
	if multiplayer.is_server():
		# 已经是服务器（host），直接执行
		_spawn_bullet(p_dir, p_pos, multiplayer.get_unique_id())
	else:
		# 客户端，发送 RPC 给服务器（id=1）
		_spawn_bullet.rpc_id(1, p_dir, p_pos, multiplayer.get_unique_id())


# ============================================
# Server 端 RPC —— 验证 + 执行
# ============================================

## 服务器执行：生成一颗子弹
## p_dir: 射击方向
## p_pos: 子弹生成位置
## p_shooter_id: 射击者的 peer_id（目前预留，未来用于伤害归属）
@rpc("any_peer", "call_local", "reliable")
func _spawn_bullet(p_dir: Vector3, p_pos: Vector3, _p_shooter_id: int) -> void:
	# 安全校验：只有服务器能执行
	if not multiplayer.is_server():
		return

	# TODO 未来：检查射击冷却、弹药、玩家是否活着

	# 从当前场景中找 World 的 MultiplayerSpawner
	var spawner: MultiplayerSpawner = _find_spawner()
	if not spawner:
		printerr("[RPCManager] 找不到 MultiplayerSpawner")
		return

	# 生成子弹（MultiplayerSpawner 自动同步到所有客户端）
	var bullet: RigidBody3D = spawner.spawn("uid://rbx5gknevc07")
	bullet.global_position = p_pos
	bullet.apply_central_impulse(p_dir * 100.0)


# ============================================
# 私有方法 —— 工具
# ============================================

## 在当前场景树中找到 World 的 MultiplayerSpawner 节点
func _find_spawner() -> MultiplayerSpawner:
	var world: Node = get_tree().current_scene
	if not world:
		return null
	return world.find_child("MultiplayerSpawner", true, false)
