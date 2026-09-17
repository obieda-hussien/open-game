# Asset Pipeline

## Goal

Final assets can look realistic while remaining predictable on Android. Every asset should have an explicit runtime budget before it enters a world cell.

## Source

Concept/rapid blockout sources may include Higgsfield, Blender and hand-authored references.

The first visual blockout for the garage district lives at:

`https://higgsfield.ai/3d-jutsu/9b6f02da-3540-47f2-af47-def24406ad2d`

Do not drop a generated GLB directly into production and assume it is mobile-ready.

## Required production pass

1. **Topology cleanup**
   - remove hidden/internal geometry;
   - merge static pieces that always render together;
   - preserve separate objects only when culling/interaction needs them.

2. **Scale/origin**
   - meters;
   - sensible pivots;
   - Z-forward/Y-up as expected by the export workflow.

3. **UVs/material consolidation**
   - trim sheets;
   - shared atlases;
   - pack ORM channels when useful;
   - remove duplicate materials.

4. **LOD**
   - LOD0/1/2 plus HLOD/impostor for major buildings.

5. **Collision**
   - hand-authored primitive/convex collision;
   - no detailed render mesh as moving collision.

6. **Lighting**
   - lightmap UV where static;
   - emissive surfaces for decorative light sources;
   - only intentional realtime shadow lights.

7. **Export**
   - glTF/GLB;
   - apply transforms;
   - validate names;
   - no embedded junk cameras/lights unless explicitly wanted.

8. **Godot import**
   - verify compression/mipmaps;
   - verify LOD;
   - verify materials;
   - verify mobile renderer appearance.

9. **Device profile**
   - place asset in a worst-case street;
   - measure draw calls, triangles, memory and frame time.

## Suggested naming

```text
env_garage_main_lod0
env_garage_main_lod1
env_garage_main_lod2
env_garage_main_hlod
prop_toolbox_a
veh_sedan_story_a
npc_owner_body
```

Stable semantic IDs should remain separate from display names.

## Cell packaging

Authored world scenes go in:

```text
content/world/cells/cell_X_Y.tscn
```

The streamer automatically prefers that scene over the procedural fallback for the matching coordinate.

This lets the game remain playable throughout production: one cell at a time can become final-quality.
