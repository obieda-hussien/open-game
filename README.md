# LAST SHIFT

**LAST SHIFT** is a mobile-first 3D open-world story and responsibility game built with **Godot 4.7.2**.

The long-term target is a dense, believable urban district that feels alive: work, money, vehicle ownership, garage management, relationships, day/night schedules, dynamic incidents, branching missions, traffic, pedestrians and a crime/mystery story — without treating a phone like a desktop GPU.

> Status: **production foundation / vertical slice**. The repository already boots into a playable streamed 3D district, has a third-person controller, touch input, mission branching, world events, time/weather, population proxies, save/load, dynamic resolution and a full settings surface. Art direction and production assets are the next layer.

## Design pillars

- **Dense open world, not empty square kilometers.** The city is split into streamed cells. Nearby authored content loads asynchronously; distant cells unload with hysteresis.
- **Responsibility is gameplay.** Cash, reputation, jobs, garage upkeep, vehicle costs, deadlines and relationships are persistent world state.
- **Events continue around the player.** Dynamic incidents are data-driven and gated by time, chapter, reputation and story flags.
- **Choices have state.** Missions are a graph, not a list of waypoint scripts.
- **Mobile performance is a feature.** Runtime frame-time feedback can lower 3D render scale and world/population budgets before the device becomes unplayable.
- **Player-controlled quality.** FPS cap, VSync, render scale, dynamic resolution, MSAA, FXAA, world distance, NPC/traffic/vegetation density, effects, audio buses and gameplay/accessibility controls are exposed.

## Current playable slice

1. Start outside the garage at night.
2. Open the garage.
3. Read the job board.
4. Pick up the first package.
5. Inspect the suspicious damaged car.
6. Make the first branching story decision.

The origin district is procedural placeholder geometry so gameplay and performance architecture can be tested before expensive final assets are locked in.

## Controls

Desktop development controls:

| Action | Input |
| --- | --- |
| Move | WASD |
| Look | Mouse |
| Sprint | Shift |
| Jump | Space |
| Interact | E |
| Settings / Pause | Esc |

Android automatically enables a left virtual stick, right-side camera drag, USE and sprint touch zones.

## Architecture

```text
scenes/
  main.tscn
  player/player.tscn

src/
  autoload/
    event_bus.gd
    game_settings.gd
    world_state.gd
    mission_manager.gd
    save_system.gd
    performance_director.gd
  core/
    game_bootstrap.gd
  player/
    third_person_controller.gd
    mobile_controls.gd
  world/
    open_world_streamer.gd
    world_cell.gd
    interaction_point.gd
    ambient_population.gd
    dynamic_event_director.gd
    time_weather_controller.gd
  ui/
    game_hud.gd
    settings_menu.gd

data/
  missions/prologue.json
  events/world_events.json

docs/
  GAME_DESIGN.md
  TECHNICAL_ARCHITECTURE.md
  MOBILE_PERFORMANCE.md
  ASSET_PIPELINE.md
```

## Mobile rendering strategy

The project defaults to Godot's **Mobile renderer** with RenderingDevice-to-OpenGL fallback enabled. The gameplay renderer does not depend on Forward+-only features such as SDFGI, SSR, volumetric fog, TAA or FSR2.

Instead the production path is designed around:

- baked lightmaps for static districts;
- limited shadow-casting key lights;
- reflection probes;
- fog and glow that are supported by the Mobile renderer;
- texture atlases and GPU-friendly compressed textures;
- LOD/HLOD and impostors for distant city blocks;
- occlusion culling;
- MultiMesh for cheap traffic/crowd proxies;
- async cell loading;
- object pooling for transient gameplay;
- frame-time-driven resolution and population pressure;
- authored per-device presets plus user overrides.

Read [`docs/MOBILE_PERFORMANCE.md`](docs/MOBILE_PERFORMANCE.md) before adding heavy world content.

## Running locally

Install Godot **4.7.2 stable**, open this directory and run `scenes/main.tscn`.

For command-line verification:

```bash
python3 tools/validate_content.py
godot --headless --path . --editor --quit-after 8
godot --headless --path . --script res://tests/test_runner.gd
```

## Android CI

Two CI implementations are included:

- `.github/workflows/android-ci.yml`
- `.circleci/config.yml`

Both validate data, parse/import the Godot project, run headless smoke tests and export a debug `arm64-v8a` APK. A signed release APK is generated only when release-signing secrets/variables are configured.

Optional Telegram delivery uses:

```text
TELEGRAM_BOT_TOKEN
TELEGRAM_CHAT_ID
```

Release signing uses:

```text
ANDROID_RELEASE_KEYSTORE_BASE64
ANDROID_RELEASE_KEYSTORE_USER
ANDROID_RELEASE_KEYSTORE_PASSWORD
```

No credentials should be committed to this repository.

## Generated 3D concept

The first garage/street 3D blockout was prototyped in Higgsfield 3D Jutsu:

`https://higgsfield.ai/3d-jutsu/9b6f02da-3540-47f2-af47-def24406ad2d`

It is a visual prototype, not a final optimized game asset. Production assets should pass the pipeline documented in `docs/ASSET_PIPELINE.md` before entering the Android build.

## Next production milestones

- replace placeholder city cells with a hand-authored garage district;
- add proper PBR materials, lightmaps, LOD chains and collision proxies;
- implement drivable vehicles with low-cost near/far simulation tiers;
- add inventory, garage repair loops, economy and shop systems;
- add NPC schedule/relationship state and dialogue;
- promote dynamic events from HUD notifications into physical world scenarios;
- add map/phone UI, quest journal and navigation;
- profile on low-, mid- and high-tier Android devices before increasing visual density.

The goal is not “GTA on a phone”. The goal is a **smaller but denser simulation whose detail, consequences and atmosphere make it feel larger than it is**.
