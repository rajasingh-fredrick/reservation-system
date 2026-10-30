## 1. Project Overview

Act as an experienced full-stack software engineer, product designer, and accessibility specialist.

Design and develop a secure, production-ready registration and reservation application for a church’s children’s music ministry.

Parents must be able to:
- Create and verify their accounts.
- Add and manage multiple children.
- Submit each child for administrator approval.
- Browse open music ministry seasons and weekly performances.
- Reserve available instrument spots for approved children.
- Download music sheets.
- Review and cancel reservations according to church policies.

Administrators must be able to:
- Approve children.
- Create seasons with custom date ranges, including overlapping seasons.
- Schedule weekly performances and songs.
- Maintain a reusable song library independently of seasons and events.
- Add songs with multiple music sheets, update or replace sheets, and delete unused library entries.
- Configure instrument requirements and musician capacity.
- Manage reservations and view participant rosters.
- Grant or revoke administrator access.

Create a polished, welcoming, visually rich interface that is easy for parents and church coordinators to use.

## 2. Supported Platforms

Build a responsive web application supporting:
- Modern desktop browsers.
- iPhone and iPad Safari.
- Android and other modern mobile browsers.

Provide PWA installation support where supported, including an appropriate app icon and standalone layout.

Do not assume a PWA is a native iOS application or that it will be distributed through the App Store.

Reservation creation, cancellation, and administrative changes require an internet connection. Never display an offline reservation as successfully confirmed.

## 3. User Roles and Authorization

Support these roles:

### Parent
Can manage only their own profile, children, and reservations.

### Administrator
Can manage seasons, performances, songs, instrument requirements, music sheets, child approvals, and registrations.

Administrators can also:
- Invite an existing or new user to become an administrator.
- Grant administrator access only after the user has verified their email.
- Revoke administrator privileges.
- Compose and immediately send an email notification to all verified parents or a selected group of one or more verified parents.
- Use parent features if they also register their own children.

Requirements:
- Show the administration navigation link only to administrators.
- Enforce authorization on the server for every protected operation. Hiding a link is not sufficient security.
- Prevent removal or demotion of the last active administrator.
- Establish the first administrator through a secure setup process.
- Record administrator role changes in an audit log.

## 4. Parent Account Management

### Account creation
Collect:
- Parent or guardian name.
- Email address, used as the username.
- Password.
- Optional phone number.
- Acknowledgment that the user is authorized to register the child.
- Acceptance of the privacy notice and applicable church policies.

### Email verification
- Require email verification before accessing authenticated parent or administrator features.
- Use single-use, expiring verification links.
- Allow users to resend verification emails with rate limiting.
- Handle expired or invalid links clearly.
- Prevent duplicate accounts using the same normalized email address.

### Sign-in and recovery
Provide:
- Sign in.
- Sign out.
- Forgot Password.
- Forgot Username / Sign-in Help.

Because the username is the email address, explain this clearly in the sign-in help flow. Do not reveal whether a particular email address has an account.

Password reset links must be single-use and expire. Use secure password storage and appropriate protection against repeated sign-in and recovery attempts.

Require verification of a new email address before replacing the existing verified address.

## 5. Child Profiles and Approval

Allow multiple children under one parent account.

For each child, collect:

| Field | Requirement |
|---|---|
| Full name | Required |
| Birth month and year | Required; do not collect the day |
| Instruments played | Required; allow multiple selections |
| Years of experience | Record separately for each selected instrument; allow beginners and fractional years |
| Additional information | Optional multiline text with a reasonable length limit |

Supported instruments:
- Violin
- Piano
- Keyboard
- Drums
- Guitar
- Bass Guitar
- Saxophone

Treat Piano and Keyboard as separate instrument types.

Validate that birth month/year is not in the future and experience is nonnegative and reasonable for the child’s age.

### Approval workflow
Each child has one of these statuses:
- Pending approval.
- Approved.
- Rejected.
- Archived.

Rules:
- New child profiles begin as pending.
- Only approved children can reserve spots.
- Administrators can approve or reject profiles and provide a parent-visible reason.
- Notify the parent of approval or rejection.
- Parents can edit their own children’s profiles.
- Changes to name, birth month/year, instruments, or experience require reapproval.
- Such edits must not silently cancel existing reservations; flag affected reservations for administrator review.
- Archiving a child must preserve historical records and clearly explain any effect on future reservations.

