# Studio checks

Status: not yet run live. Record the Studio version, date and outcome when testing.

1. Install `FlashMaterials.rbxmx` in a separate test place. Check toolbar toggling, a narrow dock and light/dark themes.
2. Try selection-only and expanded scopes, including overlapping roots and removed objects. Verify counts against Explorer.
3. Try the valid and invalid examples in the README. Rejected operations must not edit the place.
4. Start a play test; the plugin must refuse its work. Stop the test and verify it remains usable.
5. Disable/reload the plugin and check for leftover UI, connections or errors.

6. Compare Skip custom variants and Clear part variants on parts with and without existing variants. Check global overrides and SurfaceAppearance separately.
7. Preview, then alter a target material, variant, parent or lock. Apply should refuse the stale plan. Change an option or selection; another preview must be required.
8. Apply a small batch, Undo once, then Redo once. Check both Material and MaterialVariant as well as untouched color, textures and custom physical properties. A no-op batch must not create an undo entry.
