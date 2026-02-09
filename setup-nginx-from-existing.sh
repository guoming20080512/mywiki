#!/bin/bash

# 基于项目现有配置文件设置 nginx

echo "正在基于项目现有配置文件设置 nginx..."

# 1. 备份当前配置
echo "1. 备份当前配置..."
sudo cp /etc/nginx/nginx.conf /etc/nginx/nginx.conf.bak 2>/dev/null || true

# 2. 创建主配置文件（基于项目的 nginx.conf）
echo "2. 创建主配置文件..."
sudo cat > /etc/nginx/nginx.conf << 'EOF2'
user www-data;
worker_processes auto;
pid /run/nginx.pid;
include /etc/nginx/modules-enabled/*.conf;

events {
    worker_connections 1024;
}

http {
    include /etc/nginx/mime.types;
    default_type application/octet-stream;

    log_format main '$remote_addr - $remote_user [$time_local] "$request" '
    '$status $body_bytes_sent "$http_referer" '
    '"$http_user_agent" "$http_x_forwarded_for"';

    access_log /var/log/nginx/access.log main;

    sendfile on;
    keepalive_timeout 65;
    gzip on;
    
    # 包含服务器配置
    include /etc/nginx/conf.d/*.conf;
}
EOF2

# 3. 创建 conf.d 目录
echo "3. 创建 conf.d 目录..."
sudo mkdir -p /etc/nginx/conf.d

# 4. 创建服务器配置文件（基于项目的 server.conf）
echo "4. 创建服务器配置文件..."
sudo cat > /etc/nginx/conf.d/server.conf << 'EOF3'
# 前端网站服务器
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    server_name www.cryptobtc.xin;
    charset utf-8;
    
    # 前端应用代理
    location / {
        proxy_pass http://127.0.0.1:3001;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
    }
    
    # 文件上传代理
    location = /api/v1/file/upload {
        proxy_pass http://127.0.0.1:8000;
        client_max_body_size 1000m;
        
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header Host $host;
    }
    
    # API 代理
    location ~ ^/api {
        proxy_pass http://127.0.0.1:8000;
        client_max_body_size 1000m;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
    
    # 分享 API 代理
    location ~ ^/share {
        proxy_pass http://127.0.0.1:8000;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
    
    # 静态文件代理
    location ~ ^/static-file/ {
        proxy_pass http://127.0.0.1:9000;
        proxy_connect_timeout 300;
        proxy_send_timeout 300;
        proxy_read_timeout 300;
        send_timeout 300;
        client_max_body_size 1000m;
        
        if ($request_uri !~* \.pdf$) {
            add_header Content-Disposition "attachment" always;
        }
        
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header Host $host;
        
        proxy_cache off;
        proxy_buffering off;
    }
    
    # 聊天消息代理
    location ~ ^/(share/v1/chat/message|api/v1/creation/text) {
        proxy_pass http://127.0.0.1:8000;
        proxy_http_version 1.1;
        chunked_transfer_encoding off;
        proxy_buffering off;
        proxy_cache off;
        proxy_read_timeout 24h;
        proxy_send_timeout 24h;
        
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header Host $host;
    }
}

# Admin 管理后台服务器
server {
    listen 2443;
    listen [::]:2443;
    server_name superme.cryptobtc.xin;
    charset utf-8;
    
    # Admin 应用代理
    location / {
        proxy_pass http://127.0.0.1:2443;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
    }
    
    # Admin 文件上传代理
    location = /api/v1/file/upload {
        proxy_pass http://127.0.0.1:8000;
        client_max_body_size 1000m;
        
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header Host $host;
    }
    
    # Admin API 代理
    location ~ ^/api {
        proxy_pass http://127.0.0.1:8000;
        client_max_body_size 1000m;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
    
    # Admin 分享 API 代理
    location ~ ^/share {
        proxy_pass http://127.0.0.1:8000;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
EOF3

# 5. 创建必要的目录
echo "5. 创建必要的目录..."
sudo mkdir -p /etc/nginx/modules-enabled

# 6. 检查配置语法
echo "6. 检查配置语法..."
sudo nginx -t

# 7. 重启 nginx 服务
echo "7. 重启 nginx 服务..."
sudo systemctl restart nginx 2>/dev/null || sudo service nginx restart

# 8. 验证服务状态
echo "8. 验证服务状态..."
sudo systemctl status nginx --no-pager 2>/dev/null || sudo service nginx status

echo "\n✓ 基于现有配置的 nginx 设置完成！"
echo "配置基于项目中的 nginx.conf 和 server.conf 文件，并进行了必要的修改以适应宿主机环境。"
echo "\n服务访问地址:"
echo "- 前端网站: http://www.cryptobtc.xin/"
echo "- Admin 管理后台: http://superme.cryptobtc.xin:2443/"
echo "\n配置文件位置:"
echo "- 主配置: /etc/nginx/nginx.conf"
echo "- 服务器配置: /etc/nginx/conf.d/server.conf"
