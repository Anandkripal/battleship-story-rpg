# Demo Battle Flight And Performance Notes

This document records the local standalone Demo Battle pass focused on making one Fire Warship directly playable before adding more visual complexity.

## Profile Snapshot

Headless smoke checks before the flight-control pass showed the small Demo Battle starting quickly and the larger 10-enemy performance scene completing within the existing smoke budget. The major visible performance risks in the live scene were architectural rather than raw data size:

- Ship movement, AI, enemy fire, camera, battle-end checks, and HUD refresh were all coordinated from rendered-frame `_process()`.
- Enemy firing checks ran every rendered frame.
- HUD refresh rebuilt weapon and target UI repeatedly, even though the information only needs low-frequency updates.
- Optional imported models and particles are already disabled in `demo_visible_battle`; fallback visuals are the correct default for gameplay tuning.
- Static environment objects use generated meshes/multimeshes and do not need per-frame scripts.

## Changes Made

- Continuous ship movement now ticks from `_physics_process()` through each ship controller.
- Player flight input is sampled on physics ticks for consistent thrust and rotation.
- AI remains throttled at the existing low frequency.
- Enemy fire checks are throttled instead of running every rendered frame.
- Demo Battle still uses performance mode, fallback ship visuals, reduced starfield count, reduced asteroid count, glow disabled, and no engine particles.
- The HUD remains low-frequency and compact to avoid the previous 1280px overflow problem.
- Battle Mode hides the tactical command grid by default and shows a compact controls/weapon HUD instead.
- New firing, hit, warning, and camera impulse feedback use lightweight mesh/label effects rather than dynamic lights or heavy particles.
- The chase camera uses simple interpolation and target composition; it does not run expensive target searches every frame.

## Current Performance Priority

Keep the standalone Demo Battle focused on:

- 1 player ship
- 2 frigates
- 1 destroyer
- direct flight feel
- readable HUD
- stable target selection
- physical projectile and missile behavior

Avoid adding heavier effects, larger fleets, or imported model visuals until manual flight and combat feel good.
