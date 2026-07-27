# Docker-only Farmer / NSR

Run Farmer or NSR end-to-end from published images only (no Python/Node installs).

Each variant has its **own** command. Starting Farmer does **not** start NSR (and vice versa). Shared pieces for either variant: Postgres, Redis, MinIO, Keycloak, ID Generator, IAM, AWE, and the **Staff Portal hub** (app launcher).

Farmer and NSR each run their **own** registry UI container (same image, different ports). The hub Staff Portal is a separate single page that lists links to those apps (from IAM).

## Prerequisites

- Docker Engine + Compose v2
- Make
- `docker login registry.gitlab.com` (AWE + Master Data images)
- In `.env`: `USE_EXTERNAL_REDIS=false`

## Commands

```bash
cd openg2p-developer
cp .env.example .env
# set USE_EXTERNAL_REDIS=false

make sync-images

# Farmer only (infra + IAM + AWE + Farmer UI/API/partner/Celery + seed)
# Downs existing Farmer stack, resets Farmer DBs, migrates, then seeds.
make docker-farmer-up
# alias: make up-farmer-registry

# NSR only (infra + IAM + AWE + NSR UI/API/partner/Celery + seed)
# Downs existing NSR stack, resets NSR DBs, migrates, then seeds.
make docker-nsr-up
# alias: make up-nsr-registry

# Both (runs Farmer then NSR)
make docker-all-up
# alias: make docker-registry-up

# Resume after a failed up (keeps running containers; starts missing ones + seeds)
make docker-farmer-continue
make docker-nsr-continue
# If schema is half-applied and you need a clean remigrate without full teardown:
# RESET_DBS=1 make docker-farmer-continue
```

Seeding runs automatically as part of each `*-up` / `*-continue` (defaults `LOAD_SAMPLE_DATA=true`). Override:

```bash
LOAD_SAMPLE_DATA=false LOAD_IMAGES=false make docker-farmer-up
```

## What each command starts

| Component | `docker-farmer-up` | `docker-nsr-up` |
|-----------|--------------------|-----------------|
| Postgres / Redis / MinIO / Keycloak / ID Gen | yes | yes |
| IAM + AWE API + AWE UI | yes | yes |
| Staff Portal hub `:3000` (links to apps) | yes | yes |
| Master Data API (migrates variant master DB) | `:8042` | `:8043` |
| Farmer registry UI `:3001` / API `:8001` / partner `:8006` / Celery | yes | — |
| NSR registry UI `:3002` / API `:8011` / partner `:8012` / Celery | — | yes |
| Variant db-seed | farmer | nsr |

## URLs / credentials

| Service | Farmer | NSR |
|---------|--------|-----|
| Staff Portal hub | http://localhost:3000 | same |
| Registry UI | http://localhost:3001 | http://localhost:3002 |
| Staff API | http://localhost:8001/docs | http://localhost:8011/docs |
| Partner API | http://localhost:8006/docs | http://localhost:8012/docs |
| IAM | http://localhost:8020 | same |
| AWE API / Admin | `:8030` / `:8031` | same |
| Master Data | http://localhost:8042 | http://localhost:8043 |
| Keycloak | http://localhost:8080 (`staff` / `staff`) | same |

## Image pins

All tags live under `images:` in [`versions.yaml`](../versions.yaml). Sync with `make sync-images`.

## Stop

```bash
make docker-down   # stop all OpenG2P compose services (volumes kept)
make down          # same as docker-down (legacy alias)
make docker-clean  # stop + remove volumes (destructive)
make clean         # same as docker-clean
```
