#!/bin/bash

# 在宿主机上安装 nginx 并配置为代理前端和后端服务

echo "正在宿主机上安装和配置 nginx..."

# 1. 安装 nginx
echo "1. 安装 nginx..."
if command -v apt &> /dev/null; then
    sudo apt update && sudo apt install -y nginx
elif command -v yum &> /dev/null; then
    sudo yum install -y nginx
elif command -v dnf &> /dev/null; then
    sudo dnf install -y nginx
else
    echo "无法自动安装 nginx，请手动安装"
    exit 1
fi

# 2. 创建必要的目录
echo "2. 创建必要的目录..."
sudo mkdir -p /etc/nginx/ssl
sudo mkdir -p /var/log/nginx
sudo chmod -R 755 /etc/nginx/

# 3. 获取容器信息（用于配置代理）
echo "3. 获取容器信息..."
CONTAINERS=$(docker ps --format "{{.Names}}")

# 初始化配置变量
APP_PORT="3001"
API_PORT="8000"
MINIO_PORT="9000"
APP_IP=""
API_IP=""
MINIO_IP=""
DOMAIN="www.cryptobtc.xin"

# 4. 分析容器信息
echo "4. 分析容器信息..."
for container in $CONTAINERS; do
    echo "  分析容器: $container"
    
    # 获取容器的网络信息
    NETWORK_INFO=$(docker inspect --format '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' $container 2>/dev/null)
    
    case "$container" in
        "panda-wiki-app")
            APP_IP="$NETWORK_INFO"
            echo "    前端应用 IP: $APP_IP"
            ;;
        "panda-wiki-api")
            API_IP="$NETWORK_INFO"
            echo "    后端 API IP: $API_IP"
            ;;
        "panda-wiki-minio")
            MINIO_IP="$NETWORK_INFO"
            echo "    MinIO IP: $MINIO_IP"
            ;;
    esac
done

# 5. 使用默认值（如果无法获取 IP）
echo "5. 使用默认值（如果需要）..."
if [ -z "$APP_IP" ]; then
    APP_IP="169.254.15.112"
    echo "    使用默认前端应用 IP: $APP_IP"
fi

if [ -z "$API_IP" ]; then
    API_IP="169.254.15.2"
    echo "    使用默认后端 API IP: $API_IP"
fi

if [ -z "$MINIO_IP" ]; then
    MINIO_IP="169.254.15.12"
    echo "    使用默认 MinIO IP: $MINIO_IP"
fi

# 6. 生成 nginx 配置文件
echo "6. 生成 nginx 配置文件..."
sudo cat > /etc/nginx/nginx.conf << EOF2
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
        server $API_IP:$API_PORT;
    }
    
    upstream frontend {
        server $APP_IP:$APP_PORT;
    }
    
    upstream minio {
        server $MINIO_IP:$MINIO_PORT;
    }
    
    # HTTP 服务器（重定向到 HTTPS）
    server {
        listen 80 default_server;
        listen [::]:80 default_server;
        server_name $DOMAIN localhost;
        
        return 301 https://$host$request_uri;
    }
    
    # HTTPS 服务器
    server {
        listen 443 ssl http2 default_server;
        listen [::]:443 ssl http2 default_server;
        server_name $DOMAIN localhost;
        
        # 使用第三方证书
        ssl_certificate /etc/nginx/ssl/fullchain.pem;
        ssl_certificate_key /etc/nginx/ssl/privkey.pem;
        
        # SSL 配置
        ssl_protocols TLSv1.2 TLSv1.3;
        ssl_prefer_server_ciphers on;
        ssl_ciphers ECDHE-RSA-AES256-GCM-SHA512:DHE-RSA-AES256-GCM-SHA512:ECDHE-RSA-AES256-GCM-SHA384:DHE-RSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-SHA384;
        ssl_session_timeout 1d;
        ssl_session_cache shared:SSL:10m;
        ssl_session_tickets off;
        
        # 前端应用代理
        location / {
            proxy_pass http://frontend;
            proxy_http_version 1.1;
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection 'upgrade';
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
            proxy_set_header Connection 'upgrade';
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

# 7. 停止并移除容器化的 nginx 和 Caddy
echo "7. 停止并移除容器化的 nginx 和 Caddy..."
docker stop panda-wiki-nginx panda-wiki-caddy || true
docker rm panda-wiki-nginx panda-wiki-caddy || true

# 8. 启动并启用宿主机 nginx 服务
echo "8. 启动并启用宿主机 nginx 服务..."
sudo systemctl restart nginx
sudo systemctl enable nginx

# 9. 验证 nginx 服务状态
echo "9. 验证 nginx 服务状态..."
sudo systemctl status nginx --no-pager | head -30

echo "\n✓ 宿主机 nginx 配置完成！"
echo "nginx 服务已在宿主机上安装并运行，替代了容器化的 nginx 和 Caddy。"
echo "\n服务访问地址:"
echo "- 前端应用: https://$DOMAIN/"
echo "- 后端 API: https://$DOMAIN/api/"
echo "- 本地访问: https://localhost/"
echo "\n重要提示:"
echo "请将您从第三方获取的证书文件放在以下位置："
echo "- 证书文件: /etc/nginx/ssl/fullchain.pem"
echo "- 密钥文件: /etc/nginx/ssl/privkey.pem"
echo "\n放置证书后，请重启 nginx 服务："
echo "sudo systemctl restart nginx"
echo "\n如果需要修改配置，请编辑：/etc/nginx/nginx.conf"
