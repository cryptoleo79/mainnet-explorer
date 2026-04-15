# NightForge Website Deployment

## Source → Server Mapping

| Source file | Deployed to | Serves |
|---|---|---|
| `website/nightforge-main.html` | `/var/www/explorer-main/index.html` | nightforge.jp |
| `website/yamori.html` | `/var/www/explorer-main/yamori.html` | nightforge.jp/yamori |
| `website/nightforge-preprod.html` | `/var/www/explorer-preprod/index.html` | preprod.nightforge.jp |
| `website/nightforge-mainnet.html` | `/var/www/explorer-mainnet/index.html` | mainnet.nightforge.jp |

## Nginx Configs

| Source file | Deployed to |
|---|---|
| `website/nginx/nightforge.jp.conf` | `/etc/nginx/sites-enabled/nightforge.jp` |
| `website/nginx/preprod.nightforge.jp.conf` | `/etc/nginx/sites-enabled/preprod.nightforge.jp` |
| `website/nginx/mainnet.nightforge.jp.conf` | `/etc/nginx/sites-enabled/mainnet.nightforge.jp` |

## Deployment Steps

```bash
# Copy static files
sudo cp website/nightforge-main.html /var/www/explorer-main/index.html
sudo cp website/yamori.html /var/www/explorer-main/yamori.html
sudo cp website/nightforge-preprod.html /var/www/explorer-preprod/index.html
sudo cp website/nightforge-mainnet.html /var/www/explorer-mainnet/index.html

# Copy nginx configs (if changed)
sudo cp website/nginx/*.conf /etc/nginx/sites-enabled/
sudo nginx -t && sudo systemctl reload nginx
```

## Notes

- The explorer API backends are separate (Express.js in `src/`)
- Static HTML frontends are hand-maintained, not built from a framework
- nginx proxies `/api/`, `/tools/`, `/ws` to the Express backend
- Static assets (favicon, logos) live in `/var/www/explorer-main/`
