#!/bin/bash

# 配置 nginx 反向代理到本地服务

echo "正在配置 nginx 反向代理..."

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
    
    # 前端网站反向代理
    server {
        listen 80 default_server;
        listen [::]:80 default_server;
        server_name www.cryptobtc.xin localhost;
        
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
    }
    
    # Admin 管理后台反向代理
    server {
        listen 2443;
        listen [::]:2443;
        server_name localhost;
        
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
echo "\n✓ nginx 反向代理配置完成！"
echo "\n服务访问地址:"
echo "- 前端网站: http://www.cryptobtc.xin/"
echo "- 前端网站: http://localhost/"
echo "- Admin 管理后台: http://localhost:2443/"
echo "\n配置文件位置: /etc/nginx/nginx.conf"
echo "备份文件位置: /etc/nginx/nginx.conf.bak"
echo "\n反向代理配置:"
echo "- 80 端口 → http://127.0.0.1:3001 (前端网站)"
echo "- 2443 端口 → http://127.0.0.1:2443 (Admin 管理后台)"
