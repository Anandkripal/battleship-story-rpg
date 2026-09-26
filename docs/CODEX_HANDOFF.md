# Codex Handoff

## System Ownership Map

- `scripts/combat/battle_controller.gd`: Demo Battle scene orchestration, Battle Mode input, camera behavior, HUD, target selection, weapon dispatch, and lightweight combat feedback.
- `scripts/combat/ship_controller.gd`: Shared ship movement state, autopilot movement, Battle/Exploration control modes, weapon arc checks, hardpoints, damage, and ship VFX.
- `scripts/combat/combat_ai.gd`: Enemy combat movement intentions such as frigate attack passes and destroyer range control.
- `scripts/combat/projectile_3d.gd` and `scripts/combat/missile_3d.gd`: Physical projectile/missile movement and lightweight impact visuals.
- `data/battle_3d_configs.json`: Demo Battle composition, performance mode, starting positions, and selected control mode.
- `data/ship_definitions.json`: Ship handling, battle steering, assist tuning, and combat stat data.
- `data/weapon_definitions.json`: Weapon range, cooldown, arc, aim assist, and presentation tuning.

## Control Modes

Ships share the same movement/inertia state, but player input is now separated by control mode:

- `battle`: simplified battleship combat controls. W/S thrust and brake, A/D turn, Q/E down/up movement, mouse camera revolve, 1/2/3 active weapon selection, LMB fires active weapon, RMB fires secondary, Space missile, Tab target, Shift boost, R recenter. The control legend stays visible in Demo Battle.
- `exploration`: free-flight foundation. W/S forward and reverse, A/D strafe, Space/Ctrl vertical, Q/E roll, Shift boost, mouse camera.
- `autopilot`: existing command-driven movement for tactical/fleet-style orders.

Demo Battle uses `battle` mode by default. Tactical command buttons are still built for future/autopilot use but hidden in Battle Mode.

## Performance State

Demo Battle still runs in performance mode with fallback visuals, reduced environment counts, no optional imported models, and no engine particles. Keep this default until combat feel is stable.
