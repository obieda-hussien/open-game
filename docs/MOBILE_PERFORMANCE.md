# Mobile Performance Strategy

The visual target is realism through **composition, materials, lighting and density**, not through blindly enabling desktop-only effects.

## Frame budgets

| Target | Total frame budget |
| --- | ---: |
| 30 FPS | 33.3 ms |
| 45 FPS | 22.2 ms |
| 60 FPS | 16.7 ms |
| 90 FPS | 11.1 ms |

Every feature spends from the same budget: rendering, physics, scripts, animation, audio, streaming and the OS.

## Rendering tiers

### Battery

- 30 FPS;
- ~0.52–0.78 dynamic 3D scale;
- no MSAA;
- short cell radius;
- low proxy population;
- no decorative shadow lights.

### Balanced

- target 45 FPS;
- ~0.60–0.95 dynamic scale;
- 2x MSAA + FXAA;
- medium streamed radius;
- moderate crowd/traffic.

### High

- target 60 FPS;
- ~0.70–1.00 dynamic scale;
- 2x MSAA + FXAA;
- larger world radius;
- higher density.

### Ultra

- opt-in;
- full 3D scale;
- 4x MSAA;
- maximum content density;
- still avoids features that are structurally bad for mobile.

Users may override individual settings and create a custom profile.

## What gives “realistic” visuals cheaply

Prioritize:

1. good physically based material values;
2. strong art direction and believable scale;
3. baked lighting and lightmaps for static architecture;
4. reflection probes placed by district;
5. decals/grime variation where supported;
6. high-quality hero assets only where the camera approaches;
7. good sky/color grading;
8. believable audio;
9. smooth animation.

Do **not** assume more realtime lights = more realism.

## Open-world memory

Never keep the entire city resident.

Each cell owns:

- meshes;
- collision;
- local props;
- local audio;
- navigation fragments;
- event anchors;
- reflection/lightmap data.

Unload with a hysteresis ring so crossing a cell boundary does not thrash resources.

Large texture sets should be district-scoped so leaving a district can actually free VRAM.

## LOD / HLOD

Production assets should ship at least:

```text
LOD0  0–18 m     hero geometry
LOD1  18–45 m    ~45–60% triangles
LOD2  45–90 m    ~15–25% triangles
HLOD  90+ m      merged block/impostor
```

Exact values depend on screen size and silhouette.

For a building block, HLOD is more important than having an individual LOD node for every chair/window.

## Occlusion

Dense streets are good for occlusion. Buildings should act as visual blockers.

Use occlusion culling in authored cells and avoid tiny occluders. The goal is to skip whole courtyards/streets/building interiors when blocked.

## Lighting

Mobile renderer does not provide the Forward+-only GI/SSR/volumetric stack used by many desktop screenshots.

Production plan:

- one shadow-casting directional sun/moon;
- baked lightmaps for static bounce/detail;
- limited realtime local lights;
- most decorative lights emissive-only;
- realtime shadows only for gameplay-important nearby lights;
- reflection probes for glossy vehicles/interiors.

## Textures

Suggested Android budget:

- hero characters/vehicles: selective 2K;
- common architecture: 1K atlases;
- small props: 512–1K;
- trim sheets for repeating architecture;
- ORM packed channels where practical;
- mipmaps on 3D textures;
- GPU compressed texture formats through Godot imports.

Avoid ten unique 4K materials on a building that occupies 120 pixels.

## Population

`AmbientPopulation` intentionally demonstrates proxy simulation using MultiMesh. Production should promote only nearby relevant entities to full nodes.

Example target caps on a mid-range phone:

```text
Full NPCs with animation/navigation: 8–14
Cheap nearby NPCs:                 12–24
Distant crowd proxies:             30–70
Full physics traffic:              4–8
Proxy traffic:                     12–30
```

These are starting budgets, not promises. Profile real devices.

## Physics

- simplified collision meshes;
- no mesh collision for moving vehicles;
- sleep inactive rigid bodies;
- reduce physics tick only if gameplay remains stable;
- pool frequently spawned bodies;
- distant traffic has no full rigid-body vehicle physics.

## Scripts

Avoid:

- scanning the entire scene tree every frame;
- allocating large arrays in `_process`;
- per-NPC expensive raycasts at the same frame;
- synchronously loading scenes while driving.

Spread AI updates across frames and use distance-aware tick rates.

The prototype interaction scan is intentionally small. Replace it with a spatial interaction registry when authored-world interactable count grows.

## Thermal behavior

Phones can hold 60 FPS for a minute and throttle later. Long profiling sessions matter.

Dynamic resolution should be the first emergency lever because it is reversible and visually smoother than deleting gameplay. If frame pressure persists, then reduce proxy density and optional effects.

## Profiling acceptance gate

Before increasing visual density, test at least:

- low-end Android;
- mainstream/mid-range Android;
- high-end Android.

Capture:

- median FPS;
- 1% low frame time;
- memory;
- GPU frame time;
- CPU frame time;
- thermals after 15–20 minutes;
- cell transition stutter;
- save/load stalls.

Content that looks better but creates repeated >50 ms spikes during driving does not pass.
