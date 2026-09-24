# 鯖 (Homelab)

自宅で運用している Proxmox ベースのホームラボ構成。物理ホスト2台 + VM/LXC群 +
リモートの OCI インスタンス1台で、セルフホストサービス・ゲームサーバー・自動化基盤を構築している。

このリポジトリには各サービスの `compose.yaml` を(機密情報を `${VAR}` 参照に置き換えた上で)収録している。
実際の値は `.env` に入れて `.gitignore` で除外する運用。**このリポジトリ自体に秘密情報を含めない。**

## ホスト一覧

| ホスト | 役割 | スペック |
|---|---|---|
| pve | Proxmoxメインホスト、LXC群 | 6コア / 24GB RAM |
| pve02 | Proxmoxセカンドホスト、VM群 | 8コア / 16GB RAM |
| OrangePi | NAS・DNS・SMB共有 | ARM SBC |
| mcp-a1 (OCI) | MCPサーバー、メール集約 | Tailscale経由でリモート接続 |
| Raspberry Pi | NPM(リバースプロキシ)・docker-proxy | - |

## pve 上の LXC

| CTID | 名前 | 役割 |
|---|---|---|
| 121 | minecraft-ct | PaperMC + Geyser/Floodgate(クロスプレイ対応マイクラ鯖) |
| 126 | vpn-lab | VPN検証環境 |
| 130 | discord-bots | Discord/Telegram bot群(everyone-bot, wol-bot, rolepanel-bot, telegram-cmd-bot) |
| 135 | manmaru | 告知Bot + Web管理パネル |
| 136 | ilust | イラスト関連サービス |
| 137 | nut-exporter | UPS監視(Prometheus exporter) |
| 138 | prometheus | メトリクス収集 |
| 139 | grafana | 可視化ダッシュボード |
| 141 | forgejo | 自前Gitサーバー |
| 142 | n8n | ワークフロー自動化(監視・自動修復・通知) |
| 146 | ollama | ローカルLLM推論 |

## pve02 上の VM

| VMID | 名前 | 役割 |
|---|---|---|
| 110 | DB-vm | MariaDB |
| 112 | docker-vm | Homepage, Home Assistant, Forgejo Runner, docker-proxy |

## mcp-a1 (OCI, リモート)

Tailscale経由で接続するMCPサーバー。Claude (Anthropic) がこのホームラボを操作するための
SSH/Proxmox API/OCI API/Proton Calendar ツールを提供する ([mcp](https://github.com/Leucophyllous/mcp) リポジトリ参照)。
同居でProtonMail Bridgeベースのメール集約スタックも稼働。

## ストレージ構成

- pve: LVM-thin(`pve/data`)+ ローカルext4ディスク(`nfs-share`、名前はNFS由来だが実体はローカル)
- バックアップ: OrangePi上のNFS共有(`backup-storage`)へvzdumpで毎日転送
- pve02: LVM-thin、discard/trim対応済み

## 監視・自動化

- **Prometheus + Grafana**: メトリクス収集・可視化
- **n8n**: サービス死活監視(Status Monitor)、UPS異常検知、Telegram通知、アプリのバージョン更新チェック(Native Update Check)

## 定期メンテナンス

- vzdump: 毎日04:00、`keep-daily=3,keep-weekly=2`
- LXCのfstrim: 毎週日曜05:45(`pct-fstrim.timer`)
- マイクラワールドバックアップ: 毎日05:30、30日ロールオーバー、OrangePiへミラー

## 関連リポジトリ

- [mcp](https://github.com/Leucophyllous/mcp) - Claude用MCPサーバー(SSH/Proxmox/OCI/Proton Calendar)
- [manmaru](https://github.com/Leucophyllous/manmaru) - 告知Bot
- [quakebot](https://github.com/Leucophyllous/quakebot) / [everyone-bot](https://github.com/Leucophyllous/everyone-bot) / [rolepanel](https://github.com/Leucophyllous/rolepanel) - Discord Bot群
- [ilust](https://github.com/Leucophyllous/ilust) / [media](https://github.com/Leucophyllous/media)

## 使い方

各 `compose/<host>/*.yaml` はそのまま `docker compose up -d` できる形だが、
`${VAR}` の実値は自分の `.env` を用意すること(`.env.example` を参照)。値そのものはこのリポジトリに含まれない。
