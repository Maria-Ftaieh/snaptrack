# SnapTrack backend

FastAPI + SQLite. Single-user backend behind a shared `X-API-Key` header.

## Local development

```bash
cd backend
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
cp .env.example .env          # then fill in API_KEY=$(openssl rand -hex 32)
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

- Swagger UI: <http://localhost:8000/docs>
- Health check (no auth): `GET /health`

### Quick curl test

```bash
KEY=...your-api-key...

curl -s -X POST localhost:8000/users \
  -H "X-API-Key: $KEY" -H "Content-Type: application/json" \
  -d '{"name":"Ali"}'

curl -s -X POST localhost:8000/users/1/scores \
  -H "X-API-Key: $KEY" -H "Content-Type: application/json" \
  -d '{"score":40000}'

curl -s localhost:8000/users/1/stats -H "X-API-Key: $KEY" | jq .
```

## Tests

```bash
pytest
```

`tests/test_stats.py` covers the pure stats math; `tests/test_api.py` smoke-tests the
HTTP layer end-to-end with a per-test SQLite file.

## Deploy to a Linux server (systemd)

1. Copy this `backend/` directory to `/opt/snaptrack`.
2. Create a `snaptrack` system user that owns it:
   ```bash
   sudo useradd --system --home /opt/snaptrack --shell /bin/false snaptrack
   sudo chown -R snaptrack:snaptrack /opt/snaptrack
   ```
3. Build the virtualenv as that user (or globally then `chown`):
   ```bash
   sudo -u snaptrack python3 -m venv /opt/snaptrack/.venv
   sudo -u snaptrack /opt/snaptrack/.venv/bin/pip install -r /opt/snaptrack/requirements.txt
   ```
4. Place a real `.env` at `/opt/snaptrack/.env` (mode 600, owned by snaptrack).
5. Install the unit file:
   ```bash
   sudo cp deploy/snaptrack.service /etc/systemd/system/
   sudo systemctl daemon-reload
   sudo systemctl enable --now snaptrack
   sudo systemctl status snaptrack
   ```
6. The service listens on `:8000`. Put TLS in front of it (see below) before
   pointing the iOS app at it — iOS App Transport Security requires HTTPS.

### HTTPS options

- **Caddy** (recommended; one-line auto-Let's Encrypt). Install Caddy, then
  drop the example Caddyfile at `/etc/caddy/Caddyfile`, edit the hostname, and
  `systemctl reload caddy`. Domain required.
- **Cloudflare Tunnel** — no public port needed; tunnel to `localhost:8000`
  and Cloudflare terminates TLS for you.
- **Dev only, no domain**: keep plain HTTP and add an ATS exception in the iOS
  app's `Info.plist`. Not recommended outside local Wi-Fi.

### Rotating the API key

Edit `/opt/snaptrack/.env`, then `sudo systemctl restart snaptrack`.

### Backups

The whole state is one file: the SQLite DB at the path in `DB_PATH`. Cron
`sqlite3 snaptrack.db ".backup /backups/snaptrack-$(date +%F).db"`.
