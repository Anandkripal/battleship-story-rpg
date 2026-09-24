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
- `upgrades.json`
- `locations.json`
- `mechanics.json`

## Asset Manifest

Chapters should reference assets by manifest ID when possible. `AssetManifestManager` first loads the public manifest, then optionally merges `assets/asset_manifest.local.json` for private local work.
