#!/bin/bash

# 获取当前容器配置信息并生成 nginx 配置文件，使用第三方证书

echo "正在获取容器配置信息并生成 nginx 配置文件..."

# 1. 获取容器信息
echo "1. 获取容器信息..."
CONTAINERS=$(docker ps --format "{{.Names}}")

# 初始化配置变量
APP_PORT="3001"
API_PORT="8000"
MINIO_PORT="9000"
APP_IP=""
API_IP=""
MINIO_IP=""
DOMAIN="www.cryptobtc.xin"

# 证书路径（请将第三方证书放在这些位置）
SSL_CERT="/etc/nginx/ssl/fullchain.pem"
SSL_KEY="/etc/nginx/ssl/privkey.pem"

# 2. 分析容器信息
echo "2. 分析容器信息..."
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

# 3. 使用默认值（如果无法获取 IP）
echo "3. 使用默认值（如果需要）..."
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

# 4. 生成 nginx 配置文件
echo "4. 生成 nginx 配置文件..."
cat > ./data/nginx/nginx.conf << EOF2
upstream backend {
    server $API_IP:$API_PORT;
}

upstream frontend {
    server $APP_IP:$APP_PORT;
}

upstream minio {
    server $MINIO_IP:$MINIO_PORT;
}

server {
    listen 80;
    server_name $DOMAIN localhost;
    
    # 重定向到 HTTPS
    return 301 https://$host$request_uri;
}

server {
    listen 443 ssl http2;
    server_name $DOMAIN localhost;
    
    # 使用第三方证书
    ssl_certificate $SSL_CERT;
    ssl_certificate_key $SSL_KEY;
    
    # SSL 配置
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_prefer_server_ciphers on;
    ssl_ciphers ECDHE-RSA-AES256-GCM-SHA512:DHE-RSA-AES256-GCM-SHA512:ECDHE-RSA-AES256-GCM-SHA384:DHE-RSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-SHA384;
    
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
EOF2

# 5. 创建证书目录
echo "5. 创建证书目录..."
mkdir -p ./data/nginx/ssl
chmod -R 755 ./data/nginx/

# 6. 停止 Caddy 容器
echo "6. 停止 Caddy 容器..."
docker stop panda-wiki-caddy || true
docker rm panda-wiki-caddy || true

# 7. 启动或重启 nginx 容器
echo "7. 启动或重启 nginx 容器..."
docker stop panda-wiki-nginx || true
docker rm panda-wiki-nginx || true

docker run -d \
  --name panda-wiki-nginx \
  --restart always \
  --network host \
  -v ./data/nginx/nginx.conf:/etc/nginx/nginx.conf:ro \
  -v ./data/nginx/ssl:/etc/nginx/ssl:ro \
  nginx:1.25-alpine

# 8. 验证配置
echo "8. 验证配置..."
sleep 5
docker ps -a | grep -E "nginx|caddy"

echo "\n✓ nginx 配置生成完成！"
echo "nginx 容器已启动，替代了 Caddy 容器。"
echo "配置文件位置: ./data/nginx/nginx.conf"
echo "\n服务访问地址:"
echo "- 前端应用: https://$DOMAIN/"
echo "- 后端 API: https://$DOMAIN/api/"
echo "- 本地访问: https://localhost/"
echo "\n重要提示:"
echo "请将您从第三方获取的证书文件放在以下位置："
echo "- 证书文件: ./data/nginx/ssl/fullchain.pem"
echo "- 密钥文件: ./data/nginx/ssl/privkey.pem"
echo "\n如果您的证书文件名不同，请修改脚本中的 SSL_CERT 和 SSL_KEY 变量。"
echo "放置证书后，请重启 nginx 容器："
echo "docker restart panda-wiki-nginx"
