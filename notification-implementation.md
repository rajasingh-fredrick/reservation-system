# Notification Implementation Plan

Status: Proposal only. No application changes have been implemented and no emails have been sent as part of this plan.

## Church and ministry details

- Church: Tamil Gospel Church
- Pastor: Pastor Solomon Karunakaran
- Ministry coordinator: Mrs. Amy Priya Shibu

## 1. Season publication announcement

### Purpose and timing

Let parents know when an administrator opens a new season for registration so they can register their children while available spots remain.

Send one announcement when a season first transitions from Draft to Published. Do not send another announcement when an administrator edits and saves an already-published season.

### Recipients and content

- Send to parent accounts with verified email addresses. Confirm whether unverified addresses should also be included.
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

Additional child registrations would receive a short acknowledgement rather than repeating the full welcome email.

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

## 7. Decisions to finalize before implementation

- Whether to include parent accounts whose email addresses are not verified.
- The destination URL for the season announcement's registration link.
- Recording submission method: email, WhatsApp, shared upload link, or an in-app upload. No upload feature is assumed in this plan.
- Coordinator contact details for submissions and questions.
- Church time zone and recording-deadline cutoff time, displayed explicitly in the email.
- Approval of the proposed first-child welcome trigger.
- Approval of the proposed late-registration behavior.
- Approval or revision of both email drafts.

## 8. Scope boundaries

- This document records the proposed plan and draft email content only.
- Do not implement notification behavior until the plan and outstanding decisions are approved.
- No recording upload feature is included unless separately approved.
- No additional automatic three-day reminder is included.
- No changes to application code or the existing requirements document are part of creating this document.
