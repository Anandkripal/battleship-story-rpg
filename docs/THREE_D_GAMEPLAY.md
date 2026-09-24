# 3D Gameplay Architecture

The project now has three layers:

- Story layer: chapter JSON, story viewer, choices, and manhua-style presentation.
- Strategy layer: resources, modules, ship management, calendar, alternate-space state, saves, and progression flags.
- 3D gameplay layer: reusable battle scenes for ships, targeting, sensors, movement, weapons, AI, and battle results.

Future chapters should not manipulate combat ships directly. They should call a reusable gameplay bridge such as:

```gdscript
var result: Dictionary = await GameEventManager.start_battle({
	"battle_config": "prototype_fire_warship_trial"
})
```

The returned result is a Dictionary with fields such as:

```json
{
  "result": "victory",
  "ships_destroyed": 3,
  "damage_dealt": 421,
  "damage_received": 97,
  "rewards": {
    "source_points": 14,
    "iron": 10
  },
  "player_ship_state": {
    "hull": 391,
    "armor": 220,
    "shield": 90
  }
}
```

## Data Files

- `data/ship_definitions.json`: hull definitions, stats, slots, hardpoints, and future evolution targets.
- `data/weapon_definitions.json`: reusable weapon definitions.
- `data/fire_warship_modules.json`: Fire Warship module definitions and upgrade costs.
- `data/battle_3d_configs.json`: fleet/battlefield configurations.

## Combat Systems

- `scripts/combat/battle_controller.gd`: owns a battle instance, fleets, HUD, camera, results, and win/retreat/defeat.
- `scripts/combat/ship_controller.gd`: movement, shield/armor/hull, energy, hardpoints, weapons, and destruction.
- `scripts/combat/targeting_system.gd`: sensor states: `UNDETECTED`, `CONTACT`, `CLASSIFIED`, `SCANNED`.
- `scripts/combat/combat_ai.gd`: lightweight reusable enemy AI.
- `scripts/combat/weapon_system.gd`: helper functions for weapon range/readiness.

## Controls

- Left click a ship: select player ship or target enemy.
- Left click empty space: move selected ship.
- Right mouse drag: orbit camera.
- Mouse wheel: zoom.
- Middle mouse drag: pan.
- `F`: toggle follow selected ship.
- `R`: reset camera.
- `Esc` or Retreat button: retreat and return a battle result.

## Ship Management

`scenes/ship_management.tscn` shows the Fire Warship preview, equipped modules, costs, current stats, next-level stats, and an upgrade button. Upgrades call `GameEventManager.upgrade_fire_warship_module()`, deduct resources, update module levels, and save.

## Save Compatibility

New fields are merged into default dictionaries when old saves load. Existing saves should gain sensible defaults for:

- materials and Source Points
- Fire Warship module state
- game calendar
- alternate-space cooldown state
- last battle result

## Adding Content

To add a ship, add an entry to `data/ship_definitions.json`.

To add a weapon, add an entry to `data/weapon_definitions.json` and reference it from a battle config or module.

To add a module, add an entry to `data/fire_warship_modules.json`, then equip it through `ShipState` or a future loot/unlock flow.

To configure a battle, add an entry to `data/battle_3d_configs.json` with player and enemy fleet arrays.

To add a future hull, add a new ship definition and reference it from an existing definition's `evolution_targets`.
