# Build and run Harmony

Run all commands from the folder containing `package.json`. The commands below
use PowerShell on Windows and `npm.cmd` to avoid PowerShell execution-policy
errors from `npm.ps1`.

## 1. Install prerequisites

- Install Node.js 24 LTS, which includes npm. The package requires Node.js
  22.12.0 or newer; Node.js 24 is the recommended version.
- Install Git if you need to clone the repository.
- Run MySQL 8.0.16 or newer (8.4 LTS recommended) on `127.0.0.1:3306`.
- Allow network access to the npm registry and Google Fonts, directly or through
  your approved proxy. Next.js downloads Inter and Plus Jakarta Sans during
  development or compilation and serves the resulting fonts locally.

Check your installation:

```powershell
node --version
npm.cmd --version
```

For a fresh checkout:

```powershell
git clone https://github.com/rajasingh-fredrick/reservation-system.git
Set-Location .\reservation-system
```

If you already have the project locally, open PowerShell in that project folder
instead of cloning it again.

## 2. Configure the proxy if required

On the corporate network, set these variables in the same terminal you will use
for installing, building, or running the application:

```powershell
$env:HTTP_PROXY = "http://pxyapp.proxy.att.com:8080"
$env:HTTPS_PROXY = $env:HTTP_PROXY
$env:NODE_USE_ENV_PROXY = "1"
$env:NO_PROXY = "localhost,127.0.0.1,::1"
```

These settings apply only to the current terminal and its child processes.
Repeat them in a new terminal when needed. Skip this step on networks where
direct access works. Do not disable TLS certificate verification; ask your
network administrator for the approved certificate configuration if your proxy
reports a certificate error.

## 3. Install dependencies

The repository includes a lockfile, so use a reproducible installation:

```powershell
npm.cmd ci
```

## 4. Create local configuration

Copy the example only if you do not already have `.env.local`:

```powershell
if (-not (Test-Path .env.local)) {
  Copy-Item .env.example .env.local
}
```

Edit `.env.local`:

- Set `APP_URL=http://127.0.0.1:3000` for the default local server. The example
  currently uses port 3001, so update it to match the port you actually use.
- Set `BETTER_AUTH_SECRET` to a cryptographically random value of at least
  32 characters. This is required even for a local production build.
- Set `MYSQL_HOST=127.0.0.1`, `MYSQL_PORT=3306`, `MYSQL_USER=appuser`, and
  `MYSQL_DATABASE=harmony`. Leave `DATABASE_URL` empty when using these settings.
  An optional `mysql://` URL overrides them; passwords in URLs require percent encoding.
- Supply `MYSQL_PASSWORD` through the process environment or your secret manager.
  Do not save it in configuration files or type it into shell commands/history.
- Leave `DATA_DIR` and `UPLOAD_DIR` empty to use `.data\uploads` for private PDFs.
  The database now lives in MySQL, not the application data directory.

Generate a secret locally, then paste the output into `BETTER_AUTH_SECRET`:

```powershell
node -e "console.log(require('node:crypto').randomBytes(32).toString('hex'))"
```

Keep the secret stable between builds and server restarts. Never commit
`.env.local`, secrets, setup tokens, database contents, or uploaded PDFs.

### Create the MySQL database and tables

On Windows, start a temporary shell with a secure credential prompt:

```powershell
npm.cmd run db:session
```

Enter the database password in the credential prompt. The script creates
`harmony`, applies all migrations, and opens a child PowerShell shell with the
password only in its environment. Run the remaining commands in that shell;
type `exit` when finished. Do not print or dump the environment.

If your environment already supplies the credential, use:

```powershell
npm.cmd run db:migrate
npm.cmd run db:check
```

The migration account needs CREATE DATABASE and schema DDL privileges. Integration
tests additionally create and drop isolated `harmony_test_*` databases. Do not
grant global administrative permissions to the normal production runtime account.
Application startup applies pending migrations to an existing database; it does
not create the database itself.

MySQL DDL implicitly commits. A failed migration can leave partial schema changes:
fix the cause and inspect/repair those changes before rerunning. Applied migration
checksums are verified; add new migrations rather than editing applied ones.
The schema migration scripts do not transfer old records. To recover the preserved
local PostgreSQL/PGlite database, stop application writes and run a rehearsal:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts\mysql-session.ps1 -ImportLegacy -SourcePath .data\db
```

After checking the counts, repeat with `-Apply` to commit. Each invocation prompts
securely for MySQL credentials and opens a new copy of the source under
`.data\legacy-import-*`, never the original database. Keep those copies private:
they contain account and family data. Uploaded sheets must remain in the configured
upload directory; their existence and sizes are checked before import.

The importer preserves account/password hashes, IDs, relationships, dates, JSON
links, and existing MySQL-only rows. Identical records are skipped; conflicting
records stop the transaction rather than being overwritten. Inserts and value
verification run in one transaction, followed by a fresh persisted-value check.
MySQL's migration history and generated booking columns are not copied from
PostgreSQL. This recovery tool supports the preserved PGlite directory, not an
external PostgreSQL server or arbitrary SQL dump. Existing session cookies may
require signing in again, especially if the authentication secret has changed.

## 5. Run checks

```powershell
npm.cmd run typecheck
npm.cmd test
```

The first command checks TypeScript; the second runs the Vitest suite. Resolve
any failures before continuing.

## 6. Build the production application

```powershell
npm.cmd run build
```

This compiles the Next.js application, checks TypeScript, downloads and bundles
the configured fonts, and generates the production output in `.next`.
The command must finish successfully before starting the production server.

If font downloads fail, repeat the proxy configuration in step 2 in the current
terminal and run the build again. If the build reports
`Set BETTER_AUTH_SECRET to a random value of at least 32 characters`, check the
value in `.env.local` and rebuild.

## 7. Start the application

For the production build:

```powershell
npm.cmd start
```

Open `http://127.0.0.1:3000`. This runs in production mode: configure the SMTP
settings from `.env.example` for verification and password-reset emails, and
set a strong `SETUP_TOKEN` if you need to create the first administrator.

For local development with automatic reloads, use this instead:

```powershell
npm.cmd run dev
```

Development email links are printed in the server terminal. Follow the initial
administrator setup instructions on the sign-in page and in the terminal.
Use the same hostname and port as `APP_URL` when opening the app.
Stop the server with Ctrl+C before switching between development and production.

## Production deployment checklist

- Use MySQL with protected credentials and durable private PDF storage.
- Configure `APP_URL` to the public HTTPS origin.
- Set `BETTER_AUTH_SECRET`, SMTP settings, and the initial `SETUP_TOKEN` through
  the hosting environment's protected configuration.
- Remove the setup token after creating the first administrator.
- Back up the database and uploads before startup applies pending migrations.
- Both npm server scripts bind to `127.0.0.1`; use a TLS reverse proxy on the same
  host or configure the hosting platform's required bind address.
- Do not deploy only the static assets: authentication, reservations, and PDFs
  require the Next.js server.

See [README.md](README.md) for administrator workflows, storage and backup
guidance, and known limitations.
