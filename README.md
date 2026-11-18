# NyayVanni

Police documentation system. An officer records a complainant's statement in Hindi,
Marathi or English; the app prepares a structured FIR draft; a station supervisor
reviews it. Administrators manage officers, stations and records from a web console.

- `lib/` — Flutter app (Android, iOS, web, desktop)
- `server/` — Node.js API and the administration console (`/admin`)

## Roles

| Role | Can do |
|---|---|
| Officer | Record statements, edit their own drafts, send them for review |
| Station supervisor | Everything an officer can, plus approve or return FIRs from the **same station and district** (never their own) |
| Administrator | Web console: approve registrations, manage officers, stations, admins, view the audit log |

## FIR workflow

`Draft` → **Send for review** → `In review` (locked) → `Approved` (locked) or `Returned` (editable again, with the reviewer's comment).

## Run the server

```powershell
cd server
npm install
copy .env.example .env      # then edit it
npm start                   # http://127.0.0.1:3000  (admin console at /admin)
npm test                    # parser and API tests
```

Set in `.env` before any real use: `JWT_SECRET`, `ADMIN_PASSWORD`. With
`NODE_ENV=production` the server refuses to start without them. Use `CORS_ORIGINS`
to restrict browser access. Data is stored in `server/data/db.json`.

## Run the app

```powershell
flutter pub get
flutter run -d chrome --dart-define=API_BASE=http://127.0.0.1:3000
```

On a phone, set `API_BASE` to your computer's LAN address (the Android emulator uses
`http://10.0.2.2:3000`). Release builds need an `https://` API address: plain HTTP is
only permitted in debug builds.

If the build fails with `'C:\Users\Name' is not recognized` your Windows user folder
contains a space. Use a junction without spaces, e.g. `mklink /J C:\flsdk "<your flutter folder>"`,
and run Flutter from there with `PUB_CACHE` set to a path without spaces.

## Temporary passwords

Passwords issued by an administrator are temporary: the officer must choose a new one
at first sign-in before anything else is allowed.
