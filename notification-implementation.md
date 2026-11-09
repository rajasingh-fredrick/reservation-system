# Notification Implementation Plan

Status: Welcome, additional-child acknowledgement, administrator registration,
scheduled season announcements, and consolidated performance reminders have
durable delivery tracking. The hourly backend entry point is
`npm run notifications:send`; configure an external scheduler to invoke it.
Development emails are log previews; this document does not establish that
production email has been sent.

## Church and ministry details

- Church: Tamil Gospel Church
- Pastor: Pastor Solomon Karunakaran
- Ministry coordinator: Mrs. Amy Priya Shibu

## 1. Season publication announcement

### Purpose and timing

Let parents know when an administrator opens a new season for registration so they can register their children while available spots remain.

Send one announcement when a season first transitions from Draft to Published. Do not send another announcement when an administrator edits and saves an already-published season.

### Recipients and content

- Send only to registered parent accounts with verified email addresses and an
  explicit email subscription. Recheck eligibility immediately before delivery.
- Include the season name, start and end dates, and registration opening and closing times. Do not include a week count.
- Invite parents to register their children while spots are available, without promising that a spot is still open.
- Include a link to the season or parent registration page.

### Delivery safeguards

- Record the publication notification and its delivery status durably so repeated saves do not send duplicates and failures can be retried.
- Surface delivery failures to administrators.
- An email failure must not undo the season publication.
- Reuse the existing email sender where practical.

## 2. Performance reminder

### Purpose and timing

Send parents a reminder seven days before their performance, requesting practice recordings at least three days before the performance. This gives Mrs. Amy Priya Shibu time to review the recordings, speak with parents, and help correct any mistakes.

This plan includes one reminder at seven days, not an additional automatic email at three days.

### Proposed behavior

- Send only for confirmed reservations in upcoming, published events.
- Use the church's time zone to calculate reminder dates and recording deadlines.
- Combine all of a family's children, songs, and instruments for the same performance into one email, including extra songs.
- Include the performance date, time, location when available, recording deadline, and submission instructions.
- Recheck current reservations before sending and exclude cancelled bookings.
- Track delivery to prevent duplicates, retry failures, and make failures visible to administrators.
- Recalculate pending reminders when a performance is rescheduled.
- Proposed late-registration rule: if a family books after the seven-day reminder date, include recording instructions in its booking confirmation and clearly flag an already-passed recording deadline.

## 3. Welcome email

### Proposed trigger

Send one welcome email when a parent successfully submits their first child profile, rather than simply creating an account.

Additional child registrations receive a short acknowledgement rather than repeating the full welcome email.

Implementation note: the section 5 template is sent as plain text with real parent,
child, and dashboard values. The current welcome email omits a reminder promise
because reminders depend on the parent's current subscription and the configured hourly job.
Email failures preserve the child registration and
are visible/retryable under the administrator's Email parents page.

### Content

- Welcome the family to Tamil Gospel Church's children's music ministry.
- Acknowledge the submitted child profile without implying approval or a confirmed performance booking.
- Explain the next steps: profile approval, selecting an available performance opportunity, and preparation.
- Introduce Pastor Solomon Karunakaran and Mrs. Amy Priya Shibu.
- Explain the recording expectation upfront.
- Link to the parent dashboard.

## 4. Implementation steps after approval

1. Finalize the announcement and email templates and resolve the outstanding decisions below.
2. Document the approved behavior in the notifications section of [copilot-instructions.md](./copilot-instructions.md).
3. Reuse the existing email sender in [src/server/mail.ts](./src/server/mail.ts), adding durable notification records and a scheduled reminder process.
4. Connect the season announcement to the first Draft-to-Published transition, using verified parent email addresses by default.
5. Connect the welcome email to successful first-child registration.
6. Add the short acknowledgement for additional child registrations.
7. Connect late-registration recording instructions to booking confirmations if that proposed behavior is approved.
8. Verify:
   - Season announcement sends once on first publication and not on subsequent edits.
   - The recipient set follows the approved parent email verification rule.
   - Announcement details and registration link are correct; no week count is included.
   - Duplicate prevention, retries, and administrator visibility for announcement delivery failures.
   - Season publication remains successful even if email delivery fails.
   - Reminder timing and deadline calculations in the church's time zone.
   - Welcome delivery after first-child submission, without implying approval.
   - Duplicate prevention, including repeated scheduler runs.
   - Cancellation handling and reservation rechecks before sending.
   - Rescheduling and pending-reminder recalculation.
   - Consolidation for multiple children, instruments, songs, and extra songs.
   - Late registration and already-passed recording deadlines.
   - Failed-delivery visibility and retries.

