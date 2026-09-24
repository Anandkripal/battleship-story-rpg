# Battleship Story RPG

A Godot 4 framework for a landscape, story-driven sci-fi battleship progression game. The public repository contains only engine code, JSON demo data, and original placeholder assets.

## Screenshots

Screenshots will be added after the visual direction is further developed.

## Project Overview

The game is built around chapters made of generic events. Story, choices, rewards, state changes, conditionals, jumps, chapter boundaries, and endings are handled by `EventRunner`. Gameplay systems are separate mechanics registered by string ID through `MechanicRegistry`.

This keeps future chapter systems flexible. A later chapter can introduce scanning, exploration, tactical combat, fleet combat, auctions, research, territory management, diplomacy, dimensional travel, or something not known yet without redesigning save data or rewriting the event runner.

## Godot Version

- Godot 4.x
- Primary development platform: macOS
- Layout: 16:9 landscape, 1280 x 720 base resolution
- Future export targets: Android and iOS, designed for landscape orientation

## Running The Demo

1. Open this folder in Godot 4.
2. Run the project.
3. Choose **Start Demo Chapter**.

The demo flow covers:

`Main Menu -> Story -> Narration -> Choice -> Scan -> Story -> Map -> Mining -> Battle -> Reward -> Upgrade -> Chapter Complete`

The story viewer supports landscape layouts such as `bottom_dialogue`, `side_dialogue`, `full_art`, `cinematic`, and `split`. Tall chapter images can be shown with display modes such as `fit`, `crop`, `focus_crop`, `split_layout`, `background_blur`, and `panel_sequence`.

## Architecture Summary

- `ChapterManager` loads chapter JSON and tracks the current event.
- `EventRunner` processes generic event kinds and delegates mechanics.
- `MechanicRegistry` maps mechanic IDs to scenes.
- `PlayerState`, `ShipState`, and `WorldState` store flexible dictionaries.
- `StatePathUtil` applies data-driven changes like `player.resources.credits`.
- `SaveManager` writes dynamic state to `user://savegame.json`.
- `DataManager` loads JSON data files.
- `AssetManifestManager` resolves manifest IDs to asset paths and can merge local private manifests.
- `UIManager` swaps scenes and shared UI flows.
- `ValidationManager` checks JSON, events, mechanics, assets, state paths, and scene references.

## Gameplay Loop

The project now supports a fuller campaign loop:

`Campaign Story -> Exploration -> Combat/Mining/Scan -> Rewards/Salvage -> Repair/Loadout -> Progression`

Reusable gameplay systems include:

- `exploration`: data-driven sector nodes, connections, objective destinations, optional encounters, repair nodes, and resources.
- `battle`: real-time tactical combat with click-to-move, weapon ranges, cooldowns, energy allocation, obstacles, AI profiles, and salvage.
- `battle_3d`: 3D Fire Warship prototype with orbit camera, sensors, targeting, shield/armor/hull, energy, AI enemies, retreat, and battle reports.
- `loadout`: module inspection and simple module installation from `data/modules.json`.
- `ship_management`: Fire Warship module upgrades using Source Points and materials.
- `scan`, `mining`, `upgrade`, and `map`: supporting mechanics for tutorial and progression beats.

## Chapter/Event Format

Chapters live in `chapters/demo/`. A mechanic event looks like:

```json
{
  "id": "scan_training_ship",
  "kind": "mechanic",
  "mechanic": "scan",
  "params": {
    "target": "training_ship"
  },
  "next": "post_scan_story"
}
```

## Adding Mechanics

Mechanics extend `mechanics/base_mechanic.gd`, implement `start(params)`, and emit `completed(result)`. Register the mechanic in `data/mechanics.json`. No `EventRunner` change is required.

See `docs/ADDING_A_MECHANIC.md`.

## Adding Resources, Stats, Locations, And Abilities

- Resources: add keys through state changes under `player.resources.*`.
- Stats: add keys under `player.stats.*` or `ship.stats.*`.
- Locations: edit `data/locations.json`.
- System abilities: edit `data/system_abilities.json`.
- Upgrades: edit `data/upgrades.json`.
- Modules: edit `data/modules.json` or add private overrides in `data/private/modules.local.json`.
- Sectors and encounters: edit `data/sectors.json` / `data/encounters.json` or use local overrides.
- Loot tables: edit `data/loot_tables.json`.
- 3D ships: edit `data/ship_definitions.json`.
- 3D weapons: edit `data/weapon_definitions.json`.
- Fire Warship modules: edit `data/fire_warship_modules.json`.
- 3D battle configs: edit `data/battle_3d_configs.json`.
- 3D visual models: edit `data/visual_models.json` or local overrides.
- Battle actions: edit `data/battle_actions.json` and reference them from ship abilities/modules.

The UI builds from data where practical; it does not hardcode ability buttons or upgrade categories.

## Save System

Saves are written to `user://savegame.json` and include:

- player state
- ship state
- world state
- current chapter
- current event
- dynamic resources, flags, inventory, relationships, and unlocks

Autosaves happen after mechanics, rewards, chapter progression, and menu-related save points.

Chapter files may end with `kind: "chapter_boundary"` when a serialized scene should continue across chapter files. The boundary can show or skip the completion screen, mark the chapter complete, autosave, and optionally continue into a specific event in the next chapter.

## Validation

Use the main menu **Validate Project** button to run in-game validation. If Godot is available in your shell, you can also run the project headlessly using the Godot executable for parser/import checks.

Headless smoke tests:

```bash
Godot --headless --path . --script res://tools/run_validation.gd
Godot --headless --path . --script res://tools/smoke_gameplay.gd
Godot --headless --path . --script res://tools/smoke_battle_3d.gd
Godot --headless --path . --script res://tools/smoke_battle_3d_performance.gd
```

## Copyright-Safe Public Repository

Do not commit copyrighted comic/manhua images, copied dialogue, private references, or local chapter material.

Private/local content belongs in ignored folders such as:

- `private_assets/`
- `local_content/`
- `reference_material/`
- `assets/private/`
- `assets/manhua/`
- `chapters/private/`

See `docs/PRIVATE_CONTENT_WORKFLOW.md`.

## Optional Local 3D Asset Packs

The 3D combat prototype can load local Quaternius CC0 asset packs from ignored folders under `assets/`. Public wrapper scenes and `data/visual_models.json` reference optional paths only; if the packs are absent, the game uses generated placeholder ship, planet, and asteroid visuals.

Raw downloaded packs remain ignored and should not be committed. See `ATTRIBUTIONS.md` and `docs/THREE_D_GAMEPLAY.md`.

## Local Asset Manifest

Public assets are listed in `assets/asset_manifest.json`. Local private assets may be listed in `assets/asset_manifest.local.json`, which is ignored by Git and can override or extend the public manifest.

Generate placeholder local entries with:

```bash
python tools/build_asset_manifest.py assets/private/ch01
```

Private Chapter 1-2 assets in this local project use legacy IDs like `ch01_001`; newer private chapters may use source-chapter IDs like `ch003_001`.
