# Harmony

A responsive music-ministry application for parent accounts, child approval,
season registration, reservations, and administrator coordination.

## Implementation scope

Implemented workflows include parent registration and email verification,
child profiles and approval, published-season browsing, spot reservations and
cancellation, administrator review queues, an event roster with CSV export,
administrator access grants/revocations, and the reusable song library.

The full requirements remain in [copilot-instructions.md](copilot-instructions.md).
Important remaining production work is listed under “Known limitations” below.

### Season-specific song roles

When adding songs through **Add event** or **Add song from the library**, select
**Opening Song**, **Closing Song**, **Special Song**, or **Offertory Song**.
Existing songs default to **Not specified**, which also clears a selected role.
Song cards display the selected role without a dropdown. Administrators can
change or clear the role using the card's Edit setup dialog; the dropdown is
available only while adding or editing a song.

Migration `0009` stores the role on the season/song pair. It applies to every
appearance of that song in the same season; the library and other seasons are
unchanged. Parent browsing lists each song in a separate full-width row with
alternating light and gradient-tinted backgrounds. Parent browsing and the
season preview show the role. Roles do not
change event ordering, extra-song eligibility, capacity, or reservations.
Copying events uses the destination season's existing role (or Not specified);
it does not copy the source season's role.

### Child-profile welcome emails

The first successful child-profile submission sends the welcome email based on
section 5 of [notification-implementation.md](notification-implementation.md).
Additional children receive a short acknowledgement; edits and account creation
do not send a welcome. Existing families are not emailed retroactively.
The messages explain pending approval, separate performance reservations, ministry
leadership, and the three-day practice-recording expectation. They do not promise
automatic one-week reminders, whose delivery process is not implemented yet.

Migration `0008` creates `child_profile_notifications`. A per-parent lock serializes
first-child detection, and the delivery record commits with the child and instruments.
Delivery then uses the existing sender and the current verified parent email.
Configure `APP_URL` for the dashboard link and the existing `SMTP_*` settings for
production. In development, messages are logged as `Preview`, not marked as sent.

Administrators can view delivery status and explicitly retry Pending/Failed records
on **Email parents**. Sent/Preview records are not resent. A mail failure does not
roll back registration. Failed SMTP attempts may have ambiguous outcomes (for
example, a connection dropping after acceptance); inspect the provider before retrying.
An interrupted process leaves `Sending` work for operator investigation rather than
automatically risking a duplicate. SMTP acceptance is not proof of inbox delivery.
No automatic retry worker is started by this feature.

Every new child profile also queues a separate administrator notification to
`kidsmusic-coord@tamilgospelchurch.org`, including additional children in an existing
family. It includes the child's name, parent name/email, and an administrator
dashboard link for approval. Edits and unsuccessful submissions do not notify the
administrator, and existing children are not notified retroactively.
Migration `0010` adds separate Parent/Administrator delivery records per child.
Both records commit with the registration and are delivered independently; an
administrator email failure does not suppress the parent's email or remove the
saved profile. **Email parents** identifies these records as **Administrator
registration** and supports the same explicit retry/status workflow. Development
still logs previews only; production requires the configured SMTP service.

### First-publication parent notifications

Saving a season as **Published** for the first time opens a notification scheduling
step. Choose a future date and time in the season's timezone, then select **Publish
and schedule**. Cancel saves nothing; **Back to season** returns to the unsaved
form. Creating a season directly as Published follows the same flow.
The notification time defaults to the registration opening date and time currently
entered in the form. Administrators can change it; if the default is already past,
they must choose a future time before publishing.

The season and schedule are committed in one transaction. Later edits or
republishing do not reschedule the announcement. Existing non-Draft seasons are
marked as historical publications by migration `0007`; no retroactive announcement
is scheduled. A Draft that had been published before this feature cannot be
identified from its current status alone and will be treated as a first publication.

