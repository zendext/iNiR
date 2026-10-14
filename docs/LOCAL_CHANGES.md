# Local changes

This page tracks the maintained customizations in `zendext/iNiR` relative to
`snowarch/iNiR`. It is a review checklist for upstream synchronization, not a
replacement for the upstream documentation or the Git diff.

The integrated upstream baseline is v2.33.0 at
`48cdcecb0f6089cfbb7019054602eab28e154b3b`, synchronized on 2026-10-14 from local
`644487cf77503bd2e74b213242bc428b10d0703c`. See [AGENTS.md](../AGENTS.md) for the
recovery reference, validation boundaries, and multi-monitor safety rules.

The synchronization merge is `7bcf54f4`. Distribution, focused regression and
QML checks passed, followed by a stable two-output live smoke test. The detailed
runtime scope and inherited documentation/catalog audit failures are recorded in
AGENTS.md; hotplug and suspend/resume remain unverified.

## Retained customizations

These entries describe the differences retained against v2.33.0. UI-specific
customizations apply only to the listed surfaces; sharing a service does not
automatically add equivalent controls to each family's separate components.

| Area | Local behavior | Main implementation |
|---|---|---|
| Weather | Use Open-Meteo as the primary forecast provider and for configured-location geocoding. | [Weather.qml](../services/Weather.qml) |
| Temperature | Select maximum, CPU, or GPU temperature for the bar indicator. | [ResourceUsage.qml](../services/ResourceUsage.qml), [Resources.qml](../modules/bar/Resources.qml) |
| Battery protection | Support start/stop charge thresholds where the hardware allows them, with registered quick toggles and desktop visibility guards. | [Battery.qml](../services/Battery.qml), [AndroidQuickPanel.qml](../modules/sidebarRight/quickToggles/AndroidQuickPanel.qml), [ClassicQuickPanel.qml](../modules/sidebarRight/quickToggles/ClassicQuickPanel.qml) |
| Chinese calendar | Add lunar-date, Chinese holiday and off-day/make-up-workday information to the ii calendar/week strip and iRiS calendar card/widget. | [CalendarCn.qml](../services/CalendarCn.qml), [LunarUtils.qml](../modules/common/functions/LunarUtils.qml), [WeekStrip.qml](../modules/sidebarLeft/widgets/WeekStrip.qml), [IrisSidebarSection.qml](../modules/iris/sidebar/IrisSidebarSection.qml), [IrisCalendarFace.qml](../modules/iris/widgets/IrisCalendarFace.qml) |
| Compact screens | Hide the standard bar's media, weather, clock/date, utility-button, and battery modules at logical output widths of 1800 or less, leaving the tray policy unchanged. Wider outputs retain these modules according to their settings. | [BarBreakpoints.js](../modules/bar/BarBreakpoints.js), [BarContent.qml](../modules/bar/BarContent.qml) |
| Keyboard volume | Change the default output volume in one-percent steps. | [Audio.qml](../services/Audio.qml) |
| Wallpaper selection | Prefer the focused monitor in wallpaper settings and display folder names in selection controls. | [BackgroundConfig.qml](../modules/settings/BackgroundConfig.qml), [QuickWallpaperItem.qml](../modules/settings/QuickWallpaperItem.qml) |
| File manager | Use Dolphin in shipped defaults, shortcuts, and fallback launch actions. | [config.json](../defaults/config.json), [70-binds.kdl](../defaults/niri/config.d/70-binds.kdl), [QuickLaunch.qml](../modules/sidebarLeft/widgets/QuickLaunch.qml) |
| Screen routing | Retain screen-local popup bindings and the standard bar's screen-local sidebar-button selected state. Some overlays retain an explicit primary-screen binding with the historical crash boundary in AGENTS.md. | [ContextMenu.qml](../modules/common/widgets/ContextMenu.qml), [BarContent.qml](../modules/bar/BarContent.qml), [AGENTS.md](../AGENTS.md) |
| Playback modes | Add repeat and shuffle controls to the ii bar popup/left sidebar and iRiS full media card, Island media page, control center, and medium/large desktop music widgets. | [PlayerControl.qml](../modules/mediaControls/PlayerControl.qml), [MediaPlayerWidget.qml](../modules/sidebarLeft/widgets/MediaPlayerWidget.qml), [IrisPlaybackModeButton.qml](../modules/iris/components/IrisPlaybackModeButton.qml) |

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

