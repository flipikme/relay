#!/bin/bash

# Запрос реального IP-адреса сервера
read -p "Введите реальный IP-адрес вашего сервера: " REAL_IP

# Проверка, что IP-адрес введён
if [[ -z "$REAL_IP" ]]; then
    echo "Вы не ввели IP-адрес. Скрипт остановлен."
    exit 1
fi

# Обновление системы
echo "Обновление системы..."
sudo apt update && sudo apt upgrade -y

# Установка NGINX и Certbot
echo "Установка NGINX и Certbot..."
sudo apt install -y nginx certbot python3-certbot-nginx

# Запуск и включение NGINX
echo "Запуск и включение NGINX..."
sudo systemctl enable --now nginx

# Создание конфигурации NGINX для релей-сервера
echo "Создание конфигурации NGINX..."
cat <<EOL | sudo tee /etc/nginx/sites-available/reverse-proxy
server {
    listen 80;
    server_name flipik.me www.flipik.me;

    location / {
        proxy_pass http://$REAL_IP; # Реальный IP сервера
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    }
}
EOL

# Активация конфигурации
echo "Активация конфигурации..."
sudo ln -s /etc/nginx/sites-available/reverse-proxy /etc/nginx/sites-enabled/
sudo nginx -t && sudo systemctl reload nginx

# Получение SSL-сертификатов
echo "Запуск Certbot для получения SSL-сертификатов..."
sudo certbot --nginx -d flipik.me -d www.flipik.me

# Обновление конфигурации NGINX для HTTPS
echo "Обновление конфигурации NGINX для HTTPS..."
cat <<EOL | sudo tee /etc/nginx/sites-available/reverse-proxy
# Перенаправление HTTP на HTTPS
server {
    listen 80;
    server_name flipik.me www.flipik.me;

    return 301 https://\$host\$request_uri;
}

# HTTPS-сервер
server {
    listen 443 ssl;
    server_name flipik.me www.flipik.me;

    # SSL-сертификаты Let's Encrypt
    ssl_certificate /etc/letsencrypt/live/flipik.me/fullchain.pem; # managed by Certbot
    ssl_certificate_key /etc/letsencrypt/live/flipik.me/privkey.pem; # managed by Certbot
    include /etc/letsencrypt/options-ssl-nginx.conf; # managed by Certbot
    ssl_dhparam /etc/letsencrypt/ssl-dhparams.pem; # managed by Certbot

    # Основной прокси
    location / {
        proxy_pass http://$REAL_IP; # Реальный IP сервера
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    }
}
EOL

# Перезагрузка NGINX
echo "Перезагрузка NGINX..."
sudo nginx -t && sudo systemctl reload nginx

echo "Настройка релей-сервера завершена! Реальный сервер проксируется через $REAL_IP."
