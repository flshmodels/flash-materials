# Flash Materials

Change built-in materials across selected parts, with a preview and one undo recording. Custom per-part material variants are skipped unless you explicitly choose to clear them.

## Install

1. Download this repository as a ZIP and extract it. No package installation is needed to use the plugin.
2. In a separate Studio test place, use Explorer's **Insert from File** action to insert `FlashMaterials.rbxmx`.
3. Select the root Script named `FlashMaterials` and choose **Save as Local Plugin**. It contains five child ModuleScripts.
4. Remove the imported root from the place. Open **Flash Materials → Materials** on the Plugins toolbar.

The plugin runs in edit mode. Measuring, previewing and applying are refused during play tests.

Preview makes no edits. Selection or option changes clear it. Apply rechecks the changed targets and records a successful batch as one Studio undo step. Failed writes ask Studio to cancel the recording. The preview shows at most 100 rows, but Apply covers every changed target in the plan; use a smaller selection if you want every row visible.

## Use it

Select parts in Explorer, or select a Model/folder and choose **Include descendants**. Enter an exact material name, choose how to handle variants, preview the proposed changes and apply.

Supported materials: `Plastic`, `SmoothPlastic`, `Wood`, `WoodPlanks`, `Concrete`, `Brick`, `Metal`, `DiamondPlate`, `Glass`, `Neon`, `Marble`, `Fabric`.

- **Skip custom variants** leaves every part with a nonempty MaterialVariant unchanged, even if its base material differs. The preview reports how many were skipped.
- **Clear part variants** sets the chosen base material and clears the part's MaterialVariant string. It does not remove MaterialVariant instances or change MaterialService's global overrides.
- An already-matching part with no per-part variant is a no-op.

## Limits

- Up to 500 selection roots, 5000 discovered objects and 1000 eligible BaseParts. Terrain is excluded. Overlapping roots are deduplicated. Services themselves cannot be selection roots.
- Parts inside any service or WorldModel can be edited; the tool does not require Workspace. A locked eligible part blocks the preview.
- The plan is a snapshot. New descendants and previously skipped targets are not added to an existing preview. Apply rechecks parents, locks, material values and variant strings on changed targets.
- The plugin writes only Material and MaterialVariant. It preserves color, textures, SurfaceAppearance objects, transparency and CustomPhysicalProperties.
- **Changing a material can change default physical behavior** when custom physical properties are not overriding it. This is not a visual-only recolor. Existing textures, SurfaceAppearance or global material overrides may also affect what you see.
- It does not create materials, alter terrain, import textures, change collision settings or make external requests.

## Inputs and outputs

`Rules.plan(rows, options, supported)` takes material/variant records, `{material, variants}` and a supported-material map. It returns changed assignments and a skipped-variant count. `Adapter` reads the selection, captures the original values, validates the preview and writes the two properties. `Transaction` wraps the batch in Studio's recording API; it does not implement a separate undo stack.

See Roblox's [materials guide](https://create.roblox.com/docs/parts/materials) and [BasePart API](https://create.roblox.com/docs/reference/engine/classes/BasePart).

## Development and tests

Source is in `src`. The native dock panel follows Studio's theme. UI and scope helpers are copied into each Flash plugin repository so each installs independently. There are no runtime packages, external assets or background services.

Rebuild with Python 3.11+:

```sh
python build.py
python -m unittest discover -s tests -v
```

Run Luau checks with Lune 0.11.1:

```sh
lune run tests/run
```

GitHub Actions compiles all source files, tests the real rules and adapters with fake Studio objects, compares the plugin XML against its source and checks reproducible builds. Material tests cover variants, stale targets, property preservation and fake undo-recording failures. Lune is installed on the CI runner, not on your computer.

**Live Studio installation, dock-panel behavior and native engine undo have not been verified.** Automated checks do not replace the [Studio checklist](docs/STUDIO-CHECKS.md).

MIT licensed; see [LICENSE](LICENSE).
