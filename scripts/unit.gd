extends Node2D

# Base class for units (player and enemy).
# Handles movement, attacking and health.

class_name Unit

# Whether this unit belongs to the player. Determines movement direction
# and coin rewards.
var is_player : bool = true
# Character stats
var health : float = 100.0
var max_health : float = 100.0
var speed : float = 60.0
var damage : float = 5.0
var attack_range : float = 30.0
var attack_cooldown : float = 0.6

# Internal state
var _cooldown_timer : float = 0.0
var direction : int = 1
var texture_path : String = ""

# Visual elements
var sprite : Sprite2D
var health_bar_bg : ColorRect
var health_bar_fg : ColorRect

func init(is_player_val: bool, health_val: float, speed_val: float, damage_val: float, range_val: float, texture_file: String) -> void:
    # Called by the spawner to initialise this unit's stats and appearance
    is_player = is_player_val
    health = health_val
    max_health = health_val
    speed = speed_val
    damage = damage_val
    attack_range = range_val
    texture_path = texture_file

func _ready() -> void:
    # Create and attach a sprite for the unit
    sprite = Sprite2D.new()
    if texture_path != "":
        sprite.texture = load(texture_path)
    # Flip the sprite horizontally for enemies so that they face left
    sprite.flip_h = not is_player
    add_child(sprite)
    # Create a simple health bar composed of a background and foreground
    health_bar_bg = ColorRect.new()
    health_bar_bg.color = Color(0.2, 0.2, 0.2, 1.0)
    health_bar_bg.size = Vector2(34, 5)
    health_bar_bg.position = Vector2(-17, -30)
    add_child(health_bar_bg)
    health_bar_fg = ColorRect.new()
    health_bar_fg.color = Color(0.0, 0.8, 0.0, 1.0)
    health_bar_fg.size = Vector2(34, 5)
    health_bar_fg.position = Vector2(-17, -30)
    add_child(health_bar_fg)

func _process(delta: float) -> void:
    # Move horizontally in the direction based on owner (player or enemy)
    position.x += speed * direction * delta
    # Decrease cooldown timer
    if _cooldown_timer > 0.0:
        _cooldown_timer -= delta
    # Update the size of the health bar foreground to reflect current health
    var percent = clamp(health / max_health, 0.0, 1.0)
    health_bar_fg.size.x = 34 * percent
    # Change bar colour based on remaining health
    if percent > 0.5:
        health_bar_fg.color = Color(0.0, 0.8, 0.0, 1.0)
    elif percent > 0.25:
        health_bar_fg.color = Color(0.9, 0.6, 0.0, 1.0)
    else:
        health_bar_fg.color = Color(0.9, 0.0, 0.0, 1.0)

func attack(target: Unit) -> void:
    # Attack another unit if the cooldown has expired
    if _cooldown_timer <= 0.0 and target.health > 0.0:
        target.health -= damage
        _cooldown_timer = attack_cooldown
