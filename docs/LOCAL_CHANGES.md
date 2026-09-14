# Local changes

This page tracks the maintained customizations in `zendext/iNiR` relative to
`snowarch/iNiR`. It is a review checklist for upstream synchronization, not a
replacement for the upstream documentation or the Git diff.

The last integrated upstream baseline is `dcba34ee124acb5a191c88b2e1952006fa5afb2f`,
merged on 2026-09-10 as `d7d611a6`. See [AGENTS.md](../AGENTS.md) for the merge
baseline, superseded primary-monitor workarounds, and multi-monitor safety rules.

## Retained customizations

The earlier entries below were checked against the current code and baseline
diff. Their historical runtime checks remain documented in AGENTS.md; they were
not all retested as part of the media-controls change.

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
| Screen routing | Retain screen-local popup bindings and bind Orbit hot corners to the native per-output window screen. | [ContextMenu.qml](../modules/common/widgets/ContextMenu.qml), [ScreenCorners.qml](../modules/screenCorners/ScreenCorners.qml), [AGENTS.md](../AGENTS.md) |
| Playback modes | Add repeat and shuffle controls to the bar popup and left sidebar media widget. | [PlayerControl.qml](../modules/mediaControls/PlayerControl.qml), [MediaPlayerWidget.qml](../modules/sidebarLeft/widgets/MediaPlayerWidget.qml) |

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
and disconnects for both surfaces. It does not instantiate QML controls or test
the D-Bus transport, so QML parsing and live UI checks remain necessary.

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
git diff dcba34ee124acb5a191c88b2e1952006fa5afb2f..HEAD --stat
git diff dcba34ee124acb5a191c88b2e1952006fa5afb2f..HEAD -- modules/mediaControls modules/sidebarLeft/widgets/MediaPlayerWidget.qml
```

Update this inventory and the relevant behavior document when a customization is
changed, removed, or replaced by an upstream implementation. Follow the existing
AGENTS.md rules for performing upstream merges away from the live checkout.
