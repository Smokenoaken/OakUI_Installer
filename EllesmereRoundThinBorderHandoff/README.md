# Ellesmere Round Thin Border Handoff

This bundle contains the minimum pieces for adding the OakUI-tested round thin border style directly to EllesmereUI.

## Files

- `Media/Borders/RoundThinBorder.png` - the visible 9-slice border texture.
- `Media/Borders/RoundThinMask.png` - the matching 9-slice mask texture used to clip square status bar corners.
- `RoundThinBorderReference.lua` - reference implementation adapted for base EllesmereUI paths and naming.

## Suggested Integration

1. Copy `Media/Borders/RoundThinBorder.png` and `Media/Borders/RoundThinMask.png` into EllesmereUI, for example:
   - `Interface\AddOns\EllesmereUI\Media\Borders\RoundThinBorder.png`
   - `Interface\AddOns\EllesmereUI\Media\Borders\RoundThinMask.png`

2. Merge `RoundThinBorderReference.lua` into EllesmereUI's media/border module, or load it after `EllesmereUI.ApplyBorderStyle` is defined.

3. Register the style in LibSharedMedia as a border/nineslice/ninesliceborder. The reference file does this in `RegisterRoundThinBorderStyle()`.

4. Use the style key `Round Thin` or `sm:Round Thin` in existing border texture settings.

## Important Behavior

The visible border alone is not enough. The matching mask must be applied to the status bar textures, backgrounds, power bars, absorbs, and related child bars. Without that mask, the square health/power textures poke through the rounded corners.

The reference module includes:

- `ApplyRoundThinBorderFrame(borderFrame, ...)`
- `HideRoundThinBorderFrame(borderFrame)`
- `ApplyRoundThinMaskOnly(maskParent, targets, anchorFrame)`
- `RemoveRoundThinMaskOnly(maskParent)`
- A hook into `EllesmereUI.ApplyBorderStyle`
- A hook into `EllesmereUI.SetBorderStyleColor`

OakUI tested this against Ellesmere resource bars, unit frames, party/raid frames, boss frames, cast bars, tracking bars, damage meters, DBM/BigWigs bars, and Blizzi interrupt bars. Base EllesmereUI probably only needs the core renderer and mask collection; the third-party hooks are installer-specific and intentionally not included here.
