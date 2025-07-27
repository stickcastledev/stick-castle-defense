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

# Upgrade buttons for upgrading each unit type.
@onready var upgrade_sword_button = hud.get_node("UpgradeButtons/UpgradeSwordButton")
@onready var upgrade_archer_button = hud.get_node("UpgradeButtons/UpgradeArcherButton")
@onready var upgrade_mage_button = hud.get_node("UpgradeButtons/UpgradeMageButton")

var coins : int = 50
var castle_health : int = 100
var current_wave : int = 0

# Upgrade levels for each unit type. Increasing these values will improve
# newly spawned units' health, speed and damage. Levels start at 0.
var upgrade_levels = {
    "sword": 0,
    "archer": 0,
    "mage": 0
}

# Base upgrade cost for each unit type. The actual cost scales with
# (upgrade level + 1), so the first upgrade costs base, the second costs
# base*2, etc.
var upgrade_base_costs = {
    "sword": 50,
    "archer": 60,
    "mage": 70
}

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

    # Connect upgrade button signals for upgrading units
    upgrade_sword_button.connect("pressed", Callable(self, "_on_upgrade_sword_pressed"))
    upgrade_archer_button.connect("pressed", Callable(self, "_on_upgrade_archer_pressed"))
    upgrade_mage_button.connect("pressed", Callable(self, "_on_upgrade_mage_pressed"))
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
    # Spawn a melee sword unit if player can afford it. Stats scale with upgrade level.
    var cost = 10
    if coins >= cost:
        coins -= cost
        # Calculate stats based on upgrade level
        var lvl = upgrade_levels["sword"]
        var health = 70 + lvl * 10
        var speed = 80 + lvl * 5
        var damage = 8 + lvl * 2
        var range = 25
        # Create a new Unit instance and initialise it
        var unit_scene : PackedScene = preload("res://scripts/unit.gd").resource
        var unit = unit_scene.new()
        unit.init(true, health, speed, damage, range, "res://sprites/player_sword.png")
        unit.position = Vector2(castle.position.x + 40, castle.position.y)
        unit.direction = 1
        units_container.add_child(unit)
        update_ui()

func _on_archer_pressed() -> void:
    # Spawn an archer unit with stats scaling by upgrade level
    var cost = 15
    if coins >= cost:
        coins -= cost
        var lvl = upgrade_levels["archer"]
        var health = 50 + lvl * 8
        var speed = 90 + lvl * 5
        var damage = 6 + lvl * 2
        var range = 80 + lvl * 10  # increase range slightly per level
        var unit_scene : PackedScene = preload("res://scripts/unit.gd").resource
        var unit = unit_scene.new()
        unit.init(true, health, speed, damage, range, "res://sprites/player_archer.png")
        unit.position = Vector2(castle.position.x + 40, castle.position.y)
        unit.direction = 1
        units_container.add_child(unit)
        update_ui()

func _on_mage_pressed() -> void:
    # Spawn a mage unit with high damage and long range; stats scale with upgrade level
    var cost = 20
    if coins >= cost:
        coins -= cost
        var lvl = upgrade_levels["mage"]
        var health = 40 + lvl * 6
        var speed = 60 + lvl * 4
        var damage = 12 + lvl * 3
        var range = 120 + lvl * 15  # extend range slightly per level
        var unit_scene : PackedScene = preload("res://scripts/unit.gd").resource
        var unit = unit_scene.new()
        unit.init(true, health, speed, damage, range, "res://sprites/player_mage.png")
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

# Upgrade button handlers. These functions increase the corresponding
# upgrade level if the player has enough coins. The cost scales with
# (current_level + 1) * base_cost. If successful, coins are deducted
# and a status message is shown.
func _on_upgrade_sword_pressed() -> void:
    var level = upgrade_levels["sword"]
    var cost = upgrade_base_costs["sword"] * (level + 1)
    if coins >= cost:
        coins -= cost
        upgrade_levels["sword"] = level + 1
        show_message("Sword upgraded to level %d" % upgrade_levels["sword"])
        update_ui()
    else:
        show_message("Not enough coins to upgrade Sword (cost: %d)" % cost)

func _on_upgrade_archer_pressed() -> void:
    var level = upgrade_levels["archer"]
    var cost = upgrade_base_costs["archer"] * (level + 1)
    if coins >= cost:
        coins -= cost
        upgrade_levels["archer"] = level + 1
        show_message("Archer upgraded to level %d" % upgrade_levels["archer"])
        update_ui()
    else:
        show_message("Not enough coins to upgrade Archer (cost: %d)" % cost)

func _on_upgrade_mage_pressed() -> void:
    var level = upgrade_levels["mage"]
    var cost = upgrade_base_costs["mage"] * (level + 1)
    if coins >= cost:
        coins -= cost
        upgrade_levels["mage"] = level + 1
        show_message("Mage upgraded to level %d" % upgrade_levels["mage"])
        update_ui()
    else:
        show_message("Not enough coins to upgrade Mage (cost: %d)" % cost)