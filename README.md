# homelab (旧構成のアーカイブ)

> 2026-10-01 に鯖を全面的に作り直しました。現行の構成と手順は **Leucophyllous/infra**（非公開）が正本です。このリポジトリは Proxmox 時代の記録として残しています。

## 現行構成（2026-10-01 時点）

| ホスト | IP | OS | 役割 |
|---|---|---|---|
| pve | 192.168.0.150 | Debian 13 + Docker | NUT 親、ilust・各bot、Cloudflare Tunnel(pve)、hdd1 の SMB |
| pve02 | 192.168.0.101 | Debian 13 + Docker | NUT 子 |
| Pi | 192.168.0.243 | Raspberry Pi OS (Debian 13) | Gatus、外部ハートビート、NUT 子 |
| OrangePi 5 Plus | 192.168.0.183 | Armbian (Debian 13) | Samba(msdfs)、restic-server、NUT 子 |
| A1 (OCI) | Tailscale 経由 | Ubuntu 24.04 | MCP、cloudflared(Tunnel A1)、homepage、manmaru、mail-sync |

- Proxmox、HA、ZFS レプリケーション、NPM、Dockge、docker-proxy、n8n 監視は廃止。
- 公開は Cloudflare Tunnel + Access のみ。
- 監視は Gatus（Pi）と Healthchecks の外部ハートビート。

旧 README は [docs/legacy-README-20260925.md](docs/legacy-README-20260925.md) に移しました。
