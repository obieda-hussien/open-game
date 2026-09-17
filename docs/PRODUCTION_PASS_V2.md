# Production Pass V2 — Asset-backed Android Vertical Slice

This pass replaces the most visible prototype shortcuts with systems that can survive further production work.

## Runtime changes

### Production origin cell

Cell `(0, 0)` is special only in content, not in the streaming architecture. `OpenWorldStreamer` requests the pinned production district GLB asynchronously. When it arrives, `ProductionOriginRuntime` supplies cheap collision proxies, physical garage logic, authored interactions, local night lighting and the driveable sedan. If the asset is unavailable, the streamer keeps the existing procedural cell fallback rather than hard-crashing.

### Interaction selection

Interactions are no longer selected only because the player is nearby. The third-person controller ranks enabled interaction points by camera-facing score, distance and line-of-sight. The HUD shows only a compact reticle and contextual prompt. This removes the previous large cyan ground marker from the production origin.

### Player locomotion

The player controller now includes acceleration/deceleration separation, coyote time and jump buffering. The production avatar loader instantiates the pinned GLB and uses its `LocomotionWalk` animation, while the old procedural avatar is kept strictly as a graceful fallback.

### Vehicle physics

The sedan uses one `VehicleBody3D` with four `VehicleWheel3D` suspension contacts. Its first-pass handling model includes:

- low-speed / high-speed steering interpolation;
- per-wheel suspension stiffness, travel, damping and grip;
- engine-force falloff near top speed;
- service brake and rear handbrake;
- lightweight traction-control torque reduction based on skid information;
- lightweight ABS pressure reduction under severe skid;
- quadratic aerodynamic drag plus rolling resistance;
- persistent fuel capacity and consumption state inside the vehicle runtime.

This is deliberately a mobile-budget vehicle model. A future custom tire model can replace `VehicleBody3D` if profiling or handling requirements exceed the built-in solver's limitations.

## Asset integrity

`data/assets/remote_assets.json` pins every generated production GLB using:

- permanent distribution URL;
- exact expected byte size;
- SHA-256 digest;
- Higgsfield project ID and revision provenance.

`tools/sync_3d_assets.py` downloads to a temporary file, verifies size and SHA-256, then atomically renames into `assets/external`. A failed or changed download cannot silently enter an APK.

## Android budget rules

Production visual geometry is never automatically promoted to full collision. The origin runtime creates primitive collision proxies around the garage and major buildings. This keeps broadphase/contact cost stable even when rendered assets become more detailed.

The existing frame-time performance director, cell streaming, dynamic resolution, density settings and graphics presets remain active around the authored origin.

## Next hard problems

1. Replace the current mechanic visual with a higher-fidelity skinned PBR character while preserving the same runtime contract.
2. Author idle/walk/run/crouch/jump/turn/enter-vehicle clips and move locomotion to an `AnimationTree` state machine.
3. Split the sedan visual into wheel/body semantic meshes or use a higher-quality vehicle asset so rendered wheel motion follows the physical wheels.
4. Add vehicle damage, repairable components, tire state and garage tools.
5. Add enterable interiors and more authored streamed districts using the same verified-asset pipeline.
6. Replace notification-only dynamic events with physical actors, traffic incidents and NPC state transitions.
7. Profile the production origin on low/mid/high Android tiers before increasing shadow count or texture resolution.
