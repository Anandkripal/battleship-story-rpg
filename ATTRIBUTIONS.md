# Attributions

This public repository contains code, data definitions, and placeholder/demo assets only. Large local asset packs and private chapter assets remain ignored by Git.

## Optional Local 3D Asset Packs

The project can optionally load the following local asset packs when present under `assets/`:

- Quaternius Ultimate Space Kit - local `License.txt` states CC0 1.0 Universal / Public Domain Dedication.
- Quaternius Ultimate Spaceships Pack - local `License.txt` states CC0 1.0 Universal / Public Domain Dedication.

The raw pack folders are ignored so they are not committed accidentally. Runtime code resolves these models by optional paths and falls back to generated placeholder geometry when the packs are absent.
