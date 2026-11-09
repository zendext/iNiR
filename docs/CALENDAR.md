# Calendar

Show events from Google Calendar, Outlook, iCloud, Nextcloud and other calendars that offer an ICS (iCal) link next to your own events. You paste the link. No login is needed.

## Add a calendar

- **Material**: **Settings › Services › Calendar Sync**. Turn on **Enable external calendar sync**, press **Add Calendar Source**, then enter a name, the ICS URL and a colour.
- **Waffle**: **Waffle Settings › General › Calendar**, same steps.

Each calendar syncs on its own. Add each one separately to give it its own colour.

## Finding the link

Most calendar services offer an iCal or ICS address for each calendar, usually in its sharing or export settings. Use the private address if the service offers both. A `webcal://` link works once you change it to `https://`.

## Refresh and display

- **Refresh interval (minutes)** is 15 by default, from 5 to 120 in steps of 5.
- The calendar also refreshes when you add or re-enable a source, when the network comes back, and when the shell starts. There is no refresh button. A source that fails shows its error.
- **Show upcoming events below calendar** is on, and **Upcoming days to show** is 3 (1 to 14).

Material: the grid shows up to three coloured dots per day. Click a day to see its events, grouped as All Day, Morning, Afternoon and Evening. The Events tab lists the next 30 days.

Waffle: click a day in the notification centre to see its events under the grid.

External events show their calendar's name and colour. You cannot edit them in iNiR.

## Chinese calendar (local customization)

The local fork shares `CalendarCn` across the ii calendar and iRiS calendar
card and classic desktop widget. It uses the existing yearly holiday cache, including
off-days and make-up workdays, together with the local lunar-date converter.

Run `scripts/calendar/update_holiday_cn.sh YEAR` to refresh a year's holiday data.
The `calendar.china` settings control the display:

- `enable`: enable Chinese-calendar information (off by default).
- `showLunar`: show lunar-date labels.
- `showWorkStatus`: show `休` for an off-day and `班` for a make-up workday.

In iRiS, open the Today panel with `inir iris today open` and expand its month
heading. Add a direct calendar-card entry with `inir iris barPiece calendar on`.
The month grid shows holiday names in preference to lunar labels; selecting a
date shows both labels and its work status below the grid. The collapsed week
strip also shows Chinese date information.

The large desktop widget shows labels below each date. Small and medium grids
keep the dates compact with work-status markers; hovering a date shows its
lunar label, holiday name and work status. The medium widget also shows today's
Chinese date beside its month grid. Missing yearly holiday data leaves holiday
names and work-status markers empty while lunar conversion remains available.

---

## Privacy

The link stays in your settings on your machine. Requests go straight to the calendar service, with no server in between. Events are cached on disk, so they show after a restart. Treat a secret link like a password, because anyone with it can read the calendar.

## Troubleshooting

- **No events**: check the error under the source. Usual causes are a wrong or expired link, no internet, or a link that needs a login.
- **Remove a source** to drop its events from the calendar. **Undo** on the notice that follows brings it back.