Do not allow one parent to access another family’s private child profile.

## 6. Scheduling and Reservation Structure

Use this hierarchy:

**Season → Performance/Event → Event Song → Instrument Requirement → Individual Reservation Spot**

Maintain a separate reusable catalog:

**Song Library → Song → One or More Music Sheets**

An event song references a library song and the music sheets selected for that event; it is not a separate copy of the library song or its uploaded files.

Definitions:
- A **season** is a named program with a custom date range.
- A **performance/event** is a dated occurrence within a season, usually weekly.
- Each event can contain one or more songs selected from the library.
- Each event song specifies the instruments needed and the number of musicians required for each instrument for that event.
- Each musician position is a separately bookable spot.
- Library songs and sheets exist independently of seasons and events and remain available for reuse after a season ends.

Example:

> Fall Music Ministry → November 8 service → Song A → Violin → 2 spots

Two children may reserve the two violin spots. A third child must not be allowed to reserve another violin spot for that song.

Do not assume all seasons have the same duration or that overlapping season dates are invalid.

## 7. Season and Event Management

Administrators can create and edit seasons with:
- Name.
- Description.
- Start and end dates.
- Registration opening and closing timestamps.
- Church timezone.
- Optional location.
- Parent instructions.
- Cancellation cutoff.
- Status: Draft, Published, Registration Closed, Completed, or Archived.

Support:
- Multiple seasons with overlapping dates.
- Weekly event generation within a season’s date range.
- Editing individual event dates and times.
- Adding exceptional dates and skipping weeks.
- Previewing a season before publication.
- Copying an event’s song and instrument setup to another date.
- Browsing and selecting existing library songs and sheets while creating or editing a season and its events.
- Adding a new song with multiple sheets to the library from the season/event setup flow, then selecting it without uploading the files again.

### Season status filters
- On Seasons & events, show only Draft and Published seasons by default.
- Provide labeled status checkboxes for Draft, Published, Registration Closed, Completed, and Archived, allowing multiple statuses to be selected.
- Provide Show all and Reset filters actions; resetting restores Draft and Published.
- Show the number of matching seasons and distinguish an empty database from no matching filter results.
- Filter only the administrator's displayed list, preserving existing date ordering and all season records. Retain the selected filters during data refreshes; a fresh page visit uses the default selection.

### Season deletion
- Provide a clearly labeled Delete season action for administrators, regardless of season status.
- Require confirmation explaining that the season, its events, song assignments, instrument requirements, and sheet selections will be permanently removed.
- Allow deletion only when the season has no reservation history, including cancelled and administrator-cancelled reservations. Otherwise reject deletion and direct the administrator to archive the season using its status control.
- Perform the history check, dependent-record deletion, and audit entry in one transaction. Protect against concurrent reservations and preserve all shared library songs, music sheets, and files.
- After successful deletion, refresh the season list. Report refresh failures separately from deletion failures.

### Extra-song registration
- For a song assigned to a season, administrators can enable "Allow as extra song for this season" (off by default).
- The setting belongs to the season and library-song pair, applies to all appearances of that song within that season, and is not part of the main library song details.
- A marked song can be chosen by an eligible child whether or not the child already has a reservation in the season.
- Each child may hold one confirmed reservation per marked extra song per season, in addition to one confirmed regular-song reservation. Extra-song reservations do not consume the regular-song allowance, regardless of booking order.
- Keep approval, instrument eligibility, registration windows, capacity, cancellation, and cross-season time-conflict rules in force. Multiple songs in the same season/event are allowed under these allowances.
- Do not carry the setting into another season when reusing songs or copying event setups. Copies within the same season use that season's existing song setting.
- Show parents which songs allow extra registration. Audit administrator changes, require impact confirmation for published seasons, and reject disabling the option when existing confirmed reservations would exceed the regular-song limit; do not silently cancel reservations.

Validate date ranges and ensure events fall within their season.

### Event creation interface
- Ask for the event date.
- Allow administrators to add more than one song to the same event, selecting each Song Name from the reusable song list.
- Immediately after selecting a song, display its details: music sheets/PDFs, all links, and song notes, alongside any event-specific notes.
- Display all library sheets to administrators so they can choose which sheets parents can access for that event.
- For each event song, provide an Instrument Type control that supports multiple selections and a capacity for each selected instrument.
- Make each requested instrument's available spots separately bookable by parents for their eligible children, subject to the reservation rules in Section 10.

