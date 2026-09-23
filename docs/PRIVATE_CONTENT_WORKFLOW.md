# Private Content Workflow

This repository is intended to be public. Keep copyrighted, private, or local-only material out of Git.

## Local Folders

Use these ignored folders for private work:

- `private_assets/`
- `local_content/`
- `reference_material/`
- `assets/private/`
- `assets/manhua/`
- `chapters/private/`
- `chapters/local/`

## Recommended Flow

1. Copy private chapter images locally into `assets/private/`.
2. Store private chapter JSON in `chapters/private/`.
3. Use `assets/asset_manifest.local.json` for private manifest entries.
4. Never commit those files.
5. Keep public demo data separate under `chapters/demo/`, `data/`, and `assets/demo/`.

## Local Manifest

`AssetManifestManager` loads `assets/asset_manifest.json` first, then merges `assets/asset_manifest.local.json` if it exists. Local entries can extend or override public entries on your machine.

Generate placeholder private manifest entries with:

```bash
python tools/build_asset_manifest.py assets/private/ch01
```

The script scans image filenames only. It does not OCR images, classify images, or invent descriptions.
