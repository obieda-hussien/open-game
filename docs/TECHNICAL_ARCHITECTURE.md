# Technical Architecture

## Engine

Godot 4.7.2 stable, GDScript, Android-first.

Default rendering method: `mobile`, with RenderingDevice fallback to OpenGL enabled for broader device survival. A separate low-end build can later force Compatibility if profiling shows a meaningful win.

## High-level runtime graph

```text
GameRoot
├── WorldEnvironment
├── Sun
├── Player
├── WorldStreamer
├── AmbientPopulation
├── DynamicEventDirector
├── TimeWeatherController
└── UI
    ├── HUD
    └── MobileControls
```

Autoload services:

```text
EventBus
Settings
WorldState
MissionManager
SaveSystem
PerformanceDirector
```

Autoloads contain persistent/services state. World nodes contain scene-local simulation.

## Open-world streaming

`OpenWorldStreamer` maps world position to a 96 m grid.

For every cell inside the active radius:

1. Check for an authored scene at `content/world/cells/cell_X_Y.tscn`.
2. If it exists, request it with `ResourceLoader.load_threaded_request`.
3. Poll threaded status across frames.
4. Instantiate after the resource is ready.
5. If no authored cell exists, generate a cheap procedural test cell.
6. Keep an extra ring of cells as unload hysteresis.
7. Create at most one procedural cell per frame.

This avoids a giant synchronous level load and gives content production a stable contract: authored cells can progressively replace the procedural fallback.

## Simulation tiers

Do not give every visible entity the same simulation.

### Tier 0 — persistent state only

Far away. No scene node required.

Examples: NPC schedule, parked vehicle ownership, shop state.

### Tier 1 — proxy

Visible-ish or relevant but not interactive.

Current `AmbientPopulation` demonstrates this with MultiMesh vehicles and pedestrians. No individual physics bodies or scripts.

### Tier 2 — active

Near the player.

Full animation, navigation and lightweight behavior.

### Tier 3 — interactive/hero

Mission NPCs, active player vehicles, combat or repair targets.

Full physics/IK/voice/detail only while needed.

Promotion/demotion between tiers is a future production system, but the repository is already structured around this model.

## Mission graph

`data/missions/prologue.json` defines mission stages.

Stages may:

- wait for a world action (`complete_on`);
- set world flags;
- advance to another stage;
- present choices;
- change reputation/cash;
- complete.

`InteractionPoint` is the first gameplay source of world actions. Future sources can include vehicle state, timers, dialogue, inventory, area triggers and AI.

## Dynamic events

`DynamicEventDirector` reads `data/events/world_events.json`.

Eligibility can use chapter, reputation, time windows, cooldowns and story flags. Events are intentionally content data, not `if` chains inside unrelated gameplay scripts.

Next step: create an EventInstance system that can spawn actors/props in an available streamed cell and persist unresolved events in `WorldState`.

## Persistence

`WorldState` is the canonical serializable world layer. `SaveSystem` writes it with mission state to an atomic temporary file before renaming into the save slot.

Future save schema versions should migrate forward rather than silently discarding fields.

## Settings and performance

`Settings` is persisted independently from game saves.

`PerformanceDirector` tracks an exponential moving average of frame time. With dynamic resolution enabled:

- sustained misses lower `Viewport.scaling_3d_scale`;
- sustained headroom raises it;
- user min/max limits are respected;
- world streaming and population systems can ask for a quality multiplier.

This is deliberately feedback-based. Device names are unreliable predictors; actual frame time is more useful.

## Content boundaries

Gameplay code should not depend on final art.

A mission references stable semantic IDs, not a specific mesh filename. World cells expose interaction IDs. This allows art and level design to iterate without rewriting story logic.

## Future modules

Recommended next modules:

```text
src/vehicles/
  vehicle_controller.gd
  vehicle_damage.gd
  vehicle_simulation_lod.gd

src/garage/
  repair_job.gd
  garage_inventory.gd
  garage_economy.gd

src/npc/
  npc_state.gd
  schedule_system.gd
  npc_promoter.gd
  dialogue_controller.gd

src/navigation/
  world_route_service.gd

src/inventory/
  item_definition.gd
  inventory.gd
```
