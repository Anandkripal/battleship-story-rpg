# Architecture

This project is designed for story-first progression with mechanics that can grow unpredictably across future chapters.

## Event Runner

`EventRunner` handles generic event kinds:

- `story`
- `narration`
- `choice`
- `mechanic`
- `reward`
- `state_change`
- `conditional`
- `jump`
- `chapter_boundary`
- `end`

It does not branch on specific gameplay systems such as scan, mining, battle, or research. For `kind: "mechanic"`, it calls `MechanicRegistry.run_mechanic(mechanic_id, params)`.

`chapter_boundary` is used when a serialized chapter ends but the gameplay flow may or may not pause. It can mark the current chapter complete, autosave, show or skip the completion screen, and optionally continue into another chapter/event. This lets a cliffhanger, battle, chase, or conversation continue across chapter files without forcing rewards, upgrades, or menu resets.

## Mechanic Registry

`MechanicRegistry` loads `data/mechanics.json` and maps mechanic IDs to scenes. A mechanic scene extends `BaseMechanic`, implements `start(params)`, and emits `completed(result)`.

## Gameplay Loop

The campaign is intended to unlock gameplay instead of replacing gameplay. A chapter can move through:

`campaign story -> exploration -> encounter/combat/mining -> rewards/salvage -> repairs/loadout -> next story beat`

The current reusable gameplay layers are:

- `exploration`: sector navigation with connected nodes, optional encounters, repairs, and objective destinations.
- `battle`: real-time tactical ship combat with click-to-move, target range, cooldowns, energy distribution, simple obstacles, deterministic AI profiles, and salvage rewards.
- `loadout`: data-driven module inspection and simple module installation.
- `mining`, `scan`, `upgrade`, and `map`: earlier mechanics that remain available for chapters and tutorials.
- `battle_3d`: separate 3D ship combat prototype launched through `GameEventManager`.
- `ship_management`: Fire Warship module preview and upgrade screen.

Combat state is explicit and data-driven where practical: ships use stable IDs, modules reference action IDs, enemy behavior comes from `ai_profile`, and battle rewards can come from enemy data plus loot tables. This keeps the single-player prototype easier to evolve toward future fleet or multiplayer systems without coupling the simulation to one chapter.

See `docs/THREE_D_GAMEPLAY.md` for the 3D gameplay layer.

## Dynamic State

State is dictionary-based:

- `PlayerState.state`
- `ShipState.ship_data`
- `WorldState.state`

Use `StatePathUtil` to modify state through paths like:

- `player.resources.credits`
- `ship.stats.scanner_level`
- `world.flags.met_signal`

This avoids fixed resource/stat lists in code and save files.

## Data Files

The public demo uses JSON files in `data/`:

- `system_abilities.json`
- `scan_targets.json`
- `battle_actions.json`
- `enemies.json`
- `modules.json`
- `sectors.json`
- `encounters.json`
- `loot_tables.json`
- `ship_definitions.json`
- `weapon_definitions.json`
- `fire_warship_modules.json`
- `battle_3d_configs.json`
- `upgrades.json`
- `locations.json`
- `mechanics.json`

## Asset Manifest

Chapters should reference assets by manifest ID when possible. `AssetManifestManager` first loads the public manifest, then optionally merges `assets/asset_manifest.local.json` for private local work.
