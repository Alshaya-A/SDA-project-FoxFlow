# FoxFlow proactive monitoring

The deployment job installs a systemd timer on the Azure VM when the protected
GitLab variables `TELEGRAM_BOT_TOKEN` and `TELEGRAM_CHAT_ID` are available.

The monitor runs every five minutes and checks:

- GitLab, GitLab Runner, and application containers.
- GitLab and application HTTP health endpoints.
- Root disk usage (warning at 75%, failure at 90%).
- Local GitLab backup freshness (warning after 26 hours, failure after 36).

Telegram receives the initial monitoring result and subsequent state changes.
Healthy checks remain quiet. Recovery messages are sent after warnings or
failures clear. The bot token is stored only in `/etc/foxflow-monitor.env` with
mode `0600`; it is never committed to Git.

Useful commands on the VM:

```bash
systemctl status foxflow-monitor.timer
sudo systemctl start foxflow-monitor.service
sudo journalctl -u foxflow-monitor.service --since today
```
