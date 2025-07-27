extends Node2D

# Main game logic for the castle defense game.
# This script controls spawning units and enemies, updating UI,
# managing waves, coins and castle health.

@onready var castle = $Castle
@onready var units_container = $Units
@onready var enemies_container = $Enemies
@onready var hud = $HUD
@onready var coins_label = hud.get_node("CoinsLabel")
@onready var castle_label = hud.get_node("CastleHealthLabel")
@onready var message_label = hud.get_node("MessageLabel")
@onready var sword_button = hud.get_node("Buttons/SwordButton")
@onready var archer_button = hud.get_node("Buttons/ArcherButton")
@onready var mage_button = hud.get_node("Buttons/MageButton")

var coins : int = 50
var castle_health : int = 100
var current_wave : int = 0

# Define wave parameters. Each wave is a dictionary with the number
# of enemies and their stats. Increase health, speed and damage per wave
# to gradually make the game more challenging but still playable.
var waves = [
    {"count": 3, "health": 40, "speed": 60, "damage": 5},
    {"count": 5, "health": 50, "speed": 70, "damage": 6},
    {"count": 7, "health": 60, "speed": 80, "damage": 8},
    {"count": 9, "health": 70, "speed": 90, "damage": 10}
]

# Time between spawning enemies within a wave (in seconds)
var spawn_interval : float = 1.2
var spawn_timer : float = 0.0
var spawn_count : int = 0
var game_over : bool = false

func _ready() -> void:
    # Connect button signals for unit spawning
    sword_button.connect("pressed", Callable(self, "_on_sword_pressed"))
    archer_button.connect("pressed", Callable(self, "_on_archer_pressed"))
    mage_button.connect("pressed", Callable(self, "_on_mage_pressed"))
    # Update UI at game start
    update_ui()
    # Start the first wave
    start_wave()

func start_wave() -> void:
    # Reset counters for spawning
    spawn_count = 0
    spawn_timer = 0.0
    # Display message for the new wave
    show_message("Wave %d" % (current_wave + 1))

func update_ui() -> void:
    # Refresh coins and castle health labels
    coins_label.text = "Coins: %d" % coins
    castle_label.text = "Castle HP: %d" % castle_health

func _process(delta: float) -> void:
    if game_over:
        return
    # Spawn enemies over time during active waves
    if current_wave < waves.size():
        spawn_timer += delta
        var wave = waves[current_wave]
        if spawn_count < wave["count"] and spawn_timer >= spawn_interval:
            spawn_enemy(wave)
            spawn_timer = 0.0
            spawn_count += 1
        # After all enemies are spawned and cleared, proceed to next wave
        elif spawn_count >= wave["count"] and enemies_container.get_child_count() == 0:
            # Reward the player with coins for completing the wave
            coins += 20 + current_wave * 10
            current_wave += 1
            update_ui()
            if current_wave >= waves.size():
                # All waves complete – player wins
                show_message("You won the campaign!")
                game_over = true
            else:
                start_wave()
    # Check collisions and attacks between units and enemies
    handle_combat(delta)
    # Check if any enemies reached the castle
    handle_castle_collisions()

func handle_combat(delta: float) -> void:
    # Attack interactions between all friendly units and enemies
    var dead_units : Array = []
    var dead_enemies : Array = []
    for unit in units_container.get_children():
        for enemy in enemies_container.get_children():
            # If units are close enough, they fight
            if abs(unit.position.x - enemy.position.x) < max(unit.attack_range, enemy.attack_range):
                unit.attack(enemy)
                enemy.attack(unit)
        # Mark dead player units for removal
        if unit.health <= 0:
            dead_units.append(unit)
    # Remove dead player units
    for u in dead_units:
        u.queue_free()
    # Mark and remove dead enemies; reward coins
    for enemy in enemies_container.get_children():
        if enemy.health <= 0:
            dead_enemies.append(enemy)
            coins += 5
    for e in dead_enemies:
        e.queue_free()
    if dead_enemies.size() > 0:
        update_ui()

func handle_castle_collisions() -> void:
    # Damage the castle if enemies reach it
    for enemy in enemies_container.get_children():
        if enemy.position.x < castle.position.x + 20:
            castle_health -= enemy.damage
            enemy.queue_free()
            if castle_health <= 0:
                castle_health = 0
                show_message("Your castle has fallen!")
                game_over = true
            update_ui()

func spawn_enemy(wave: Dictionary) -> void:
    # Create an enemy unit from the Unit class
    var enemy_scene : PackedScene = preload("res://scripts/unit.gd").resource
    var enemy = enemy_scene.new()
    # Initialise with enemy stats; texture for enemy
    enemy.init(false, wave["health"], wave["speed"], wave["damage"], 20, "res://sprites/enemy.png")
    enemy.position = Vector2(get_viewport().size.x - 50, castle.position.y)
    enemy.direction = -1
    enemies_container.add_child(enemy)

func _on_sword_pressed() -> void:
    # Spawn a melee sword unit if player can afford it
    var cost = 10
    if coins >= cost:
        coins -= cost
        var unit_scene : PackedScene = preload("res://scripts/unit.gd").resource
        var unit = unit_scene.new()
        unit.init(true, 70, 80, 8, 25, "res://sprites/player_sword.png")
        unit.position = Vector2(castle.position.x + 40, castle.position.y)
        unit.direction = 1
        units_container.add_child(unit)
        update_ui()

func _on_archer_pressed() -> void:
    # Spawn an archer unit with longer range but less health
    var cost = 15
    if coins >= cost:
        coins -= cost
        var unit_scene : PackedScene = preload("res://scripts/unit.gd").resource
        var unit = unit_scene.new()
        unit.init(true, 50, 90, 6, 80, "res://sprites/player_archer.png")
        unit.position = Vector2(castle.position.x + 40, castle.position.y)
        unit.direction = 1
        units_container.add_child(unit)
        update_ui()

func _on_mage_pressed() -> void:
    # Spawn a mage unit with high damage and long range but low health
    var cost = 20
    if coins >= cost:
        coins -= cost
        var unit_scene : PackedScene = preload("res://scripts/unit.gd").resource
        var unit = unit_scene.new()
        unit.init(true, 40, 60, 12, 120, "res://sprites/player_mage.png")
        unit.position = Vector2(castle.position.x + 40, castle.position.y)
        unit.direction = 1
        units_container.add_child(unit)
        update_ui()

func show_message(text: String) -> void:
    # Display a temporary message in the HUD
    message_label.text = text
    # Clear the message after a short delay
    var timer = Timer.new()
    timer.one_shot = true
    timer.wait_time = 3.0
    add_child(timer)
    timer.connect("timeout", Callable(self, "_on_message_timeout"))
    timer.start()

func _on_message_timeout() -> void:
    message_label.text = ""
