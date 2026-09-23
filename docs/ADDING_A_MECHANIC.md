# Adding A Mechanic

This guide adds a new example mechanic called `research`. The event runner does not need modification.

## 1. Create A Scene And Script

Create:

```text
mechanics/research/research.tscn
mechanics/research/research.gd
```

The script should extend `BaseMechanic`:

```gdscript
extends "res://mechanics/base_mechanic.gd"

func start(params: Dictionary) -> void:
	super.start(params)
	# Build research UI from params and/or JSON data.

func _finish_research() -> void:
	finish({
		"success": true,
		"changes": [
			{
				"path": "world.discovered_technologies.plasma_tools",
				"operation": "set",
				"value": true
			}
		]
	})
```

## 2. Register It

Add this to `data/mechanics.json`:

```json
{
  "research": {
    "scene": "res://mechanics/research/research.tscn",
    "description": "Researches technologies from data."
  }
}
```

## 3. Use It In A Chapter

```json
{
  "id": "research_plasma_tools",
  "kind": "mechanic",
  "mechanic": "research",
  "params": {
    "technology": "plasma_tools"
  },
  "next": "after_research"
}
```

## Why EventRunner Does Not Change

`EventRunner` only sees:

```json
"kind": "mechanic",
"mechanic": "research"
```

It asks `MechanicRegistry` to run `research`, waits for the mechanic to emit `completed(result)`, applies any returned state changes, autosaves, and continues.
