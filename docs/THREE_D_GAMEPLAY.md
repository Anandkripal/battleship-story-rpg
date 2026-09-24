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
- `data/visual_models.json`: optional visual model IDs and transforms for local asset packs.

## Visual Wrapper Architecture

Combat logic and ship visuals are deliberately separate:

```text
Ship3D
├── GameplayRoot
├── VisualRoot
│   └── ShipVisualWrapper
├── Hardpoints
├── EnginePoints
├── VFX
└── Audio
```

`ShipController` owns movement, shields, armor, hull, energy, targeting, and firing. `ShipVisualWrapper` owns only the displayed model. Replacing a Quaternius model later should only require changing a visual wrapper scene or `data/visual_models.json`.

Current wrapper scenes:

- `scenes/ships/visuals/player_fire_warship.tscn`
- `scenes/ships/visuals/enemy_frigate.tscn`
- `scenes/ships/visuals/enemy_destroyer.tscn`
- `scenes/ships/visuals/enemy_cruiser.tscn`

The wrappers load optional local glTF files when present. If the ignored local asset packs are missing, they generate readable fallback geometry so public clones still run.

Selected optional local models:

- Fire Warship: Quaternius `Executioner`
- Frigate: Quaternius `Spitfire`
- Destroyer: Quaternius `Imperial`
- Cruiser: Quaternius `Zenith`
- Planet: Quaternius Space Kit `Planet_7`, with procedural fallback
- Asteroids: Quaternius Space Kit `Rock_1` and `Rock_Large_2`, with procedural fallback

## Hardpoints

Weapons fire from named hardpoints in `data/ship_definitions.json`, for example:

- `MainWeapon`
- `SecondaryWeaponLeft`
- `SecondaryWeaponRight`
- `MissileLauncher`
- `EngineLeft`
- `EngineRight`
- `SpecialModule`

Weapon definitions can specify a `hardpoint`. Module definitions can specify `visual_attachment` so ship management can highlight the relevant area.

## Combat Systems

- `scripts/combat/battle_controller.gd`: owns a battle instance, fleets, HUD, camera, results, and win/retreat/defeat.
- `scripts/combat/ship_controller.gd`: movement, shield/armor/hull, energy, hardpoints, weapons, and destruction.
- `scripts/combat/targeting_system.gd`: sensor states: `UNDETECTED`, `CONTACT`, `CLASSIFIED`, `SCANNED`.
- `scripts/combat/combat_ai.gd`: lightweight reusable enemy AI.
- `scripts/combat/weapon_system.gd`: helper functions for weapon range/readiness.
- `scripts/combat/model_catalog.gd`: resolves optional visual model IDs.
- `scripts/combat/ship_visual_wrapper.gd`: visual-only wrapper with generated fallback ships.

## Controls

- Left click a ship: select player ship or target enemy.
- Left click empty space: move selected ship.
- Right mouse drag: orbit camera.
- Mouse wheel: zoom.
- Middle mouse drag: pan.
- `F`: focus selected ship.
- `T`: focus selected target.
- `R`: reset camera.
- `Esc` or Retreat button: retreat and return a battle result.

The HUD also exposes `Approach`, `Scan`, `Maintain`, `Stop`, `Focus Ship`, `Focus Target`, `Repair`, and `Retreat`.

## Sensors

Enemy ships begin as sensor contacts when distance and signature permit. Target information progresses through:

```text
UNDETECTED -> CONTACT -> CLASSIFIED -> SCANNED
```

The `Scan` command manually promotes a selected target to `SCANNED` when it is inside the scan envelope. Chapters and future exploration systems can reuse the same sensor concepts.

## Space Environment

`battle_3d_configs.json` can configure:

- starfield count
- distant sun/light
- large planet
- asteroid field count, center, spread, and optional model IDs

The playable trial uses a large planet, a directional sun, a starfield, visual asteroids, and kilometer-scale enemy contact placement.

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

To add a ship, add an entry to `data/ship_definitions.json`. Include dynamic stats, hardpoints, slots, and optional `visual_scene` / `visual_model` fields.

To add a ship model, add a wrapper scene under `scenes/ships/visuals/` or add a `visual_model` entry to `data/visual_models.json`. Prefer optional paths so public clones fall back gracefully.

To replace a Quaternius model later, keep the same ship definition and hardpoint names. Update the wrapper scene or visual model transform until the new mesh aligns.

To add a weapon, add an entry to `data/weapon_definitions.json` and reference it from a battle config or module. Set `range`, `cooldown`, `energy_cost`, `projectile_speed`, and `hardpoint`.

To add a module, add an entry to `data/fire_warship_modules.json`, then equip it through `ShipState` or a future loot/unlock flow.

To configure a battle, add an entry to `data/battle_3d_configs.json` with player and enemy fleet arrays.

To add a future hull, add a new ship definition and reference it from an existing definition's `evolution_targets`.

## Smoke Tests

```bash
Godot --headless --path . --script res://tools/run_validation.gd
Godot --headless --path . --script res://tools/smoke_battle_3d.gd
Godot --headless --path . --script res://tools/smoke_battle_3d_performance.gd
Godot --headless --path . --script res://tools/smoke_save_compat.gd
```
