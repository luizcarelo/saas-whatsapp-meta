# Nginx bot.lhsolucao.com.br

## Visao geral

Este documento registra a configuracao do Nginx para o dominio bot.lhsolucao.com.br.

## Resultado

Status:

    concluido

## Dominio configurado

Dominio:

    bot.lhsolucao.com.br

## Arquivo alterado

Arquivo:

    /etc/nginx/sites-available/bot.lhsolucao.com.br

## Link ativo

Link:

    /etc/nginx/sites-enabled/bot.lhsolucao.com.br

## Backup criado

Backup:

    /home/luizcarelo/saas-whatsapp-meta/backups/nginx_bot_lhsolucao_20260708_220340.conf.bak

## Rollback

Script:

    /home/luizcarelo/saas-whatsapp-meta/scripts/rollback_nginx_bot_lhsolucao_20260708_220340.sh

## Destino do proxy

Destino:

    http://127.0.0.1:8180

## SSL

Certificados mantidos:

    /etc/letsencrypt/live/bot.lhsolucao.com.br/fullchain.pem
    /etc/letsencrypt/live/bot.lhsolucao.com.br/privkey.pem

## Configuracoes preservadas

A etapa nao alterou os demais arquivos do Nginx.

Nao foram alterados:

- rh_lhsolucao.conf
- lhsolucao.com.br.conf
- gestao
- mobile-dev.conf

## Validacoes executadas

Validacoes:

- backup criado
- nginx -t executado com sucesso
- nginx recarregado apos validacao

## Proxima etapa sugerida

Etapa 20C:

    Subir containers e testar acesso pelo dominio
