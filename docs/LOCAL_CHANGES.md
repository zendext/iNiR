# Local changes

This page tracks the maintained customizations in `zendext/iNiR` relative to
`snowarch/iNiR`. It is a review checklist for upstream synchronization, not a
replacement for the upstream documentation or the Git diff.

The integrated upstream baseline is v2.33.0 at
`48cdcecb0f6089cfbb7019054602eab28e154b3b`, synchronized on 2026-10-14 from local
`644487cf77503bd2e74b213242bc428b10d0703c`. See [AGENTS.md](../AGENTS.md) for the
recovery reference, validation boundaries, and multi-monitor safety rules.

## Retained customizations

These entries describe the differences retained against v2.33.0. UI-specific
customizations apply to the named Material or Waffle surfaces; selecting iRiS
does not automatically add equivalent controls to its separate components.

| Area | Local behavior | Main implementation |
|---|---|---|
| Weather | Use Open-Meteo as the primary forecast provider and for configured-location geocoding. | [Weather.qml](../services/Weather.qml) |
| Temperature | Select maximum, CPU, or GPU temperature for the bar indicator. | [ResourceUsage.qml](../services/ResourceUsage.qml), [Resources.qml](../modules/bar/Resources.qml) |
| Battery protection | Support start/stop charge thresholds where the hardware allows them, with registered quick toggles and desktop visibility guards. | [Battery.qml](../services/Battery.qml), [AndroidQuickPanel.qml](../modules/sidebarRight/quickToggles/AndroidQuickPanel.qml), [ClassicQuickPanel.qml](../modules/sidebarRight/quickToggles/ClassicQuickPanel.qml) |
| Chinese calendar | Add lunar-date and Chinese holiday information to the calendar and week strip. | [CalendarCn.qml](../services/CalendarCn.qml), [LunarUtils.qml](../modules/common/functions/LunarUtils.qml), [WeekStrip.qml](../modules/sidebarLeft/widgets/WeekStrip.qml) |
| Compact screens | Hide the standard bar's media, weather, clock/date, utility-button, and battery modules at logical output widths of 1800 or less, leaving the tray policy unchanged. Wider outputs retain these modules according to their settings. | [BarBreakpoints.js](../modules/bar/BarBreakpoints.js), [BarContent.qml](../modules/bar/BarContent.qml) |
| Keyboard volume | Change the default output volume in one-percent steps. | [Audio.qml](../services/Audio.qml) |
| Wallpaper selection | Prefer the focused monitor in wallpaper settings and display folder names in selection controls. | [BackgroundConfig.qml](../modules/settings/BackgroundConfig.qml), [QuickWallpaperItem.qml](../modules/settings/QuickWallpaperItem.qml) |
| File manager | Use Dolphin in shipped defaults, shortcuts, and fallback launch actions. | [config.json](../defaults/config.json), [70-binds.kdl](../defaults/niri/config.d/70-binds.kdl), [QuickLaunch.qml](../modules/sidebarLeft/widgets/QuickLaunch.qml) |
| Screen routing | Retain screen-local popup bindings and the standard bar's screen-local sidebar-button selected state. Some overlays retain an explicit primary-screen binding with the historical crash boundary in AGENTS.md. | [ContextMenu.qml](../modules/common/widgets/ContextMenu.qml), [BarContent.qml](../modules/bar/BarContent.qml), [AGENTS.md](../AGENTS.md) |
| Playback modes | Add repeat and shuffle controls to the bar popup and left sidebar media widget. | [PlayerControl.qml](../modules/mediaControls/PlayerControl.qml), [MediaPlayerWidget.qml](../modules/sidebarLeft/widgets/MediaPlayerWidget.qml) |

## Customizations covered by upstream

- `04a08098` removes the shadowing `screen` declaration from Orbit corner windows,
  matching local `4c90b7cd`. This is now upstream behavior rather than a fork diff.
- `fbdbf4b5` routes all four standard-bar sidebar click handlers to their output,
  covering the routing part of local `644487cf`. The right button's selected-state
  binding still needs the local output argument. The focused regression checks
  both click routing and selected state, including swapped sidebar roles.

The local media-popup layout uses upstream `PlayerProgress`, `positionOf()`,
`lengthOf()` and `seek()` while keeping the compact time row and playback modes.
The Chinese calendar retains its lunar/work-status labels alongside upstream's
date font rules. Neither feature is replaced by the upstream styling changes.

## Playback modes

The behavior and visual states are described in [Audio and Media](AUDIO_MEDIA.md#media-players).
The scope is the bar media popup and the left sidebar's general media widget.
The existing right sidebar and the dedicated YT Music player are separate
components and were not changed in this work.

Controls use each card's MPRIS player and check `canControl` plus the corresponding
capability flag. No Spotify credentials, Web API adapter, polling process, or new
runtime dependency is required. Spotify Smart Shuffle has no separate state in
this interface and is not offered as an additional mode.

Run the focused regression check from the repository root:

```bash
node scripts/test-media-playback-modes.mjs
```

The check executes the actual QML button bindings and click handlers against a
simulated player contract. It covers repeat order, shuffle toggling, icon
brightness, externally changed state, player switching, unsupported capabilities,
and disconnects for both surfaces. It also executes the controller's time and
seek methods with remembered browser-track length and a position correction,
checking that the popup labels and slider share that timeline and that seeking
clears the correction. It does not instantiate QML controls or test the D-Bus
transport, so QML parsing and live UI checks remain necessary.

On 2026-09-14, both changed QML files passed Qt 6 `qmlformat` parsing. Both surfaces
were exercised against Spotify: clicking the repeat cycle and shuffle toggle
changed Spotify's reported state. Externally changed mode state was also checked
in the media popup. The final brightness and layout were inspected in both
surfaces after restarting iNiR, with no related QML errors or automatic service
restarts. Playback modes were restored after the tests.

Other players, every theme/font scale, and screen hotplug were not exhaustively
tested. Future live checks should verify that the intended panel is open before
clicking, wait for Spotify's asynchronous state updates, and restore the initial
playback modes afterward.

## Reviewing an upstream update

Use the last integrated baseline to inspect the retained changes:

```bash
git diff 48cdcecb0f6089cfbb7019054602eab28e154b3b..HEAD --stat
git diff 48cdcecb0f6089cfbb7019054602eab28e154b3b..HEAD -- modules/mediaControls modules/sidebarLeft/widgets/MediaPlayerWidget.qml
```

Update this inventory and the relevant behavior document when a customization is
changed, removed, or replaced by an upstream implementation. Follow the existing
AGENTS.md rules for performing upstream merges away from the live checkout.
