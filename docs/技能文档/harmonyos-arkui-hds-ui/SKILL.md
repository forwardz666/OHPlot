---
name: harmonyos-arkui-hds-ui
description: HarmonyOS ArkUI and HDS UI implementation guidance for immersive layouts, HdsTabsFloatingStyle, hdsMaterial glass effects, bottom floating tab bars, cards, charts, responsive text, and visual verification. Use when improving HarmonyOS app UI or matching a shared style across ArkTS pages.
---

# HarmonyOS ArkUI HDS UI

## Source Order

Prefer local SDK docs and examples first:

```powershell
rg -n "HdsTabsFloatingStyle|hdsMaterial|Tabs|TabBar|Blur|Material|safeArea|expandSafeArea" "C:\Program Files\Huawei\DevEco Studio\sdk\default"
```

Use web search only when the user allows it or the SDK docs are insufficient. Prefer official Huawei Developer documentation.

## Layout Principles

Build the real app screen, not a landing page. Keep operational screens dense, readable, and stable.

For HarmonyOS app pages:

- use immersive full-page backgrounds instead of white bottom bands
- keep the navigation/tab bar floating above content
- keep the content viewport full height behind a fully floating bar
- add scroll-tail clearance only when the final interactive item must move above the bar
- use cards for repeated items and tools, not nested page sections
- keep text black or intentionally high contrast when the user asks for pure black
- avoid debug text in production cards
- verify landscape and portrait separately

## Floating Tab Bar

When implementing an HDS-style bottom tab:

1. Inspect current tab implementation and page root safe-area behavior.
2. Separate the full-screen background/content and floating bar into independent overlay layers.
3. Keep tab bar width content-aware with max width and horizontal margins.
4. Use transparent/glass material instead of opaque white.
5. Keep selection highlight visually distinct but consistent with the app palette.
6. Do not leave a colored bottom region behind the floating bar.

Use this structure for card- or list-based pages:

```text
Stack
├─ continuous background expanded into the bottom system area
├─ full-height List/Scroll/content viewport extending behind the bar
└─ floating HDS bar overlaid above the bottom safe inset
```

Keep `barOverlap(true)` when it is required for the HDS floating style. A fully floating bar does not own a full-width safe-area band. Content and cards may continue beneath and around the capsule while scrolling; the material itself provides the visual separation.

Do not apply bottom padding plus `.clip(true)` to the entire `TabContent`, List viewport, or page root. That truncates the content at the bar top and creates a persistent full-width empty strip. Instead, if the last item must remain reachable, add end padding inside the scrollable content:

```text
scroll-tail clearance =
  bottom safe inset + bar bottom visual gap + bar height + desired item gap
```

This clearance belongs after the final list/scroll item, not on the viewport itself. Apply a matching bottom margin to floating action buttons that must stay above the bar. A continuous canvas or editor can remain full height with no scroll-tail clearance.

ArkUI placement matters:

- for `List`, use a trailing transparent `ListItem` or content-end spacer; `List.padding({ bottom: ... })` can shrink the inner drawable viewport and still cut cards near the capsule
- for `Scroll`, put the clearance on the child `Column` or final content spacer, not on the `Scroll` viewport

Do not fix this artifact by:

- setting `barOverlap(false)` when that turns the HDS floating capsule into a full-width dock
- padding and clipping the entire `TabContent` to the bar top
- adding a full-width `gradientMask` when the requested design is a fully floating material capsule
- changing `barBottomMargin` without measuring the actual bar and system-indicator bounds

Look for these issues in screenshots:

- extra white/colored bottom strip
- tab bar clipped by gesture/navigation area
- content cut off along a full-width horizontal line at the bar top
- a persistent empty region caused by viewport-level bottom insets
- tab labels too pale
- selected highlight too large or too opaque
- content hidden behind tab bar

## Safe Area Insets

Prefer publishing safe-area values from the window layer in vp:

1. Query both `TYPE_SYSTEM` and `TYPE_NAVIGATION_INDICATOR`.
2. Use the maximum visible bottom inset.
3. Convert px to vp with the window `UIContext`.
4. Store the vp value in `AppStorage`.
5. Refresh it from `avoidAreaChange`.

Anchor only the floating control to this inset. Keep the continuous background immersive. When an existing project publishes px, convert it with `this.getUIContext().px2vp()` before using a `Length`.

## Glass Material

Prefer native HDS/material APIs if available in the project SDK. If the API is unavailable, approximate with:

- translucent background
- blur/material effect supported by ArkUI
- subtle stroke/border
- restrained shadow
- no decorative gradient orbs

Do not hard-code a glass recipe from another project until you inspect its current implementation.

## Responsive Text

Avoid viewport-based font scaling. Use fixed text sizes with responsive containers. For compact controls:

- define stable heights and widths
- use icons where appropriate
- prevent labels from wrapping into adjacent UI
- test the longest Chinese and English labels

## Verification

After UI changes:

```powershell
hdc -t <device> install -r "<hap>"
hdc -t <device> shell "aa start -b <bundle> -m entry -a EntryAbility"
hdc -t <device> shell "snapshot_display -f /data/local/tmp/screen.png"
hdc -t <device> file recv "/data/local/tmp/screen.png" ".\screen.png"
hdc -t <device> shell "uitest dumpLayout /data/local/tmp/layout.json"
hdc -t <device> file recv "/data/local/tmp/layout.json" ".\layout.json"
```

Review screenshots for overlap, clipped text, white bands, and wrong safe-area handling. Review layout JSON for missing labels or hidden controls.

Use a page with contrasting cards or records as the visual benchmark. Same-color empty/content backgrounds can hide an incorrect cutoff. While the list is not at its padded end, a record card should be able to pass visibly beneath the material capsule instead of stopping on a horizontal line at its top.

For a floating bottom bar, record and compare:

- content viewport bottom
- floating bar top and bottom
- navigation-indicator top

For a fully floating bar, require the content viewport to continue below the bar top and normally reach the page/window bottom. Confirm the bar remains narrower than the screen, overlaps the content, and has no opaque full-width mask or reserved safe-area node behind it. Separately verify that the final interactive item can be scrolled above the bar when needed.

## Report

Mention the files changed, the visual issue fixed, and whether the fix was verified on device. If screenshots were captured, provide their local paths.
