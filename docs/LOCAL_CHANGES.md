# Local changes

This fork tracks iNiR v3.0.1 (`4c7cab0b`). The pre-upgrade recovery point is
`140c4719`. The [v2.33.0 inventory](https://github.com/zendext/iNiR/blob/140c4719/docs/LOCAL_CHANGES.md)
records the previous runtime checks and the original implementation paths.

| Area | Behavior in this fork |
| --- | --- |
| Weather | The shared service uses Open-Meteo for forecasts and city search. Nominatim resolves coordinates to a place name, and wttr.in serves as the forecast fallback. |
| Battery | The shared battery service applies start and stop thresholds on supported hardware. Material carries Android and Classic quick toggles. iRiS uses its upstream charge-limit settings, and the start threshold comes from `battery.chargeLimit.startThreshold`. |
| Chinese calendar | Material's calendar and week strip and the iRiS Today card and classic calendar widget use the shared lunar calendar and yearly holiday cache. See [Calendar](CALENDAR.md#chinese-calendar-local-customization). |
| Compact screens | The standard Material bar hides media, weather, clock, utilities, and battery on outputs at most 1800 logical pixels wide. The tray keeps its existing policy. |
| Volume keys | The default sink changes in one-percent steps. |
| Wallpaper settings | Material and Waffle settings prefer the focused output, then the configured primary output. The Material quick picker displays directory names. |
| File manager | New defaults, the installer preference, and file shortcuts prefer Dolphin. The configuration migration preserves existing pinned apps. |
| Screen routing | Material's right sidebar button reflects its own output. The shared context menu and Material media/tray backdrops follow the source window. The Material settings overlay and screen keyboard take the configured primary screen when their windows are created. |
| Playback modes | The shared media popup, Material's left media widget, and the iRiS control center and classic medium/large music widgets expose repeat and shuffle when the displayed player supports them. The popup retains upstream's shared timeline and symmetric time labels. See [Audio and media](AUDIO_MEDIA.md#media-players). |

Upstream provides the maximum CPU/GPU temperature in the bar, per-output Orbit
corners and sidebar clicks, and repeat/shuffle on the iRiS media card and Island
page. The fork uses those implementations.

## Build and install the downstream families

iNiR 3.x loads Material, iRiS, and Waffle from the Hub. The three
[patches](../local-families) apply to the Hub revision in
[`upstream-revision`](../local-families/upstream-revision). The catalogue uses
versions 2.35.1006 (Material), 2.33.1062 (iRiS), and 2.34.1008 (Waffle).

In a repo-linked checkout, with the upstream `inir` CLI and its Hub commands available:

```bash
./scripts/build-local-families.sh
INIR_RUNTIME_DIR="$PWD" INIR_HUB_FROM_SHELL=1 ./scripts/inir hub install ii iris waffle
```

Pass the absolute path of the CLI binary as the build script's first argument
when it lives outside the normal iNiR data directory. The builder fetches the
pinned Hub commit, applies the patches, and uses `inir hub build`. The launcher
and setup load the resulting catalogue first and the official catalogue second.
Bump both manifests for a family when its package changes. Stop the running shell
before switching the source checkout or its linked families. The launcher
resolves a linked user configuration before starting QML so atomic writes
update the profile and preserve its link.

## Regression checks

Run these against a checkout with the downstream families installed:

```bash
node scripts/test-bar-sidebar-routing.mjs
node scripts/test-iris-calendar.mjs
node scripts/test-iris-playback-modes.mjs
node scripts/test-media-playback-modes.mjs
QT_QPA_PLATFORM=offscreen qmltestrunner -input tests/tst_bar_breakpoints.qml
```

Keep the [multi-monitor safety rules](../AGENTS.md) when changing native window
routing. Source-level routing checks cover two outputs and swapped sidebar roles.
The nested Niri smoke test covers startup and representative panel IPC for the
three families on one output. Primary-monitor changes, physical hotplug,
suspend/resume, and physical charge-threshold writes need separate verification.
