# homelab

2026-10-06 時点の現行構成と、運用の正本。GitHub の infra リポジトリは 2026-10-06 にアーカイブ済みで、旧構成の参照用。

## 現行構成

| ホスト | IP | 役割 |
|---|---|---|
| pve | 192.168.0.150 | Pterodactyl（Panel は Docker、Wings は systemd）、Minecraft Bedrock、mixerbox-api、samba-hdd1、NUT 親 |
| OrangePi 5 Plus | 192.168.0.183 | Gatus、restic rest-server、Samba、telegram-cmd-bot、wol-bot。サブネットルート 192.168.0.0/24 を広告 |
| A1 (OCI) | Tailscale 経由 | MCP、homepage、ilust、manmaru、Discord bot、mail-sync、Cloudflare Tunnel。削除・譲渡禁止 |
| pve02 / Pi | .101 / .243 | 一時廃止（電源オフ） |

## 方針

- 役割を分ける: 重いサービスは pve、ローカル必須の軽いものは OrangePi、公開系は A1。
- 管理は各ホストの Dockge（/opt/stacks）。秘密は /opt/secrets。バックアップは restic。Komodo は廃止。
- 公開は Cloudflare Tunnel と Access（Leila only）。
- Minecraft Bedrock は Pterodactyl 内で transport=nethernet、UDP 19132 の1本。グローバルIPが変わったら server.properties の server-udp-ports を更新する。起動時に自動アップデートする。
- 監視は Gatus と Healthchecks。自動対応の手順は [docs/auto-heal-runbook.md](docs/auto-heal-runbook.md)。

## 過去の記録

旧 README は [docs/legacy-README-20260925.md](docs/legacy-README-20260925.md)。
