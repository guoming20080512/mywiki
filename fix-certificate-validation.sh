#!/bin/bash

# 修复 Certbot 验证失败问题脚本

DOMAIN="www.cryptobtc.xin"
WEBROOT="/data/wiki/mywiki/data/caddy/webroot"
CERT_DIR="/data/wiki/mywiki/data/caddy/certificates"

echo "正在修复 Certbot 验证失败问题..."

# 1. 停止 Caddy 容器
echo "1. 停止 Caddy 容器..."
docker stop panda-wiki-caddy || true
docker rm panda-wiki-caddy || true

# 2. 清理并创建必要的目录
echo "2. 清理并创建必要的目录..."
rm -rf "$WEBROOT"
mkdir -p "$WEBROOT/.well-known/acme-challenge"
mkdir -p "$CERT_DIR"
chmod -R 755 "$WEBROOT"
chmod -R 755 "$CERT_DIR"

# 3. 创建临时测试文件
echo "3. 创建临时测试文件..."
TEST_CONTENT="test-$(date +%s)"
echo "$TEST_CONTENT" > "$WEBROOT/.well-known/acme-challenge/test.txt"
TEST_URL="http://$DOMAIN/.well-known/acme-challenge/test.txt"
echo "测试文件已创建：$TEST_URL"
echo "预期内容：$TEST_CONTENT"

# 4. 启动临时 HTTP 服务器用于验证
echo "4. 启动临时 HTTP 服务器..."
# 使用 Python 或 Node.js 启动简单的 HTTP 服务器
if command -v python3 &> /dev/null; then
    cd "$WEBROOT" && python3 -m http.server 80 &
    HTTP_SERVER_PID=$!
    echo "临时 HTTP 服务器已启动（PID: $HTTP_SERVER_PID）"
elif command -v python &> /dev/null; then
    cd "$WEBROOT" && python -m SimpleHTTPServer 80 &
    HTTP_SERVER_PID=$!
    echo "临时 HTTP 服务器已启动（PID: $HTTP_SERVER_PID）"
elif command -v node &> /dev/null; then
    cd "$WEBROOT" && npx http-server -p 80 -c-1 &
    HTTP_SERVER_PID=$!
    echo "临时 HTTP 服务器已启动（PID: $HTTP_SERVER_PID）"
else
    echo "无法启动临时 HTTP 服务器，请手动启动一个 HTTP 服务器在 $WEBROOT 目录的 80 端口"
    exit 1
fi

# 5. 等待服务器启动
sleep 3

# 6. 测试验证文件可访问性
echo "6. 测试验证文件可访问性..."
curl -v "$TEST_URL" 2>&1

# 7. 尝试获取证书
echo "7. 尝试获取证书..."
sudo certbot certonly \
  --webroot \
  -w "$WEBROOT" \
  -d "$DOMAIN" \
  --email guoming20080512@outlook.com \
  --agree-tos \
  --non-interactive \
  --config-dir "$CERT_DIR" \
  --work-dir "$CERT_DIR/work" \
  --logs-dir "$CERT_DIR/logs"

# 8. 停止临时 HTTP 服务器
echo "8. 停止临时 HTTP 服务器..."
kill "$HTTP_SERVER_PID" 2>/dev/null || true

# 9. 检查证书是否成功获取
echo "9. 检查证书是否成功获取..."
if [ -f "$CERT_DIR/live/$DOMAIN/fullchain.pem" ] && [ -f "$CERT_DIR/live/$DOMAIN/privkey.pem" ]; then
    echo "✓ 证书获取成功！"
    
    # 10. 重新启动 Caddy 容器
    echo "10. 重新启动 Caddy 容器..."
    docker run -d \
      --name panda-wiki-caddy \
      --restart always \
      --network host \
      --cap-add NET_ADMIN \
      -v ./data/caddy/caddy_config:/config \
      -v ./data/caddy/caddy_data:/data \
      -v ./data/caddy/run:/var/run/caddy \
      -v ./data/caddy/run:/app/run \
      -v "$WEBROOT":/var/www/html \
      chaitin-registry.cn-hangzhou.cr.aliyuncs.com/chaitin/panda-wiki-caddy:2.10-alpine
    
    echo "✓ 证书获取和配置完成！请访问 https://$DOMAIN 验证新证书。"
else
    echo "✗ 证书获取失败！请检查以下问题："
    echo "1. 确保 80 端口可从外部访问"
    echo "2. 确保域名正确指向服务器 IP"
    echo "3. 确保临时 HTTP 服务器正常运行"
    echo "4. 查看详细日志：$CERT_DIR/logs/letsencrypt.log"
fi
