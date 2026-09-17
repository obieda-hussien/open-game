# LAST SHIFT

**LAST SHIFT** is an Android-first third-person open-world story / life-simulation game prototype built with **Godot 4.7.2**. The project targets dense, believable districts, story decisions, jobs, vehicles and responsibility systems while keeping rendering and simulation budgets suitable for phones.

> Status: **production vertical slice**, not a finished game. The current branch now uses synchronized Higgsfield/Blender GLB assets for its origin district, player character and driveable sedan instead of relying only on primitive placeholder geometry.

## Current vertical slice

The current branch includes a playable gameplay foundation rather than a static visual mockup:

- landscape-first mobile controls with left joystick, right-side camera look and contextual actions
- third-person movement with acceleration, friction, coyote time, buffered jumping, crouch and sprint
- production character GLB with rig/locomotion animation plus a procedural fallback
- camera-facing, line-of-sight interaction selection instead of proximity-only prompts
- streamed 96 m world cells with a production origin district and procedural fallback cells
- Higgsfield/Blender origin GLB containing the garage district, apartment block, corner store, roads, vehicles and street props
- a physical garage door with collision that opens through gameplay state rather than a glowing world marker
- a driveable sedan using `VehicleBody3D` and four `VehicleWheel3D` suspension contacts
- speed-dependent steering, service braking, handbrake, lightweight traction control / ABS approximation, aerodynamic/rolling drag and fuel use
- mobile driving controls plus compact speed/fuel telemetry
- branching mission graph, dynamic events, save/load, time/day and lightweight weather
- frame-time-driven dynamic 3D resolution and distance/density budgets for Android
- Battery / Balanced / High / Ultra / Custom graphics presets and separate Master/Music/SFX/Voice/Ambience controls

## Playable prologue

The first story path is still deliberately small while the systems are being hardened:

1. Start outside the garage at night.
2. Physically open the garage door.
3. Look at and use the job board.
4. Collect the waiting delivery package.
5. Inspect the suspicious damaged car.
6. Make the first branching story choice.
7. Find the separate sedan and drive it using the vehicle physics controller.

## Production 3D asset pipeline

Large generated GLBs are intentionally not committed into git history. `data/assets/remote_assets.json` pins each production model by URL, exact byte count, SHA-256 and Higgsfield provenance. `tools/sync_3d_assets.py` downloads assets atomically and refuses mismatched or partial files.

Both GitHub Actions and CircleCI synchronize and verify the assets **before** Godot imports the project, so exported APKs contain the production city, character and sedan while the git repository remains lightweight.

Current pinned assets:

- `last_shift_city_block_v2.glb` — production origin district
- `last_shift_mechanic_v2.glb` — rigged mechanic character
- `last_shift_driveable_sedan_v1.glb` — sedan visual model prepared for vehicle physics

## Mobile performance strategy

The game does not try to render or simulate the entire open world at maximum fidelity. Production rules include:

- stream world cells around the player and unload distant cells;
- keep expensive authored 3D assets in important near cells and retain procedural/low-cost fallbacks;
- use simplified collision proxies instead of full rendered-mesh collision over city blocks;
- progressively reduce geometry, animation and simulation cost with distance;
- use MultiMesh/proxies for background population and repeated vegetation;
- keep expensive real-time shadows local and quality-tier dependent;
- dynamically reduce internal 3D resolution when measured frame time exceeds budget;
- expose visual quality, population density, draw distance, anti-aliasing, audio and FPS limits to the player.

See `docs/MOBILE_PERFORMANCE.md` and `docs/ASSET_PIPELINE.md` for the detailed budgets and authoring rules.

## Architecture

```text
assets/external/                 # synchronized GLBs, ignored by git

data/assets/
  remote_assets.json             # URL + size + SHA-256 + provenance pins

scenes/
  main.tscn
  player/player.tscn
  vehicles/driveable_sedan.tscn

src/
  autoload/
  core/
  player/
    mobile_controls.gd
    production_avatar.gd
    third_person_controller.gd
  vehicles/
    driveable_vehicle.gd
  world/
    open_world_streamer.gd
    production_origin_runtime.gd
    world_cell.gd
  ui/
    game_hud.gd
    settings_menu.gd

tools/
  sync_3d_assets.py
  validate_content.py
```

## Android CI

`.github/workflows/android-ci.yml` and `.circleci/config.yml` both synchronize and cryptographically verify production GLBs before Godot import. The pipeline then validates data, imports/parses the project headlessly, rejects script/resource parser errors, runs smoke tests, configures Android SDK/JDK/signing and exports a debug APK. Signed release export is optional when release secrets are configured.

The smoke suite covers landscape orientation, player scene loading, production asset presence, production runtime scripts and the four-wheel physical sedan scene.

Optional Telegram delivery still uses repository/workspace secrets only; credentials are never stored in source.

## Local setup

After cloning, synchronize the generated assets before opening the project:

```bash
python3 tools/sync_3d_assets.py --required
python3 tools/validate_content.py
godot --headless --path . --editor --quit-after 12
godot --headless --path . --script res://tests/test_runner.gd
```

Then open the project with Godot **4.7.2 stable** and run `scenes/main.tscn`.

## Development status / next production passes

The vertical slice is now asset-backed and physically interactive, but it is not yet a PUBG-scale finished game. The next passes focus on higher-fidelity PBR environment and character assets, a larger animation set with AnimationTree blending, vehicle damage/repair systems, traffic and NPC schedules, enterable interiors, deeper jobs/economy, dialogue, physical world events and more authored streamed districts.

The target remains a **smaller but much denser open world** whose simulation, consequences and atmosphere make it feel larger without treating an Android phone like a desktop GPU.
