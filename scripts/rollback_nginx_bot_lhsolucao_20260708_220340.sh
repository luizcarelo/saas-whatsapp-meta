#!/usr/bin/env bash
set -euo pipefail

echo "== Rollback Nginx bot.lhsolucao.com.br =="

sudo cp "/home/luizcarelo/saas-whatsapp-meta/backups/nginx_bot_lhsolucao_20260708_220340.conf.bak" "/etc/nginx/sites-available/bot.lhsolucao.com.br"

if [ ! -L "/etc/nginx/sites-enabled/bot.lhsolucao.com.br" ]; then
  sudo ln -s "/etc/nginx/sites-available/bot.lhsolucao.com.br" "/etc/nginx/sites-enabled/bot.lhsolucao.com.br"
fi

sudo nginx -t
sudo systemctl reload nginx

echo "Rollback concluido."
