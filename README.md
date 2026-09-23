# Battleship Story RPG

A Godot 4 framework for a portrait, story-driven sci-fi battleship progression game. The public repository contains only engine code, JSON demo data, and original placeholder assets.

## Screenshots

Screenshots will be added after the visual direction is further developed.

## Project Overview

The game is built around chapters made of generic events. Story, choices, rewards, state changes, conditionals, jumps, and endings are handled by `EventRunner`. Gameplay systems are separate mechanics registered by string ID through `MechanicRegistry`.

This keeps future chapter systems flexible. A later chapter can introduce scanning, fleet combat, auctions, research, territory management, diplomacy, dimensional travel, or something not known yet without redesigning save data or rewriting the event runner.

## Godot Version

- Godot 4.x
- Primary development platform: macOS
- Layout: portrait, 720 x 1280 base resolution
- Future export targets: Android and iOS

## Running The Demo

1. Open this folder in Godot 4.
2. Run the project.
3. Choose **Start Demo Chapter**.

The demo flow covers:

`Main Menu -> Story -> Narration -> Choice -> Scan -> Story -> Map -> Mining -> Battle -> Reward -> Upgrade -> Chapter Complete`

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

## Validation

Use the main menu **Validate Project** button to run in-game validation. If Godot is available in your shell, you can also run the project headlessly using the Godot executable for parser/import checks.

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

## Local Asset Manifest

Public assets are listed in `assets/asset_manifest.json`. Local private assets may be listed in `assets/asset_manifest.local.json`, which is ignored by Git and can override or extend the public manifest.

Generate placeholder local entries with:

```bash
python tools/build_asset_manifest.py assets/private/ch01
```
