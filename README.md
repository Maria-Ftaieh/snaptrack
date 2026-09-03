# SnapTrack

Track Snapchat snapscores for a small circle of friends over time and see how
their activity trends. You add people, log each person's current snapscore
whenever you check it, and the app turns that history into charts and stats.

The score is entered manually — SnapTrack does not connect to Snapchat or read
any account. It only stores the numbers you type in.

## What it does

- **People list** — add friends (name + optional Snapchat username).
- **Log a score** — tap a person, enter their current snapscore. Every entry is
  timestamped and stored on the backend.
- **Fix mistakes** — delete any wrong entry from the person's recent history.
- **Stats per person**
  - Current score and last update time
  - Last 7 / 30 day increase and daily average
  - Week-over-week and month-over-month percentage change
  - Snapscore line chart (auto-scaled to the value range so trends are readable)
  - Daily activity (last 14 days), weekly activity (last 8 weeks) and hourly
    activity bar charts
- **Reminders** — local notifications every ~2 hours between 10:00 and 00:00 at a
  slightly randomised minute, with a 10-minute follow-up if you don't open the
  app. All timing is on-device; no push server involved.

## Architecture

```
iOS app (SwiftUI)  ──HTTPS──▶  FastAPI (uvicorn)  ──▶  SQLite
                              ▲
                              │  X-API-Key header
```

- **iOS app** — SwiftUI, Swift Charts, `@Observable` view models, iOS 26+.
- **Backend** — FastAPI + SQLAlchemy + SQLite. Every endpoint is protected by a
  single shared API key sent in the `X-API-Key` header.

## Repository layout

```
snaptrack/
├── snaptrack/            # iOS app source (SwiftUI)
├── snaptrack.xcodeproj/  # Xcode project
├── backend/              # FastAPI backend
│   ├── app/              # routers, models, schemas, stats
│   ├── tests/            # pytest suite
│   └── deploy/           # systemd unit + Caddy example
└── tools/                # helper scripts (app icon generator)
```

## Backend setup

Requires Python 3.11+.

```bash
cd backend
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
cp .env.example .env          # then set API_KEY=$(openssl rand -hex 32)
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

- API docs (Swagger UI): <http://localhost:8000/docs>
- Health check (no auth): `GET /health`
- Run the tests: `pytest`

For production deployment (systemd service, reverse proxy with HTTPS, backups),
see [`backend/README.md`](backend/README.md).

### Configuration

Environment variables (via `backend/.env`):

| Variable    | Purpose                                            | Default            |
|-------------|----------------------------------------------------|--------------------|
| `API_KEY`   | Shared key required in the `X-API-Key` header      | `dev-key-change-me`|
| `DB_PATH`   | SQLite database file path                          | `./snaptrack.db`   |
| `ROOT_PATH` | URL prefix when served under a subpath by a proxy  | `` (empty)         |

## iOS app setup

1. Open `snaptrack.xcodeproj` in Xcode (iOS 26 SDK).
2. Select your development team under **Signing & Capabilities**.
3. Build and run on a simulator or a device.
4. On first launch, open **Settings** (gear icon), enter the backend base URL and
   the API key, then tap **Test connection**.
5. Allow notifications when prompted to receive reminders.

> The backend must be reachable over HTTPS for the iOS app to connect. For local
> HTTP testing you need an App Transport Security exception in the app's
> `Info.plist`.

## API overview

All endpoints require the `X-API-Key` header.

| Method   | Path                                | Description                       |
|----------|-------------------------------------|-----------------------------------|
| `POST`   | `/users`                            | Create a user                     |
| `GET`    | `/users`                            | List users with their latest score|
| `GET`    | `/users/{id}`                       | Get a user                        |
| `DELETE` | `/users/{id}`                       | Delete a user and their scores    |
| `POST`   | `/users/{id}/scores`                | Log a snapscore                   |
| `GET`    | `/users/{id}/scores`                | List a user's scores              |
| `DELETE` | `/users/{id}/scores/{score_id}`     | Delete one score entry            |
| `GET`    | `/users/{id}/stats`                 | Aggregated stats for charts       |

## License

Released under the [MIT License](LICENSE).