The notification process must not lose or undo a valid child registration or reservation because an email delivery fails.

## 5. Draft welcome email

**Subject:** Welcome to Tamil Gospel Church's Children's Music Ministry!

Dear {{ParentName}},

Welcome to the children's music ministry at **Tamil Gospel Church**! We are delighted that your family is joining us as our children grow in their musical gifts and use them to worship and serve the Lord.

We have received the registration for **{{ChildNames}}**. Our ministry team will review the submitted profile, and you will receive a separate notification once it has been approved. Registering a child's profile does not yet reserve a performance spot.

**What happens next?**

- Once your child's profile is approved, sign in to view upcoming ministry events and available songs and instrument spots.
- Choose an available opportunity that matches your child's approved instruments.
- Use the music sheets and practice resources provided for the selected song.

For each performance, please send a practice recording **at least three days before the performance date**. This allows our ministry coordinator, **Mrs. Amy Priya Shibu**, to review the recording, speak with you about any corrections, and help your child feel prepared and confident.

You will also receive a reminder one week before the performance with the recording deadline and submission instructions.

**Parent dashboard:** {{DashboardLink}}

Under the pastoral leadership of **Pastor Solomon Karunakaran**, we look forward to encouraging your child and serving the Lord together.

Thank you for your support and partnership!

With warm regards,  
**Mrs. Amy Priya Shibu**  
Ministry Coordinator  
**Tamil Gospel Church**

## 6. Draft performance reminder

**Subject:** Performance next week - practice recording due {{RecordingDeadline}}

Dear {{ParentName}},

We look forward to your child's participation in the upcoming performance at **Tamil Gospel Church**!

**Performance:** {{EventName}}  
**Date and time:** {{PerformanceDateTime}}  
**Location:** {{LocationIfAvailable}}

**Your family's participation:**  
{{ChildName - Song - Instrument}}  
{{AdditionalParticipationRows}}

Please send a practice recording for each listed song and instrument **by {{RecordingDeadline}}**, at least three days before the performance.

This will give our ministry coordinator, **Mrs. Amy Priya Shibu**, time to review the recordings and speak with you about any mistakes or areas that need attention, helping your child prepare with confidence.

**How to send your recordings:** {{RecordingSubmissionInstructions}}

If you anticipate difficulty meeting the deadline, please contact Mrs. Amy Priya Shibu as soon as possible.

Thank you for helping your child prepare faithfully. We look forward to worshipping together!

With warm regards,  
**Mrs. Amy Priya Shibu**  
Ministry Coordinator  
**Tamil Gospel Church**

Template note: omit the location line when no location is available. Replace all placeholders with actual values before sending.

## 7. Backend notification jobs and subscriptions

- Run `npm run notifications:send` from the application directory once per hour.
  The command runs once and exits; it does not install a scheduler or run a daemon.
- Apply migration `0011` using `npm run db:migrate` before deployment. It adds
  opt-in preferences, publication audience tracking, and the automated delivery queue.
- Apply migration `0012` for the durable immediate email queue. Run
  `npm run notifications:work` as a separately supervised, continuously running
  process. It polls every second and delivers immediate emails without waiting
  for the hourly job; no web request contacts SMTP. Delivery latency depends on
  backlog and the SMTP service. Neither command installs a scheduler/service.
- Queue verification and password-reset links for existing accounts, bound to the
  current email and token expiry (24 hours / 1 hour). Unverified accounts must
  be eligible for these security messages; parent ministry notifications still
  require registration and verification. Expired or ineligible queued messages
  are Skipped. Clear general message bodies after Sent/Preview/Skipped; protect
  database and backup access to pending token-bearing messages.
- Save profile decisions, booking/cancellation/review work, and their email tasks
  atomically. Administrator-composed broadcasts queue private per-parent tasks
  and audit counts in one transaction. Recheck subscription at delivery.