Draft seasons are visible only to administrators.

Store precise timestamps consistently and display dates and times using the church’s configured timezone.

## 8. Songs, Instruments, and Music Sheets

### Reusable song library
Maintain songs and their music sheets as persistent library records, separate from season and event records. The library is shared by administrators and must not be tied to the administrator who uploaded a song.

Administrators can:
- View, search, and browse the library even when no season or event exists.
- Add a song with a Song Name (title), optional notes, multiple music sheets/PDF uploads, and multiple links in one workflow.
- Allow more than one PDF file to be selected and uploaded for a song, with controls to add or remove individual files before saving.
- Provide repeatable link fields so administrators can add, edit, or remove more than one link per song; validate each URL on the server and allow only HTTP/HTTPS links.
- Edit song details and add, edit labels for, replace, or remove individual sheets.
- Label each sheet by instrument or arrangement where applicable.
- See which seasons and events use a song or sheet before changing or deleting it.
- Delete unused songs and sheets with explicit confirmation.

The library management page is an administrator-facing view of the catalog, not a raw database console. Protect all library management APIs with server-side administrator authorization.

### Season and event reuse
For each event, administrators can:
- See a read-only list of confirmed reservations showing each child's full name, song, selected instrument, and spot number directly on Seasons & events.
- See a clear "No confirmed reservations yet" message when an event has no occupied spots. Cancelled and administrator-cancelled reservations must not appear as occupied spots.
- Keep reservation names administrator-only through server-side authorization; parent browsing must continue hiding other families' children's names. Refreshing administrator data must update these event lists.
- Select library songs, reorder them, or remove them from the event.
- Choose one or more of each song's library sheets for that event.
- Set event-specific notes without overwriting the library song's notes.
- Select only the instruments needed.
- Specify a positive whole-number capacity for each selected instrument.

Reuse the same library song and sheets across multiple events and seasons without duplicating song records or uploaded files. Keep song order, selected sheets, notes, instrument requirements, capacity, and reservations specific to each event.

Removing a song or sheet selection from an event must not delete it from the library or affect other events. Deleting or archiving a season or event must not cascade-delete library songs or sheets.

If a song requests only Piano and Violin, parents must see only Piano and Violin booking options.

### Updates, deletion, and history
- Clearly distinguish editing a shared library record from editing an event's configuration.
- Before applying a shared song or sheet change, show the affected seasons and events and require confirmation of its impact.
- Do not silently replace or remove sheets already selected for published events; require explicit impact review and notify affected families when relevant.
- Block permanent deletion of songs or sheets referenced by events or historical records. Allow archiving them to prevent new selections while preserving existing references and authorized access.
- Preserve the sheet versions used by past events when replacing a shared file; do not overwrite or delete those stored files.
- Record library creation, updates, replacements, archiving, and deletion in the administrator audit log.

### Music sheets
- Support PDF uploads initially.
- Validate file type, size, and access permissions on the server.
- Provide accessible download links and previews where supported.
- Protect files from unauthenticated public access.
- Allow parents to access only sheets selected for events they are authorized to view; the complete library and unselected sheets remain administrator-only.
- Allow replacement and removal subject to the shared-library impact and history rules above, with clear parent notifications when relevant.
- Store files in durable storage rather than temporary application storage.
- Display helpful messages for missing or unavailable files.

Administrators must confirm they have permission to distribute uploaded material.

## 9. Parent Season Browsing

Provide a season listing page showing currently published seasons and clearly identifying whether registration is open, not yet open, closed, or full.

Provide season details showing:
- Description and date range.
- Registration window.
- Event dates, times, and location.
- Songs.
- Required instruments.
- Total, reserved, and available capacity for each instrument.
- Available music sheets.
- Booking and cancellation rules.
- The parent’s eligible children.
- The parent’s existing reservations.