The following `seasons` columns are the integration contract for a **separate
notification sender** (no worker or email delivery is started by this feature):

- `first_published_at`: UTC first-publication time; for historical seasons, the
  pre-migration `updated_at` is a historical marker, not a reconstructed publication time.
- `registration_notification_at`: chosen send instant, stored as UTC `datetime(3)`.
- `registration_notification_timezone`: IANA timezone at scheduling, retained even
  if the season's timezone changes later.
- `registration_notification_sent_at`: nullable UTC completion time; only the
  separate sender may set it after successful delivery.

With its MySQL session timezone set to UTC, the sender can discover due work using:

```sql
SELECT id, name, registration_notification_at, registration_notification_timezone
FROM seasons
WHERE status = 'Published'
  AND registration_notification_sent_at IS NULL
  AND registration_notification_at <= UTC_TIMESTAMP(3)
ORDER BY registration_notification_at, id;
```

This query discovers work; it does **not** claim it or guarantee exactly-once
delivery. Before enabling a sender, implement exclusive job claiming, durable
per-recipient delivery tracking/idempotency and retries, recheck Published status,
and select verified parent accounts. Send each parent a separate message. Mark
completion only after all intended deliveries succeed; never set completion just
because a job was fetched. Delivery is paused while the season is not Published;
republishing resumes its original unsent schedule, even if it is now overdue.
Deleting a season without reservation history also deletes its schedule.

## Stack

- Next.js App Router, React, and strict TypeScript.
- Tailwind CSS and Lucide icons.
- MySQL 8.0.16+ (8.4 LTS recommended) with Drizzle and the mysql2 driver.
- Better Auth for email/password authentication, email verification, and password recovery.
- Private filesystem PDF storage with retained file versions.
- Vitest for automated backend tests.

Local development connects to MySQL on `127.0.0.1:3306` as `appuser`, using the
`harmony` database. There is no embedded database fallback.
For deployment, use MySQL and a persistent private storage volume. Object
storage is a future storage adapter, not a feature of this increment.

## Shared visual theme

All pages use Plus Jakarta Sans for welcoming body text and bold headings, with a
periwinkle-to-deep-blue gradient (`#919BFF` to `#133A94`), glossy light panels,
navy text, and semantic coral/teal accents. Navigation and hero panels
use a lightened brand gradient with dark labels, not solid blue backgrounds.
Primary buttons use the same gradient with a dark overlay and white labels for
readable contrast at both endpoints; secondary controls use light periwinkle/blue tints.
Theme colors, buttons, focus states, and loading
styles are defined in `src/app/globals.css`; shared illustrations in
`src/components/ui/Motifs.tsx` reuse the supplied `public/music_icon.jpg` for
branding, music icons, and decorative artwork; browser and install icons use
the same image. The legacy
`forest`, `parchment`, and `sage` utility names map to the refreshed palette.
Use these shared tokens instead of hardcoded colors when adding pages.
In administrator Seasons and events, its preview, and parent Seasons and
reservations, each season shows one event at a time.
Use Previous/Next or the Jump to event selector to navigate chronologically
without scrolling through every week. Selection is retained during refreshes;
if the selected event is deleted, the first remaining event is shown. Cards
alternate light gradient surfaces and periwinkle/blue gradient tints to make weekly boundaries clearer.
Parent filters apply before event navigation, so the selector and event count
include only matching events. Your reservations remain visible separately.

## Local setup

For step-by-step installation, proxy configuration, validation, production
builds, and startup, see [BUILD.md](BUILD.md).

To recover records from the preserved local PostgreSQL/PGlite directory, follow
the legacy-import rehearsal and apply instructions in [BUILD.md](BUILD.md).
The recovery tool preserves the original database and uploads, verifies imported
values, and stops on conflicts rather than overwriting MySQL records.

Use Node.js 24 LTS (Node.js 16 cannot run this application).