- Set `NODE_ENV=production` for actual SMTP. The command loads the existing
  application environment configuration. Set `APP_URL`, `SMTP_HOST`, `SMTP_FROM`,
  the remaining provider settings, and `RECORDING_SUBMISSION_INSTRUCTIONS`.
  Instructions must be supplied by the coordinator; no recording upload or
  submission method is invented. Keep passwords in the process environment or a
  secret manager, not scheduler command-line arguments or committed files.
- Parents manage their preference using **Email notifications** in Family Workspace.
  New profiles are subscribed by default; migration `0013` changes the default
  without altering existing preferences. This controls season announcements,
  performance reminders, and administrator-composed ministry announcements.
  Administrators with their own children are parents too: child registration creates
  a missing parent profile, and migration `0014` repairs existing child-owner accounts.
  These profiles use the default subscription without inventing consent acceptance;
  saved preferences and administrator permissions are preserved.
  Account verification/recovery and transactional child-profile/reservation emails
  remain separate; the earlier question about opting out of those is unresolved.
- At each run, snapshot the subscribed, verified parent audience for each due
  first-publication schedule. Later season edits or newly subscribed parents do
  not regenerate an already-queued announcement. Expired registration periods and
  unpublished seasons are not announced.
- Discover confirmed families for events in Published or Registration Closed
  seasons, beginning at midnight seven calendar days before the performance in
  the season's church timezone. Hourly delivery may be up to an hour after that
  boundary. If the scheduler was offline, catch up while the event is still upcoming.
- Consolidate all currently confirmed children/songs/instruments, including extra
  songs, into one reminder per family and event. Re-read reservations, event time,
  season status, verification, registration, and subscription before sending.
- Recording deadline: end of the church-local calendar date three days before
  the event, explicitly shown with the timezone. Late reminders flag a passed
  deadline. Pending/Skipped reminders use a rescheduled event's current date;
  previously Sent reminders are not sent again after a reschedule.
- The immediate worker processes Pending child-profile notifications, including
  the separate administrator recipient, using their existing templates and claims.
  Welcome, acknowledgement, approval/rejection, booking, cancellation, review,
  administrator-composed, verification, and password-reset emails all use backend
  delivery. The hourly job processes a bounded immediate-queue fallback batch.
  Neither job replays source requests or backfills historical mail.
- Child-profile approval and rejection emails identify the child by their saved full name; rejection emails retain the coordinator's note.
- Scheduled tasks retry once per hourly run. Immediate general-email failures
  retry with exponential backoff from one minute to one hour; child-registration
  failures retry hourly. Each immediate batch takes at most 100 records from each
  queue and prioritizes account-security mail. A failure does not spin in a loop.
  Unique recipient/entity keys and transactional claims prevent normal duplicate
  delivery, including when the immediate worker overlaps the hourly job.
- A database-scoped advisory lock prevents overlapping command executions.
  Sent and Preview tasks are not resent. A process interrupted after claiming a
  task leaves Sending for operator investigation; it is never blindly reclaimed.
  SMTP is not exactly-once: a provider accepting mail before a connection drops
  can leave an ambiguous failure, and retrying may duplicate that email.
- See **Email parents** for automated delivery status and attempts. Correct SMTP
  configuration before the next hourly retry. Investigate Sending records with
  the mail provider before any manual recovery. A season is marked complete only
  when its announcement records are Sent/Skipped, never on a failed delivery.
- The command logs aggregate counts, closes database connections, and exits
  nonzero on processing errors, Failed tasks, or interrupted Sending work.
  Scheduler logs should be monitored. Development Preview rows are not production
  delivery; do not run development previews against the production database.

## 8. Remaining decisions

- Supply coordinator-approved recording submission instructions in the job environment.
- Decide whether unsubscribing should also affect transactional child/reservation
  emails. They currently retain existing behavior.
- Booking confirmations do not yet include the proposed late-registration
  recording instructions. Late-registered families receive the next hourly
  reminder if their family/event reminder has not already been sent.

## 9. Scope boundaries

- The hourly sender implements the season-announcement and performance-reminder
  behavior above; it does not install an operating-system scheduler.
- No recording upload feature is included unless separately approved.
- No additional automatic three-day reminder is included.
- The welcome implementation updates application code and the requirements document.