### Song and instrument listing
- List every event song added to the season, grouped by event date; do not show only songs with available spots.
- For each entry, display DATE, SONG NAME, all music sheets selected for that event with preview/download access, all song links, library notes, and event-specific notes.
- Show every requested instrument for each song, its availability, and a registration action for each available spot so parents can register an eligible child.
- Selecting an instrument must show the associated event, song details, and instrument availability in read-only form; parents cannot edit the schedule, song details, or instrument requirements.
- Keep occupied spots visible and clearly labeled Reserved. Their details remain viewable but read-only, with no registration action for the occupied spot and no disclosure of another family's child's name.
- An instrument with remaining capacity must still allow registration for its available spots even when other spots for that instrument are reserved.
- Preserve the signed-in parent's ability to view and cancel their own reservations according to Section 11.

Allow filtering by season, date, instrument, and availability.

Use clear labels such as:
- Available.
- Full.
- Registration Closed.
- Pending Child Approval.
- Already Registered This Season.

Do not rely on color alone to communicate status.

## 10. Reservation Rules and Concurrency

### Primary business rule
**A child can hold one confirmed regular-song spot across an entire season, regardless of event, song, or instrument, plus one confirmed spot per song marked as an extra song for that season (Section 7).**

An overlapping season is a separate season with independent regular- and extra-song allowances, provided the event times do not conflict across seasons.

Additional rules:
- Only approved children belonging to the signed-in parent can be booked.
- The child must list the selected instrument in their approved profile.
- Registration must be open.
- The selected spot must be available.
- Each spot can have only one confirmed reservation.
- Multiple children under the same account can each reserve their own eligible spot.
- Cancelled reservations do not count toward the regular-song or extra-song limits.
- Prevent overlapping confirmed performance times for the same child across seasons.
- Prevent duplicate bookings from repeated taps, retries, or simultaneous requests.

### Booking flow
1. Choose a season and event.
2. Review songs and availability.
3. Select an eligible child.
4. Select an available instrument spot.
5. Review and confirm.
6. Show a confirmation screen and send an email.

Creating an approved child’s reservation should confirm immediately; do not introduce a second administrator approval step unless explicitly requested.

Enforce capacity and uniqueness rules atomically in the database, not only in the interface.

If two parents attempt to book the final spot simultaneously, exactly one request should succeed. The other must receive a clear “This spot has just been taken” message and refreshed availability.

Do not show success until the reservation is durably stored.

## 11. Cancellations and Changes

Parents can:
- View upcoming and past reservations.
- Cancel before the configured cancellation cutoff.
- See when cancellation requires coordinator assistance.

After a valid cancellation:
- Release the spot immediately.
- Update availability.
- Send a cancellation notification.
- Preserve a cancellation record.

Administrators can cancel or reassign reservations with an explanation and notification to the affected parent.

Do not automatically cancel an existing reservation while a parent attempts to switch spots. A failed switch must leave the original reservation intact.

If an administrator reduces instrument capacity below the number of confirmed reservations, block the change until affected reservations are explicitly resolved.

For deleting seasons, events, event song assignments, or instrument requirements:
- Allow straightforward deletion of unused drafts.
- Require impact review and explicit confirmation when reservations exist.
- Preserve historical and audit records.
- Notify affected families of cancellations or significant changes.

Deleting an event song assignment must not delete its library song or sheets. Apply the library-specific deletion and history rules in Section 8 when deleting shared catalog records.

## 12. Children’s Privacy

Protect children’s information by default.

- Administrators can view full names and registration details.
- Parents can view full details only for their own children.
- Other authenticated parents see only Reserved next to an occupied spot, never the registered child's name or identifying details.
- Enforce this restriction in parent-facing API responses as well as the interface; administrators retain authorized roster access, and parents can still view their own children's reservations.
- Never display children’s birth details, experience notes, parent contact details, or additional information to other families.
- Do not make rosters or music sheets publicly accessible.
- Do not include unnecessary sensitive information in notifications or logs.

Provide a documented retention policy and an administrator-supported process for account deletion and child-data removal, subject to legitimate recordkeeping needs.

## 13. Administration Interface

Provide a separate, responsive administration area with:

### Dashboard
- Pending child approvals.
- Upcoming events.
- Reservations by season.
- Filled and unfilled instrument spots.
- Recently changed or cancelled registrations.

### Management pages
- Seasons and publication status.
- Parent email notifications with recipient selection and immediate delivery.
- Events and songs.
- Instrument requirements and capacity.
- Song library with search, song details, multiple-sheet uploads, sheet editing/replacement, usage visibility, archiving, and deletion controls.
- Child approvals.
- Reservations.
- Administrator access.

