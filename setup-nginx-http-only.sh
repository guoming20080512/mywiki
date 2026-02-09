#!/bin/bash

# 配置 Nginx 只使用 80 端口（HTTP），移除 HTTPS 配置

echo "正在配置 Nginx 只使用 80 端口..."

# 1. 备份当前配置
echo "1. 备份当前配置..."
sudo cp /etc/nginx/nginx.conf /etc/nginx/nginx.conf.bak

# 2. 生成新的 HTTP 配置
echo "2. 生成新的 HTTP 配置..."
sudo cat > /etc/nginx/nginx.conf << 'EOF2'
user www-data;
worker_processes auto;
pid /run/nginx.pid;
include /etc/nginx/modules-enabled/*.conf;

events {
    worker_connections 768;
}

http {
    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 65;
    types_hash_max_size 2048;
    
    include /etc/nginx/mime.types;
    default_type application/octet-stream;
    
    access_log /var/log/nginx/access.log;
    error_log /var/log/nginx/error.log;
    
    gzip on;
    
    # 上游服务器配置
    upstream backend {
        server 169.254.15.2:8000;
    }
    
    upstream frontend {
        server 169.254.15.112:3001;
    }
    
    upstream minio {
        server 169.254.15.12:9000;
    }
    
    # HTTP 服务器（仅使用 80 端口）
    server {
        listen 80 default_server;
        listen [::]:80 default_server;
        server_name www.cryptobtc.xin localhost;
        
        # 前端应用代理
        location / {
            proxy_pass http://frontend;
            proxy_http_version 1.1;
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection "upgrade";
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
            proxy_cache_bypass $http_upgrade;
        }
        
        # 后端 API 代理
        location ~ ^/api {
            proxy_pass http://backend;
            proxy_http_version 1.1;
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection "upgrade";
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
            proxy_cache_bypass $http_upgrade;
        }
        
        # 静态文件服务代理
        location ~ ^/static-file/ {
            proxy_pass http://minio;
            proxy_http_version 1.1;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
            
            # 对于非 PDF 文件，添加下载头
            if ($request_uri !~* \.pdf$) {
                add_header Content-Disposition "attachment" always;
            }
        }
        
        # 聊天消息代理（需要特殊配置）
        location ~ ^/(share/v1/chat/message|api/v1/creation/text) {
            proxy_pass http://backend;
            proxy_http_version 1.1;
            chunked_transfer_encoding off;
            proxy_buffering off;
            proxy_cache off;
            proxy_read_timeout 24h;
            proxy_send_timeout 24h;
            
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
        }
        
        # 文件上传代理（需要大文件支持）
        location = /api/v1/file/upload {
            proxy_pass http://backend;
            client_max_body_size 1000m;
            
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
        }
    }
}
EOF2

# 3. 检查配置语法
echo "3. 检查配置语法..."
sudo nginx -t

# 4. 重启 Nginx 服务
echo "4. 重启 Nginx 服务..."
sudo systemctl restart nginx

# 5. 验证服务状态
echo "5. 验证服务状态..."
sudo systemctl status nginx --no-pager | head -30

# 6. 测试 HTTP 访问
echo "6. 测试 HTTP 访问..."
curl -v http://localhost/ 2>&1 | head -20

echo "\n✓ Nginx HTTP 配置完成！"
echo "Nginx 现在只使用 80 端口（HTTP），已移除 HTTPS 配置。"
echo "\n服务访问地址:"
echo "- 前端应用: http://www.cryptobtc.xin/"
echo "- 后端 API: http://www.cryptobtc.xin/api/"
echo "- 本地访问: http://localhost/"
echo "\n配置文件位置: /etc/nginx/nginx.conf"
echo "备份文件位置: /etc/nginx/nginx.conf.bak"
