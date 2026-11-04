class_name GameConstants
## Global gameplay, rendering and world constants (port of GameConstants.ts).
## All lengths are in world units; one tile is TILE_SIZE units wide.

# Gravity
const GRAVITY := 30.0
const MAX_FALL_SPEED := 30.0

# Camera
const CAMERA_FOV := 75.0
const CAMERA_NEAR := 0.1
const CAMERA_FAR := 100.0

# Player
const PLAYER_SPEED := 6.0
const PLAYER_RADIUS := 0.3
## Eye height above the feet.
const PLAYER_EYE_HEIGHT := 0.5
const MOUSE_SENSITIVITY := 0.001
const PITCH_LIMIT_DEG := 80.0

# Weapon
const PISTOL_DAMAGE := 34.0
const PISTOL_COOLDOWN := 0.2

# Projectile
const PROJECTILE_SPEED := 200.0

# Enemy
const ENEMY_HP := 100.0
const ENEMY_RADIUS := 0.3
## Height of the enemy's reference point (sprite center) above its feet.
const ENEMY_BASE_HEIGHT := 0.4

# Physics layers
const LAYER_WORLD := 1
const LAYER_PLAYER := 2
const LAYER_ENEMY := 4