## iRiS adoption notes

The following adoption choices apply as of 2026-10-14.

- Battery protection: use iRiS Settings > Battery > Charge limit instead of
  adding a separate iRiS quick toggle. Its enable switch and stop threshold use
  the existing `battery.chargeLimit` settings and shared
  [Battery service](../services/Battery.qml), which must remain. The local start
  threshold is retained in configuration; iRiS currently has no start-threshold
  field. The existing ii quick toggles are unchanged.
- Chinese calendar: the iRiS
  [sidebar/calendar card](../modules/iris/sidebar/IrisSidebarSection.qml) and
  [calendar widget face](../modules/iris/widgets/IrisCalendarFace.qml) now reuse
  [CalendarCn](../services/CalendarCn.qml), the existing yearly holiday data,
  and `calendar.china` settings. The card, its collapsed week strip, and large
  desktop month grid show Chinese date labels and `休` / `班` markers. Small
  and medium grids show the markers, with full date information on hover;
  the medium widget also shows today's Chinese date. See
  [Calendar Integration](CALENDAR.md#chinese-calendar-local-customization).
- Playback modes: iRiS now includes the existing shuffle/repeat customization
  through a shared [mode button](../modules/iris/components/IrisPlaybackModeButton.qml).
  It uses normal transport-icon colors when active, 45% opacity when inactive,
  and the same background in both states, without hover text. The full media card,
  Island media page, control center, and medium/large desktop music widgets bind
  controls to their displayed player. Compact cards and small widgets are unchanged.

Run `node scripts/test-iris-calendar.mjs` for lunar, holiday, make-up-workday,
deferred-data and display-setting regression checks. This executes the shared
QML presentation functions and actual lunar conversion; it does not render QML.

## Playback modes

The behavior and visual states are described in [Audio and Media](AUDIO_MEDIA.md#media-players).
The ii scope is the bar media popup and the left sidebar's general media widget.
The ii right sidebar and dedicated YT Music player remain separate components.
The iRiS scope is the full [media card](../modules/iris/components/IrisMediaCard.qml),
[Island media page](../modules/iris/bar/island/IslandMediaPage.qml),
[control center](../modules/iris/control/IrisControlGrid.qml), and medium/large
[desktop music widgets](../modules/iris/widgets/IrisNowPlayingFace.qml).

Controls use each card's MPRIS player and check `canControl` plus the corresponding
capability flag. No Spotify credentials, Web API adapter, polling process, or new
runtime dependency is required. Spotify Smart Shuffle has no separate state in
this interface and is not offered as an additional mode.

Run the focused regression check from the repository root:

```bash
node scripts/test-media-playback-modes.mjs
node scripts/test-iris-playback-modes.mjs
```

The check executes the actual QML button bindings and click handlers against a
simulated player contract. It covers repeat order, shuffle toggling, icon
brightness, externally changed state, player switching, unsupported capabilities,
and disconnects for both surfaces. It also executes the controller's time and
seek methods with remembered browser-track length and a position correction,
checking that the popup labels and slider share that timeline and that seeking
clears the correction. It does not instantiate QML controls or test the D-Bus
transport, so QML parsing and live UI checks remain necessary.
The iRiS check covers the four displayed-player bindings, shared mode behavior,
foreground/background states, absent hover text, and disabled controls while editing.
Icon sizing is checked visually: the Material Symbols mode glyphs are taller
than skip/rewind at equal font sizes, so they use separate optical size adjustments,
with a final 1px increase for shuffle and 2px for repeat.

On 2026-09-14, both changed QML files passed Qt 6 `qmlformat` parsing. Both surfaces
were exercised against Spotify: clicking the repeat cycle and shuffle toggle
changed Spotify's reported state. Externally changed mode state was also checked
in the media popup. The final brightness and layout were inspected in both
surfaces after restarting iNiR, with no related QML errors or automatic service
restarts. Playback modes were restored after the tests.

On 2026-10-14, the five iRiS QML files passed Qt 6 parsing, and an isolated preview
with a temporary MPRIS player verified all four surfaces, repeat/shuffle writes,
external state updates, capability loss, and matching transport-icon colors.
One preview shutdown crashed in Quickshell's `ColorQuantizer` destructor
(`cancelAsync()` / `QThreadPool::waitForDone()`); the crash report was preserved.
The main shell remained active with no service restarts. These checks do not
establish that Quickshell hot reload or shutdown is crash-free.

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