### Rosters and reporting
Administrators can filter by:
- Season.
- Event date.
- Song.
- Instrument.
- Child.
- Parent.
- Reservation status.

Show:
- Child name.
- Parent or guardian name.
- Authorized contact information.
- Season.
- Performance date and time.
- Song.
- Selected instrument.
- Reservation status and timestamp.

Provide CSV export and a print-friendly roster. Restrict exports to administrators and protect against spreadsheet formula injection.

## 14. Notifications

Send transactional emails for:
- Email verification.
- Password reset.
- Administrator invitations.
- Child approval or rejection.
- Reservation confirmation.
- Cancellation.
- Significant schedule, song, or instrument changes affecting a reservation.
- Event reminders.

Make reminder timing configurable at the church level.

Email delivery failures must be visible to administrators and retryable. A failed confirmation email must not lose or undo a valid reservation.

### Administrator-composed email
- Provide an administrator-only interface to compose a plain-text email with a subject and message body.
- Let administrators select one parent, multiple parents, or all parent accounts. The all-parents action targets the current set of parent accounts with verified email addresses.
- Show parent names and email addresses in the recipient picker, with search and an accessible select-all/clear-all control.
- Send immediately when the administrator confirms the send action; do not schedule or queue these user-composed messages.
- Send each recipient a separate message so parent email addresses are never disclosed to other recipients.
- Enforce administrator authorization and same-origin write checks on the server, validate and bound input, rate-limit sends, and record an audit entry with counts but not message contents.
- Report full and partial delivery outcomes clearly. Do not report failed recipients as sent; allow the administrator to retry only failed recipients without resending to recipients who already received the message.
- A delivery failure must not block other recipients from receiving their messages.

Optional in-app notices may supplement email. Do not make SMS or push notifications mandatory for the initial release.

## 15. Visual Design and Accessibility

Create a cohesive, polished interface rather than a generic CRUD dashboard.

### Visual direction
- Warm, welcoming, family-friendly, and appropriate for a church music ministry.
- Clean layouts, generous spacing, readable typography, and consistent components.
- A restrained color palette with strong contrast.
- Subtle music-related imagery or illustrations without clutter.
- Clear visual hierarchy and prominent primary actions.

### Parent experience
Include:
- A useful dashboard with child approval statuses and upcoming reservations.
- Easy-to-scan season cards.
- A mobile-friendly event agenda or calendar.
- Clear capacity indicators.
- A short, guided booking flow.
- Helpful empty states and actionable validation messages.
- Confirmation dialogs for destructive actions.
- Loading, error, unavailable, and offline states.

### Accessibility and iOS usability
Target WCAG 2.2 AA:
- Keyboard-accessible navigation.
- Visible focus indicators.
- Screen-reader labels.
- Accessible forms and error summaries.
- Sufficient contrast.
- Reduced-motion support.
- Touch targets appropriate for mobile use.
- No hover-only interactions.
- Support for text resizing and small-screen layouts.

Avoid excessive animation, cramped tables on phones, tiny controls, and unnecessary steps.

## 16. Technical Quality and Security

Before implementation:
- Propose a suitable technology stack and briefly justify it.
- Document assumptions and identify unresolved product decisions.
- Do not silently change the regular-song or season-specific extra-song reservation limits in Section 10.

Implementation requirements:
- Persistent database storage with migrations.
- Relational integrity and database-enforced booking constraints.
- Separate persistent entities for library songs, music sheets and retained file versions, event song assignments, and event sheet selections, with foreign keys that prevent deletion of referenced library records.
- Server-side validation for all writes.
- Secure session handling.
- Appropriate protection against CSRF, XSS, injection, brute-force attacks, and unauthorized access.
- Rate limiting for authentication and sensitive endpoints.
- Secure handling of uploaded files and secrets.
- Audit records for approvals, role changes, reservation overrides, and impactful schedule changes.
- Structured operational logging without unnecessary personal data.
- Backup and restore guidance.
- Clear separation between development/demo and production configuration.

Use real authentication, persistent data, and actual file storage. Do not present mocked functionality as a completed production feature.

## 17. Testing and Acceptance Criteria

Include automated tests covering critical workflows and authorization boundaries.

The application is acceptable only when:

