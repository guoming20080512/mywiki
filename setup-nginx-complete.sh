#!/bin/bash

# 配置 nginx 反向代理，参考项目现有配置文件

echo "正在配置 nginx 反向代理，参考项目现有配置文件..."

# 1. 备份当前配置
echo "1. 备份当前配置..."
sudo cp /etc/nginx/nginx.conf /etc/nginx/nginx.conf.bak 2>/dev/null || true

# 2. 创建新的 nginx 配置
echo "2. 创建新的 nginx 配置..."
sudo cat > /etc/nginx/nginx.conf << 'EOF'
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
    
upstream backend {
    server 127.0.0.1:8000;
}

# 前端网站反向代理
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    server_name www.cryptobtc.xin;
    charset utf-8;
       
    # 聊天消息代理（需要特殊配置）
    location ~ ^/(share/v1/chat/message|api/v1/creation/text) {
        proxy_set_header Connection '';
        proxy_http_version 1.1;
        chunked_transfer_encoding off;
        proxy_buffering off;
        proxy_cache off;

        proxy_read_timeout 24h;
        proxy_send_timeout 24h;

        # Forward client information
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header Host $http_host;

        proxy_pass http://backend;
    }
    
    # 文件上传代理（需要大文件支持）
    location = /api/v1/file/upload {
        proxy_pass http://backend;

        client_max_body_size 1000m;

        # Forward client information
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header Host $http_host;
    }
    
    # API 代理
    location ~ ^/api {
        proxy_pass http://backend;

        client_max_body_size 1000m;

        # Forward client information
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header Host $http_host;
    }
    
    # 分享 API 代理
    location ~ ^/share {
        proxy_pass http://backend;

        # Forward client information
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header Host $http_host;
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
        proxy_set_header Host $http_host;

        proxy_cache off;
        proxy_buffering off;
    }

     location / {
        root /data/wiki/mywiki/web/app/dist;
        index index.html index.htm;
        try_files $uri $uri/ $uri.html /index.html;
        if ($request_filename ~* .*\.(htm|html)$) {
            add_header Cache-Control "no-cache";
        }
    }
}
    
# Admin 管理后台反向代理
server {
    listen 2443;
    listen [::]:2443;
    server_name superme.cryptobtc.xin;
    charset utf-8;
    
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
    
    # 聊天消息代理（需要特殊配置）
    location ~ ^/(share/v1/chat/message|api/v1/creation/text) {
        proxy_set_header Connection '';
        proxy_http_version 1.1;
        chunked_transfer_encoding off;
        proxy_buffering off;
        proxy_cache off;

        proxy_read_timeout 24h;
        proxy_send_timeout 24h;

        # Forward client information
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header Host $http_host;

        proxy_pass http://backend;
    }
    
    # 文件上传代理（需要大文件支持）
    location = /api/v1/file/upload {
        proxy_pass http://backend;

        client_max_body_size 1000m;

        # Forward client information
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header Host $http_host;
    }
    
    # Admin API 代理
    location ~ ^/api {
        proxy_pass http://backend;

        client_max_body_size 1000m;

        # Forward client information
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header Host $http_host;
    }
    
    # Admin 分享 API 代理
    location ~ ^/share {
        proxy_pass http://backend;

        # Forward client information
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header Host $http_host;
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
        proxy_set_header Host $http_host;

        proxy_cache off;
        proxy_buffering off;
    }
}
}
EOF

# 3. 创建必要的目录
echo "3. 创建必要的目录..."
sudo mkdir -p /etc/nginx/modules-enabled

# 4. 检查配置语法
echo "4. 检查配置语法..."
sudo nginx -t

# 5. 重启 nginx 服务
echo "5. 重启 nginx 服务..."
sudo systemctl restart nginx 2>/dev/null || sudo service nginx restart

# 6. 验证服务状态
echo "6. 验证服务状态..."
sudo systemctl status nginx --no-pager 2>/dev/null || sudo service nginx status

# 7. 测试访问
echo "7. 测试访问..."
curl -v http://localhost/ 2>&1 | head -20

# 8. 显示配置信息
echo "\n✓ nginx 完整配置完成！"
echo "参考了项目中的配置文件，包含了所有必要的代理规则。"
echo "\n服务访问地址:"
echo "- 前端网站: http://www.cryptobtc.xin/"
echo "- Admin 管理后台: http://superme.cryptobtc.xin:2443/"
echo "\n反向代理配置:"
echo "- 80 端口 → http://127.0.0.1:3001 (前端网站)"
echo "- 2443 端口 → http://127.0.0.1:2443 (Admin 管理后台)"
echo "- API 请求 → http://127.0.0.1:8000 (后端 API)"
echo "- 静态文件 → http://127.0.0.1:9000 (MinIO)"
echo "\n域名配置:"
echo "- 前端网站域名: www.cryptobtc.xin"
echo "- Admin 管理后台域名: superme.cryptobtc.xin"
echo "\n配置文件位置: /etc/nginx/nginx.conf"
echo "备份文件位置: /etc/nginx/nginx.conf.bak"