```powershell
npm install
Copy-Item .env.example .env.local
npm run db:session
# In the temporary shell opened after secure credential entry:
npm run dev
```

Open `http://127.0.0.1:3000`. Configure the application origin to match the address
you use in the browser; do not mix `localhost` and `127.0.0.1` for authentication.
The development server binds to loopback rather than exposing the setup flow to
your network.

Follow the first-administrator setup instructions on the sign-in screen and in
the server terminal. Setup requires a server-side setup token; it is not public
registration. Verify the administrator email before signing in. Development-only
email links are written to the server terminal when SMTP is not configured.
Production must use real email delivery.

Parents can register at `/register`, verify their email, and sign in to `/parent`.
In Family Workspace, **Add child** above the Children list (or in the empty
state) clears the inline editor and scrolls to the focused name field. It remains
available when the family already has profiles. **Edit profile** focuses the same
editor with the selected child's details; new profiles use **Submit for approval**.
The **Upcoming reservations** heading opens Your reservations on the Seasons and
reservations page. Each upcoming reservation card links directly to its matching
reservation details, scrolling to and focusing the card after the data loads.
Add children there and wait for administrator approval before booking. The
administrator dashboard contains pending child and reservation-review queues.
The reservation roster and CSV export are available from the admin navigation.

Never commit local configuration, setup tokens, passwords, sessions, uploaded
music, or database contents.

## Administrator guide

### Families and reservations

Parents register with a verified email address, then create child profiles using
birth month/year only. Each child is reviewed by an administrator. Changes to
eligibility details return the profile to pending approval and flag existing
confirmed reservations for coordinator review; they are not silently cancelled.

Only approved children and their listed instruments can be booked. A child may
hold one confirmed regular-song spot per season, plus one spot per song marked
"Allow as extra song for this season" by an administrator in the event-song list.
This setting applies to every appearance of the song in that season only; it is
off by default and is never copied to another season or stored in the library.
Extra songs can be booked before or after a regular song, including at the same
event. Database indexes prevent duplicate active spots and duplicate bookings
within each allowance. Disabling extra registration is blocked if confirmed
bookings would exceed the regular-song limit; published-season changes require
impact confirmation. Overlapping event times across seasons are checked in the
booking transaction. Cancellation is available until the season's configured
cutoff; after that, the parent must contact a coordinator.

The parent season view groups performances by church-local date and includes all
songs, their library and event notes, links, and event-selected PDF versions with
preview and download actions. Each requested instrument lists its individual
Available and Reserved spots. Instrument and occupied-spot details are read-only;
other families' child names are not disclosed. Parents can register an eligible
child for a remaining spot and manage their own reservations separately.

The administrator reservation review queue can keep a flagged reservation or
cancel it with an explanation. The roster supports season, date, song, instrument,
child, parent, and status filters. CSV export is administrator-only and escapes
spreadsheet formula prefixes.

Administrator access can be granted only to an existing verified account. The
last administrator cannot be revoked. Role grants and revocations are audited.

### Song library

1. Add a song with its title, optional composer and notes, and any HTTP/HTTPS links.
2. Attach multiple PDF sheets, up to 15 MB each, and give each a meaningful label.
   Set the instrument and arrangement when appropriate. Remove unwanted files
   before saving.
3. Confirm that you have permission to distribute the uploaded material.
4. Reuse that song and its sheets in any number of events without uploading again.
5. Use song details to inspect usage, preview or download current and retained
   sheet versions, add sheets, edit metadata, replace a PDF, archive content, or
   delete unused content.

Saved song links are visible in song details and included in library search.
Expand a sheet's usage list to see the events and seasons using that PDF before
editing or archiving it. Unused songs and sheets require deletion confirmation;
referenced content cannot be permanently deleted.

Library edits are shared. Event notes, instrument requirements, capacity, song
order, and sheet selections belong only to that event. Removing an event
assignment does not delete the library song or its files.

