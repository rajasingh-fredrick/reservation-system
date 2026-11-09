-- Harmony MySQL bootstrap. Run against an empty MySQL 8.0.16+ server/schema.
-- Includes schema only; it does not copy application data or MySQL server users.
-- Keep the database name below aligned with MYSQL_DATABASE on the destination site.
CREATE DATABASE IF NOT EXISTS harmony CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_as_ci;
USE harmony;
SET SESSION sql_mode = CONCAT_WS(',', NULLIF(@@SESSION.sql_mode, ''), 'ANSI_QUOTES');
CREATE TABLE IF NOT EXISTS schema_migrations (
  name varchar(255) PRIMARY KEY,
  checksum char(64) NOT NULL,
  applied_at datetime(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3)
) ENGINE=InnoDB;

-- Migration 0001_initial.sql
CREATE TABLE IF NOT EXISTS "user" (
  id varchar(191) PRIMARY KEY,
  name varchar(320) NOT NULL,
  email varchar(320) NOT NULL UNIQUE,
  "emailVerified" boolean NOT NULL DEFAULT false,
  image text,
  "createdAt" datetime(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  "updatedAt" datetime(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3)
) ENGINE=InnoDB;
CREATE TABLE IF NOT EXISTS session (
  id varchar(191) PRIMARY KEY,
  "expiresAt" datetime(3) NOT NULL,
  token varchar(255) NOT NULL UNIQUE,
  "createdAt" datetime(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  "updatedAt" datetime(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  "ipAddress" varchar(320),
  "userAgent" text,
  "userId" varchar(191) NOT NULL,
  FOREIGN KEY ("userId") REFERENCES "user"(id) ON DELETE CASCADE
) ENGINE=InnoDB;
CREATE TABLE IF NOT EXISTS account (
  id varchar(191) PRIMARY KEY,
  "accountId" varchar(320) NOT NULL,
  "providerId" varchar(191) NOT NULL,
  "userId" varchar(191) NOT NULL,
  "accessToken" text,
  "refreshToken" text,
  "idToken" text,
  "accessTokenExpiresAt" datetime(3),
  "refreshTokenExpiresAt" datetime(3),
  scope varchar(320),
  password text,
  "createdAt" datetime(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  "updatedAt" datetime(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  UNIQUE ("providerId", "accountId"),
  FOREIGN KEY ("userId") REFERENCES "user"(id) ON DELETE CASCADE
) ENGINE=InnoDB;
CREATE TABLE IF NOT EXISTS verification (
  id varchar(191) PRIMARY KEY,
  identifier varchar(320) NOT NULL,
  value text NOT NULL,
  "expiresAt" datetime(3) NOT NULL,
  "createdAt" datetime(3) DEFAULT CURRENT_TIMESTAMP(3),
  "updatedAt" datetime(3) DEFAULT CURRENT_TIMESTAMP(3)
) ENGINE=InnoDB;
CREATE TABLE IF NOT EXISTS admin_users (
  user_id varchar(191) PRIMARY KEY,
  granted_at datetime(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  FOREIGN KEY (user_id) REFERENCES "user"(id) ON DELETE CASCADE
) ENGINE=InnoDB;
CREATE TABLE IF NOT EXISTS app_settings (
  "key" varchar(191) PRIMARY KEY,
  value text NOT NULL
) ENGINE=InnoDB;
CREATE TABLE IF NOT EXISTS songs (
  id varchar(191) PRIMARY KEY,
  title varchar(320) NOT NULL,
  composer varchar(320) NOT NULL DEFAULT '',
  notes text NOT NULL DEFAULT (''),
  archived boolean NOT NULL DEFAULT false,
  created_at datetime(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at datetime(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3)
) ENGINE=InnoDB;
CREATE TABLE IF NOT EXISTS sheets (
  id varchar(191) PRIMARY KEY,
  song_id varchar(191) NOT NULL,
  label varchar(320) NOT NULL,
  instrument varchar(191),
  arrangement varchar(320) NOT NULL DEFAULT '',
  current_version integer NOT NULL DEFAULT 1 CHECK (current_version > 0),
  archived boolean NOT NULL DEFAULT false,
  created_at datetime(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  CHECK (instrument IS NULL OR instrument IN ('Violin','Piano','Keyboard','Drums','Guitar','Bass Guitar','Saxophone')),
  FOREIGN KEY (song_id) REFERENCES songs(id) ON DELETE RESTRICT
) ENGINE=InnoDB;
CREATE TABLE IF NOT EXISTS sheet_versions (
  sheet_id varchar(191) NOT NULL,
  version integer NOT NULL CHECK (version > 0),
  file_name varchar(320) NOT NULL,
  storage_key varchar(191) NOT NULL UNIQUE,
  size_bytes integer NOT NULL CHECK (size_bytes > 0),
  created_at datetime(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (sheet_id, version),
  FOREIGN KEY (sheet_id) REFERENCES sheets(id) ON DELETE RESTRICT
) ENGINE=InnoDB;
CREATE TABLE IF NOT EXISTS seasons (
  id varchar(191) PRIMARY KEY,
  name varchar(320) NOT NULL,
  description text NOT NULL DEFAULT (''),
  start_date date NOT NULL,
  end_date date NOT NULL,
  registration_opens_at datetime(3) NOT NULL,
  registration_closes_at datetime(3) NOT NULL,
  timezone varchar(320) NOT NULL,
  location varchar(320) NOT NULL DEFAULT '',
  instructions text NOT NULL DEFAULT (''),
  cancellation_hours integer NOT NULL DEFAULT 0 CHECK (cancellation_hours >= 0),
  status varchar(320) NOT NULL DEFAULT 'Draft' CHECK (status IN ('Draft','Published','Registration Closed','Completed','Archived')),
  created_at datetime(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at datetime(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  CHECK (start_date <= end_date),
  CHECK (registration_opens_at <= registration_closes_at)
) ENGINE=InnoDB;
CREATE TABLE IF NOT EXISTS events (
  id varchar(191) PRIMARY KEY,
  season_id varchar(191) NOT NULL,
  name varchar(320) NOT NULL,
  starts_at datetime(3) NOT NULL,
  ends_at datetime(3) NOT NULL,
  location varchar(320) NOT NULL DEFAULT '',
  CHECK (starts_at < ends_at),
  FOREIGN KEY (season_id) REFERENCES seasons(id) ON DELETE RESTRICT
) ENGINE=InnoDB;
CREATE TABLE IF NOT EXISTS event_songs (
  id varchar(191) PRIMARY KEY,
  event_id varchar(191) NOT NULL,
  song_id varchar(191) NOT NULL,
  notes text NOT NULL DEFAULT (''),
  position integer NOT NULL CHECK (position > 0),
  UNIQUE (event_id, position),
  FOREIGN KEY (event_id) REFERENCES events(id) ON DELETE RESTRICT,
  FOREIGN KEY (song_id) REFERENCES songs(id) ON DELETE RESTRICT
) ENGINE=InnoDB;
CREATE TABLE IF NOT EXISTS event_requirements (
  event_song_id varchar(191) NOT NULL,
  instrument varchar(191) NOT NULL CHECK (instrument IN ('Violin','Piano','Keyboard','Drums','Guitar','Bass Guitar','Saxophone')),
  capacity integer NOT NULL CHECK (capacity > 0),
  PRIMARY KEY (event_song_id, instrument),
  FOREIGN KEY (event_song_id) REFERENCES event_songs(id) ON DELETE RESTRICT
) ENGINE=InnoDB;
CREATE TABLE IF NOT EXISTS event_sheets (
  event_song_id varchar(191) NOT NULL,
  sheet_id varchar(191) NOT NULL,
  selected_version integer NOT NULL CHECK (selected_version > 0),
  PRIMARY KEY (event_song_id, sheet_id),
  FOREIGN KEY (sheet_id, selected_version) REFERENCES sheet_versions(sheet_id, version) ON DELETE RESTRICT,
  FOREIGN KEY (event_song_id) REFERENCES event_songs(id) ON DELETE RESTRICT,
  FOREIGN KEY (sheet_id) REFERENCES sheets(id) ON DELETE RESTRICT
) ENGINE=InnoDB;
CREATE TABLE IF NOT EXISTS audit_log (
  id varchar(191) PRIMARY KEY,
  action varchar(320) NOT NULL,
  description text NOT NULL,
  actor_id varchar(191) NOT NULL,
  created_at datetime(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  FOREIGN KEY (actor_id) REFERENCES "user"(id) ON DELETE RESTRICT
) ENGINE=InnoDB;
CREATE INDEX events_season_idx ON events(season_id, starts_at);
CREATE INDEX event_songs_event_idx ON event_songs(event_id, position);
CREATE INDEX event_sheets_sheet_idx ON event_sheets(sheet_id);
CREATE INDEX audit_created_idx ON audit_log(created_at DESC);

INSERT INTO schema_migrations (name,checksum) VALUES ('0001_initial.sql','559b743094827e26c4bf5398990ddccc4278e92ed330f6c4b3388246b5cd81b2');

-- Migration 0002_parent_children.sql

CREATE TABLE IF NOT EXISTS parent_profiles (
  user_id varchar(191) PRIMARY KEY,
  phone varchar(320) NOT NULL DEFAULT '',
  authorized_child_registration boolean NOT NULL,
  privacy_accepted_at datetime(3) NOT NULL,
  policies_accepted_at datetime(3) NOT NULL,
  created_at datetime(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at datetime(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  FOREIGN KEY (user_id) REFERENCES "user"(id) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS children (
  id varchar(191) PRIMARY KEY,
  parent_user_id varchar(191) NOT NULL,
  full_name varchar(320) NOT NULL CHECK (char_length(trim(full_name)) BETWEEN 1 AND 160),
  birth_month smallint NOT NULL CHECK (birth_month BETWEEN 1 AND 12),
  birth_year smallint NOT NULL CHECK (birth_year BETWEEN 1900 AND 9999),
  additional_information text NOT NULL DEFAULT ('') CHECK (char_length(additional_information) <= 3000),
  status varchar(320) NOT NULL DEFAULT 'Pending approval'
    CHECK (status IN ('Pending approval','Approved','Rejected','Archived')),
  status_reason text,
  reviewed_by varchar(191),
  reviewed_at datetime(3),
  created_at datetime(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at datetime(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  FOREIGN KEY (parent_user_id) REFERENCES "user"(id) ON DELETE RESTRICT,
  FOREIGN KEY (reviewed_by) REFERENCES "user"(id) ON DELETE RESTRICT
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS child_instruments (
  child_id varchar(191) NOT NULL,
  instrument varchar(191) NOT NULL
    CHECK (instrument IN ('Violin','Piano','Keyboard','Drums','Guitar','Bass Guitar','Saxophone')),
  years_experience decimal(4,1) NOT NULL CHECK (
    years_experience BETWEEN 0 AND 30 AND years_experience * 2 = truncate(years_experience * 2,0)
  ),
  PRIMARY KEY (child_id, instrument),
  FOREIGN KEY (child_id) REFERENCES children(id) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE INDEX children_parent_idx ON children(parent_user_id, created_at DESC);


INSERT INTO schema_migrations (name,checksum) VALUES ('0002_parent_children.sql','0cf28afc35c936524c947bf9689f81bd2e72021e3cc9071bec938c78da2ca602');

-- Migration 0003_reservations.sql
ALTER TABLE events ADD CONSTRAINT events_id_season_unique UNIQUE (id, season_id);
ALTER TABLE event_songs ADD CONSTRAINT event_songs_id_event_unique UNIQUE (id, event_id);

CREATE TABLE reservations (
  id varchar(191) PRIMARY KEY,
  child_id varchar(191) NOT NULL,
  season_id varchar(191) NOT NULL,
  event_id varchar(191) NOT NULL,
  event_song_id varchar(191) NOT NULL,
  instrument varchar(191) NOT NULL
    CHECK (instrument IN ('Violin','Piano','Keyboard','Drums','Guitar','Bass Guitar','Saxophone')),
  spot_number integer NOT NULL CHECK (spot_number > 0),
  status varchar(320) NOT NULL DEFAULT 'Confirmed'
    CHECK (status IN ('Confirmed','Cancelled','Admin cancelled')),
  created_at datetime(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at datetime(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  cancelled_at datetime(3),
  cancellation_reason text,
  FOREIGN KEY (event_id, season_id) REFERENCES events(id, season_id) ON DELETE RESTRICT,
  FOREIGN KEY (event_song_id, event_id) REFERENCES event_songs(id, event_id) ON DELETE RESTRICT,
  FOREIGN KEY (child_id) REFERENCES children(id) ON DELETE RESTRICT,
  FOREIGN KEY (season_id) REFERENCES seasons(id) ON DELETE RESTRICT
) ENGINE=InnoDB;

ALTER TABLE reservations ADD COLUMN active_booking tinyint GENERATED ALWAYS AS (CASE WHEN status='Confirmed' THEN 1 ELSE NULL END) STORED;

CREATE UNIQUE INDEX reservations_one_child_spot_per_season
  ON reservations(child_id, season_id, active_booking);
CREATE UNIQUE INDEX reservations_one_active_spot
  ON reservations(event_song_id, instrument, spot_number, active_booking);
CREATE INDEX reservations_child_idx ON reservations(child_id, created_at DESC);
CREATE INDEX reservations_event_idx ON reservations(event_id, status);


INSERT INTO schema_migrations (name,checksum) VALUES ('0003_reservations.sql','1c3b5a337ac4c1918eea79ca83613e92893c805307fe240ca0cece114dc1e578');

-- Migration 0004_reservation_review.sql
ALTER TABLE reservations ADD COLUMN review_required boolean NOT NULL DEFAULT false;
ALTER TABLE reservations ADD COLUMN review_reason text;
ALTER TABLE reservations ADD CONSTRAINT reservations_requirement_fk
  FOREIGN KEY (event_song_id, instrument)
  REFERENCES event_requirements(event_song_id, instrument)
  ON DELETE RESTRICT;


INSERT INTO schema_migrations (name,checksum) VALUES ('0004_reservation_review.sql','c3e25ffd57cd2c582d50f121f133ec8f91c30a13aa0b8a64d3339084b3d3afbb');

-- Migration 0005_song_links.sql
ALTER TABLE songs ADD COLUMN links json NOT NULL DEFAULT (JSON_ARRAY());


INSERT INTO schema_migrations (name,checksum) VALUES ('0005_song_links.sql','161a81ca02aceaed7f4f42fa9969a3493a800c74ca78b203a6754049d078034c');

-- Migration 0006_season_extra_songs.sql
CREATE TABLE season_song_settings (
  season_id varchar(191) NOT NULL,
  song_id varchar(191) NOT NULL,
  allow_extra boolean NOT NULL DEFAULT false,
  PRIMARY KEY (season_id, song_id),
  FOREIGN KEY (season_id) REFERENCES seasons(id) ON DELETE CASCADE,
  FOREIGN KEY (song_id) REFERENCES songs(id) ON DELETE CASCADE
) ENGINE=InnoDB;

ALTER TABLE reservations ADD COLUMN booking_group varchar(191) NOT NULL DEFAULT 'regular';
DROP INDEX reservations_one_child_spot_per_season ON reservations;
CREATE UNIQUE INDEX reservations_one_child_spot_per_season
  ON reservations(child_id, season_id, booking_group, active_booking);

INSERT INTO schema_migrations (name,checksum) VALUES ('0006_season_extra_songs.sql','e2d2ae03b2ea8f4ea620a2e1b71e27d1b25b76ffc849de7f092f95876430ff19');

-- Migration 0007_season_publication_notifications.sql
ALTER TABLE seasons
  ADD COLUMN first_published_at datetime(3) NULL,
  ADD COLUMN registration_notification_at datetime(3) NULL,
  ADD COLUMN registration_notification_timezone varchar(100) NULL,
  ADD COLUMN registration_notification_sent_at datetime(3) NULL,
  ADD INDEX seasons_notification_due (status, registration_notification_sent_at, registration_notification_at);

UPDATE seasons SET first_published_at=updated_at WHERE status <> 'Draft';

INSERT INTO schema_migrations (name,checksum) VALUES ('0007_season_publication_notifications.sql','384f1fbfd7d6e3404f70dcc8a7589bb2bfc7e95dafbd9fd77d0b2f4bade770ea');

-- Migration 0008_child_profile_notifications.sql
CREATE TABLE child_profile_notifications (
  id varchar(191) PRIMARY KEY,
  child_id varchar(191) NOT NULL UNIQUE,
  parent_user_id varchar(191) NOT NULL,
  kind varchar(32) NOT NULL CHECK (kind IN ('Welcome','Acknowledgement')),
  status varchar(32) NOT NULL DEFAULT 'Pending'
    CHECK (status IN ('Pending','Sending','Sent','Failed','Preview')),
  attempts integer NOT NULL DEFAULT 0,
  created_at datetime(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  last_attempt_at datetime(3),
  sent_at datetime(3),
  FOREIGN KEY (child_id) REFERENCES children(id) ON DELETE CASCADE,
  FOREIGN KEY (parent_user_id) REFERENCES "user"(id) ON DELETE CASCADE,
  INDEX child_notifications_status_idx (status,created_at)
) ENGINE=InnoDB;

INSERT INTO schema_migrations (name,checksum) VALUES ('0008_child_profile_notifications.sql','424962630aec6ee8bbaf6ffdf9f8325314bdf9b884c9df1c09f45fbe1b84d9ba');

-- Migration 0009_season_song_roles.sql
ALTER TABLE season_song_settings
  ADD COLUMN song_role varchar(32) NULL
  CHECK (song_role IS NULL OR song_role IN ('Opening Song','Closing Song','Special Song','Offertory Song'));

INSERT INTO schema_migrations (name,checksum) VALUES ('0009_season_song_roles.sql','2ee2a370b657f0d0dcf21d49230596b4470d75d88bd76cac6d6c1acb4883cde2');

-- Migration 0010_child_admin_notifications.sql
ALTER TABLE child_profile_notifications
  ADD COLUMN recipient varchar(32) NOT NULL DEFAULT 'Parent'
    CHECK (recipient IN ('Parent','Administrator')),
  ADD UNIQUE INDEX child_notifications_recipient_idx (child_id,recipient);

ALTER TABLE child_profile_notifications DROP INDEX child_id;

INSERT INTO schema_migrations (name,checksum) VALUES ('0010_child_admin_notifications.sql','5f35d1c9ac128e427a80c206cfeedef9aa544148058e4ffadf4d9c32a2ab614b');

-- Migration 0011_automated_notifications.sql
ALTER TABLE parent_profiles
  ADD COLUMN email_notifications_subscribed boolean NOT NULL DEFAULT false;

ALTER TABLE seasons
  ADD COLUMN registration_notification_queued_at datetime(3);

CREATE TABLE automated_notifications (
  id varchar(191) PRIMARY KEY,
  kind varchar(32) NOT NULL CHECK (kind IN ('SeasonAnnouncement','PerformanceReminder')),
  parent_user_id varchar(191) NOT NULL,
  season_id varchar(191) NOT NULL,
  event_id varchar(191),
  deduplication_key varchar(191) NOT NULL UNIQUE,
  status varchar(32) NOT NULL DEFAULT 'Pending'
    CHECK (status IN ('Pending','Sending','Sent','Failed','Preview','Skipped')),
  attempts integer NOT NULL DEFAULT 0,
  created_at datetime(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  last_attempt_at datetime(3),
  sent_at datetime(3),
  FOREIGN KEY (parent_user_id) REFERENCES "user"(id) ON DELETE CASCADE,
  FOREIGN KEY (season_id) REFERENCES seasons(id) ON DELETE CASCADE,
  FOREIGN KEY (event_id) REFERENCES events(id) ON DELETE CASCADE,
  INDEX automated_notifications_status_idx (status,created_at)
) ENGINE=InnoDB;

INSERT INTO schema_migrations (name,checksum) VALUES ('0011_automated_notifications.sql','a958cf2ed54f6b4aa8f72ea3f5488a7f5525148c63440d1ceb04631cba792e28');

-- Migration 0012_immediate_email_queue.sql
CREATE TABLE email_notifications (
  id varchar(191) PRIMARY KEY,
  user_id varchar(191) NOT NULL,
  kind varchar(32) NOT NULL CHECK (kind IN ('AccountSecurity','ParentTransactional','MinistryMessage')),
  expected_email varchar(320),
  subject varchar(255) NOT NULL,
  body mediumtext,
  expires_at datetime(3),
  status varchar(32) NOT NULL DEFAULT 'Pending'
    CHECK (status IN ('Pending','Sending','Sent','Failed','Preview','Skipped')),
  attempts integer NOT NULL DEFAULT 0,
  created_at datetime(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  next_attempt_at datetime(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  last_attempt_at datetime(3),
  sent_at datetime(3),
  FOREIGN KEY (user_id) REFERENCES "user"(id) ON DELETE CASCADE,
  INDEX email_notifications_due_idx (status,next_attempt_at,created_at)
) ENGINE=InnoDB;

INSERT INTO schema_migrations (name,checksum) VALUES ('0012_immediate_email_queue.sql','b6b84e38421a3d1af9b0fa5a180e0793e1b5cefd82c96fac5ea4fc695ce4acb4');

-- Migration 0013_email_notifications_default_subscribed.sql
ALTER TABLE parent_profiles
  MODIFY COLUMN email_notifications_subscribed boolean NOT NULL DEFAULT true;

INSERT INTO schema_migrations (name,checksum) VALUES ('0013_email_notifications_default_subscribed.sql','cc7bf862841bccf39dc98724b68e610a87fd75c32e16530d91bfccbe08482c24');

-- Migration 0014_parent_profiles_for_child_owners.sql
ALTER TABLE parent_profiles
  MODIFY COLUMN authorized_child_registration boolean DEFAULT NULL,
  MODIFY COLUMN privacy_accepted_at datetime(3) DEFAULT NULL,
  MODIFY COLUMN policies_accepted_at datetime(3) DEFAULT NULL;

INSERT INTO parent_profiles (user_id)
SELECT DISTINCT c.parent_user_id
FROM children c
LEFT JOIN parent_profiles pp ON pp.user_id=c.parent_user_id
WHERE pp.user_id IS NULL;

INSERT INTO schema_migrations (name,checksum) VALUES ('0014_parent_profiles_for_child_owners.sql','5312eb79e5100c35653ed90bf4df4942645dae905b78298804e924bf08d1642d');
