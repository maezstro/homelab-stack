# ServerChan Homelab Stack

Docker Compose setup for an Unraid server (Intel N100): VPN-routed torrent automation, a Jellyfin media server, and a Cloudflare Tunnel + Nginx Proxy Manager front door. Split into several small stacks instead of one big file.

## Layout

| Folder | Contents |
|---|---|
| `compose/` | Infrastructure: cloudflared and Nginx Proxy Manager. Creates the shared `compose_default` network. |
| `cloudflared/` | Tunnel `config.yml` (tunnel ID replaced with a placeholder) |
| `torrent-automation/` | Gluetun, qBittorrent, Prowlarr, Sonarr, sonarr-anime, Radarr, Bazarr, cross-seed, autobrr, qbit_manage, Profilarr |
| `media-server-stack/` | Jellyfin, Seerr, Wizarr, Audiobookshelf, NostalgiaTV |
| `actual/` | Actual Budget |
| `scripts/` | Helper scripts |

Not in this repo: Immich (its own compose project), and monitoring services (Pi-hole, Uptime Kuma, Glance), which run on a separate mini PC.

## Setup

1. In each stack folder, copy `.env.example` to `.env` and fill in real values. `.env` files are git-ignored.
2. Start the infrastructure stack first, since it creates the network the others join:

```
cd compose && docker compose up -d
```

3. Start the rest, one folder at a time:

```
cd torrent-automation && docker compose up -d
cd media-server-stack && docker compose up -d
```

To change a service, edit that stack's compose file and run `docker compose up -d` again. Only containers whose settings changed get recreated.

Don't run `docker compose down` in `compose/`. The other stacks attach to its network.

## Configuration notes

- **Single data share:** everything lives under one `/mnt/user/data` share, with `torrents/` and `media/{movies,tv,anime,audiobooks,podcasts}`. The arr apps mount the whole share as `/data`, qBittorrent and cross-seed mount `torrents/` as `/downloads`. One filesystem path means hardlinks work, so seeding doesn't cost extra disk space.
- **VPN-routed apps:** qBittorrent, Prowlarr, Sonarr, sonarr-anime and Radarr share Gluetun's network via `network_mode: service:gluetun`. Their ports are published on the `gluetun` service, and other containers reach them at `gluetun:<port>`. Gluetun's `FIREWALL_INPUT_PORTS` must list every one of those ports.
- **WireGuard key:** Gluetun uses NordVPN over WireGuard. The private key comes from the "manual setup" section of the NordVPN dashboard, not the access token (the token silently fails). It lives in `.env` as `WIREGUARD_PRIVATE_KEY`.
- **Jellyfin transcoding:** Intel Quick Sync via `/dev/dri`.
- **Seerr + Jellyfin:** Seerr needs `EnableLegacyAuthorization=true` in Jellyfin's `system.xml` to connect.
- **Remote access:** a Cloudflare Tunnel points every hostname at Nginx Proxy Manager, which routes by hostname.

## Backups

Unraid's Appdata Backup plugin saves app configs nightly. A daily flash-drive backup and a nightly rclone sync to Backblaze B2 run through the User Scripts plugin.

## Notes

Personal setup shared for reference. Paths, domains and hardware settings are specific to my machine.