Referenced library content cannot be permanently deleted. Archive it to prevent
new selections while preserving existing event references. Replacing a sheet
retains previous PDF versions; event selections identify the version to use.
Review affected events before confirming shared changes.

### Seasons and events

Create a season with a custom date range, church timezone, registration window,
location, and instructions. Overlapping seasons are supported. Add individual
events or generate weekly events, then adjust exceptional dates individually.

Select songs and sheets from the library for each event, add event-specific notes,
and configure positive whole-number capacities for the required instruments.
Piano and Keyboard are separate instruments. Copy an existing event setup when
appropriate; review the target event afterward.

When adding an individual event, choose its date and times, then select one or
more songs in the same dialog. Each selection immediately shows the library
notes, song links, and PDF preview links. Choose the sheets families will receive,
check the requested instrument types, and enter a capacity for each checked
instrument. Use Add song for additional entries. Saving creates the event and
all song configurations together; an invalid selection saves none of them.
Existing events retain their separate song editing and ordering controls.

The song-links database migration runs automatically at application startup.
Back up existing data before applying migrations; an already damaged local
database must be restored or replaced separately.

Seasons & events shows only Draft and Published seasons by default. Use the
status checkboxes to include other statuses, **Show all** to see every season,
or **Reset filters** to restore Draft and Published. Filters stay selected during
workspace refreshes and reset on a fresh page visit.

Each event also shows its confirmed reservations: the child's full name, song,
instrument, and spot number. Empty events show "No confirmed reservations yet."
Cancelled bookings are excluded. This list is administrator-only; parents still
cannot see another family's children's names. Refresh the workspace to load
the latest bookings.

Preview the season before publication. Published changes require explicit impact
confirmation. Use **Delete season** to permanently remove a season and all its
events after confirmation, regardless of status, only if it has no reservation
history. Cancelled reservations also prevent deletion; use **Edit** to set the
season status to **Archived** instead. Shared library songs, music sheets, and
files are preserved. Individual event deletion remains limited to drafts without
reservation history. The activity view records administrator changes.

## Validation

```powershell
npm run typecheck
npm test
npm run build
```

## Production and data operations

Use a managed MySQL service for multi-instance deployments. Store private PDFs on a durable
shared volume accessible to all instances, never in the public web directory or
an ephemeral deployment filesystem.

Configure a strong authentication secret, the correct HTTPS application origin,
SMTP delivery, and a protected setup token. Do not enable development email
logging in production. The bootstrap token should be removed after setup.

```powershell
npm run build
npm start
```

The start script binds to loopback. Put it behind a TLS reverse proxy on the same
host, or explicitly configure the hosting platform's required bind address.

Back up MySQL using its supported backup tooling (for example, `mysqldump` with
`--single-transaction` for InnoDB), and back up the private upload volume at the
same recovery point. Restore into a separate environment and test
song downloads and event sheet selections before switching production traffic.
Include retained file versions in backups; do not remove old files manually.

Before public use, establish church-approved retention and copyright policies,
configure monitoring and backup schedules, and review the application in its
actual hosting environment. UI accessibility and browser testing do not replace a
formal WCAG audit.

## Known limitations

- Administrator grants currently apply to existing verified users; invitation
   acceptance for new accounts is not implemented.
- Administrator roster support includes filtering, printing, and CSV export;
   reassignment and bulk operations are not implemented.
- Email verification, reset, booking, and review messages are sent inline. There
   is no durable delivery queue, retry UI, or configurable reminder scheduler.
- A church-approved retention duration and account/child deletion process have
   not been selected. Archived child records and reservation history are retained;
   establish and document the church policy before production use.
- Reservation cancellation is implemented, but automated schedule-change impact
   notifications and coordinator-initiated reassignment workflows remain incomplete.
- PWA standalone metadata is present. Offline reservation actions are not queued
   or represented as successful; the app requires a server response to confirm a
   booking.
