class_name GameConst
## 遊戲全域常數

const TILE_SIZE: int = 32
const MAP_W: int = 13
const MAP_H: int = 13
const MAP_PX_W: int = TILE_SIZE * MAP_W   # 416
const MAP_PX_H: int = TILE_SIZE * MAP_H   # 416

const PLAYER_SPEED: float = 110.0
const ENEMY_SPEED: float = 70.0
const BULLET_SPEED: float = 320.0

enum Dir { UP, RIGHT, DOWN, LEFT }

const DIR_VEC := {
	Dir.UP:    Vector2(0, -1),
	Dir.RIGHT: Vector2(1,  0),
	Dir.DOWN:  Vector2(0,  1),
	Dir.LEFT:  Vector2(-1, 0),
}

const DIR_ANGLE := {
	Dir.UP:    0.0,
	Dir.RIGHT: PI / 2.0,
	Dir.DOWN:  PI,
	Dir.LEFT:  -PI / 2.0,
}
