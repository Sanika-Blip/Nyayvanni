# NyayVanni API

```
npm install
copy .env.example .env     # set JWT_SECRET and ADMIN_PASSWORD
npm start
npm test
```

## Endpoints (summary)

| Method and path | Who |
|---|---|
| `POST /api/auth/login` | officers |
| `POST /api/admin/login` | administrators |
| `GET/PUT /api/me` | signed-in user (officers may change phone, address, password) |
| `POST /api/parse` | extract FIR fields from a transcript |
| `GET/POST/PUT/DELETE /api/drafts` | officers (own drafts), administrators |
| `POST /api/drafts/:id/submit` | officer sends a draft for review |
| `GET /api/review/queue` | supervisors: FIRs from their station waiting for a decision |
| `POST /api/review/:id` | supervisors: `{ decision: "approved" \| "returned", comment }` |
| `/api/admin/*` | administrators (registrations, officers, stations, admins, emails, audit) |

Drafts that are in review or approved cannot be edited or deleted by their author.
Administrator changes and review decisions are written to the audit log.

## Configuration

`PORT`, `JWT_SECRET`, `ADMIN_USERNAME`, `ADMIN_PASSWORD`, `ADMIN_EMAIL`,
`CORS_ORIGINS`, `DATA_DIR`, and optional `SMTP_*` (see `.env.example`). Without SMTP,
credential emails are stored in the console's Email log instead of being sent.

The Flutter app uses `http://127.0.0.1:3000` unless built with `--dart-define=API_BASE=...`.