1. An unverified account cannot access protected parent or administrator features.
2. A parent can add multiple children and view their approval statuses.
3. A pending or rejected child cannot reserve a spot.
4. One family cannot access another family’s private records.
5. Only configured instruments appear for each song.
6. Capacity is enforced under simultaneous booking attempts.
7. A child cannot hold two confirmed regular-song spots within one season or more than one confirmed spot for the same extra song in that season.
8. A cancellation releases capacity and permits a new eligible booking.
9. Overlapping seasons are supported without permitting conflicting performance times for the same child.
10. Failed spot changes preserve the original reservation.
11. Destructive administrative changes cannot silently orphan or remove reservations.
12. Non-administrators cannot access administrative APIs directly.
13. Music-sheet access is authenticated and authorized.
14. Key parent and administrator workflows work on desktop and iPhone/iPad Safari.
15. Booking confirmations appear only after successful persistent storage.
16. Email delivery failure does not erase a confirmed reservation.
17. An administrator can create a library song with multiple PDF sheets without first creating a season or event, and the records and files persist after restarting the application.
18. Administrators can browse and edit the shared library, update sheet labels, replace sheets, and delete unused songs or individual sheets with confirmation.
19. The same library song and sheets can be selected while creating multiple seasons and events without duplicate records or file uploads.
20. Editing one event's song order, notes, selected sheets, instruments, or capacity does not change another event or the shared library.
21. Removing an event song assignment or deleting a season/event leaves the library song and its sheets intact.
22. Referenced songs and sheets cannot be permanently deleted; archiving prevents new selections while preserving existing references, and file replacement preserves sheets used by past events.
23. Changes to sheets selected for published events require impact review and relevant notifications; parents cannot browse the complete library or download unselected sheets through direct URLs.
24. The Add Song interface collects Song Name, optional notes, multiple PDF uploads, and multiple editable links in a single workflow, and saved details persist when the song is reopened.
25. Event creation collects a date and supports multiple library songs; selecting each song immediately displays its sheets, links, and notes, and administrators can select multiple instrument types with separate capacities for that song.
26. Parents browsing a season see every event song by date, including its selected sheets, links, notes, requested instruments, and available registration actions for eligible children.
27. Selecting an instrument displays read-only event/song/instrument details. Occupied spots remain visible as Reserved without exposing another family's child's name in the interface or API response, while any remaining spots stay bookable under Section 10.
28. Administrators can mark an assigned song as an extra song for one season, with the setting shared across its event appearances but absent from the library record and not carried to another season by song reuse or event copying.
29. An eligible child can reserve each marked extra song once per season, before or after a regular-song reservation, including at the same event. Cancellation releases the corresponding allowance, and concurrent requests cannot exceed either limit.
30. Extra-song settings are administrator-only and audited. Published-season changes require impact confirmation, and disabling is rejected without changing settings or reservations when it would leave multiple confirmed regular-song bookings for a child.
31. Administrators can compose an email, send it immediately to all verified parents or any selected set of one or more verified parents, and see which recipients succeeded or failed without exposing addresses to other recipients.
32. Administrators can delete a season and its events after confirmation only when it has no reservation history. All reservation statuses block deletion, shared library content remains intact, and failed deletions leave the season unchanged.
33. Seasons & events initially shows only Draft and Published seasons. Administrators can select any combination of statuses, show all seasons, reset to the defaults, and see an informative empty state when no seasons match.
34. Each event on Seasons & events displays the children holding confirmed reservations with their song, instrument, and spot number. Cancelled bookings are excluded, empty events are clearly labeled, and other families' children's names remain inaccessible to parents.

## 18. Deliverables and Scope

Deliver:
- Working application.
- Database schema and migrations.
- Automated tests.
- Secure first-administrator setup instructions.
- Local setup and deployment instructions.
- Environment-variable documentation without committed secrets.
- A concise administrator guide covering library management, multiple-sheet uploads, season/event reuse, shared-change impact review, and safe deletion or archiving.
- Clearly labeled synthetic demonstration data.
- A summary of completed requirements and any known limitations.

Keep the initial release focused. Payments, native App Store distribution, automatic waitlists, SMS, and multi-church tenancy are outside the initial scope unless explicitly approved.

Where a material requirement remains ambiguous, ask for clarification before implementing that behavior. Prefer the simplest maintainable solution that fully meets the confirmed requirements.