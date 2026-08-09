# ServerChan Homelab Stack

A self-hosted media automation stack running on Docker Compose, with VPN-routed
downloads, a reverse proxy, and a recipe manager.

## Services

- **Gluetun** - VPN gateway (NordVPN/OpenVPN) that routes qBittorrent, Sonarr,
  Radarr, Prowlarr, and Profilarr traffic through the VPN
- **qBittorrent** - torrent client
- **Sonarr / Radarr** - TV and movie library automation
- **Prowlarr** - indexer manager for the *arr apps
- **Profilarr** - quality profile sync for Sonarr/Radarr
- **Bazarr** - subtitle automation
- **Jellyfin** - media server
- **Jellyseerr** - media request UI for Jellyfin
- **ErsatzTV** - custom "live TV" channels from your library
- **Homarr** - dashboard for the stack
- **Notifiarr** - notifications for the *arr apps
- **Nginx Proxy Manager** - reverse proxy + SSL for exposed services
- **FlareSolverr** - Cloudflare bypass proxy for indexers
- **Mealie** - self-hosted recipe manager (separate compose file)

## Architecture notes

- Media is stored on two NAS shares mounted via CIFS/SMB, split across
  `/mnt/nas/media` and `/mnt/nas/media2`
- Downloading services (qBittorrent, Sonarr, Radarr, Prowlarr, Profilarr) share
  Gluetun's network namespace so all their traffic is VPN-routed
- Nginx Proxy Manager handles reverse proxy + certs for exposed services

## Setup

1. Copy `.env.example` to `.env` and fill in real values:

```
cp .env.example .env
```

2. Review `compose/docker-compose.yml` and adjust volume paths to match your
   own NAS/storage layout
3. Bring up the main stack:

```
docker compose -f compose/docker-compose.yml up -d
```

4. Bring up Mealie separately:

```
docker compose -f compose/mealie-docker-compose.yaml up -d
```


## Configuration notes

A few things about this setup you won't figure out just from staring at the compose file:

- **Two NAS mounts, not one**: My media's split across two separate NAS shares
  (`/mnt/nas/media` and `/mnt/nas/media2`), each with its own Movies/Shows/Anime
  folders. Anything that touches media (Sonarr, Radarr, Jellyfin, Bazarr,
  ErsatzTV) mounts both and treats them as separate libraries. If you're just
  running one NAS/drive, feel free to drop the "2" mounts and simplify — this
  split is a "me" problem, not a "you" problem.

- **Everything routes through Gluetun**: qBittorrent, Sonarr, Radarr, Prowlarr,
  and Profilarr all share Gluetun's network via `network_mode: "service:gluetun"`
  instead of exposing their own ports. That means Gluetun's `ports:` section is
  what actually opens things up to the outside — if you add another service
  that needs to go through the VPN, its ports go there, not under the service
  itself. Easy thing to forget and then wonder why you can't reach a new app.

- **CIFS mount settings actually matter**: NAS shares are mounted with `hard`
  (not `soft`) in `/etc/fstab`. Learned this one the hard way — `soft` mounts
  were throwing `EAGAIN` errors in qBittorrent every time the NAS had even a
  tiny network hiccup. `noserverino` is set too, since this NAS doesn't give
  out consistent inode numbers on its own.

- **Jellyfin needed a nudge**: Bumped `JELLYFIN_FFmpeg__probesize` and
  `analyzeduration` up to 50M. Without this, playback took forever to start
  because ffmpeg's default probing settings are way too conservative for a
  library sitting on network storage.

## Backups

A nightly cron job backs up all *arr configs, compose files, Nginx Proxy
Manager's database/certs, and Mealie data, with 14-day retention. See
`scripts/` for the backup script.

## Notes

This is a personal homelab setup shared for reference. Volume paths, network
config, and hardware acceleration settings (`/dev/dri` for QuickSync) are
specific to my hardware and will need adjusting for yours.
