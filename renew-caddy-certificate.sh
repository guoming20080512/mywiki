#!/bin/bash

# 重新获取 Caddy HTTPS 证书脚本

echo "正在重新获取 Caddy HTTPS 证书..."

# 1. 停止 Caddy 容器
echo "1. 停止 Caddy 容器..."
docker stop panda-wiki-caddy || true

# 2. 清理现有证书
echo "2. 清理现有证书..."
CERT_DIR="./data/caddy/caddy_data/certificates"
if [ -d "$CERT_DIR" ]; then
    echo "删除现有证书目录: $CERT_DIR"
    rm -rf "$CERT_DIR"
    mkdir -p "$CERT_DIR"
    chmod -R 755 "$CERT_DIR"
else
    echo "证书目录不存在，跳过清理"
fi

# 3. 清理 ACME 挑战目录
echo "3. 清理 ACME 挑战目录..."
ACME_DIR="./data/caddy/acme-challenge"
if [ -d "$ACME_DIR" ]; then
    rm -rf "$ACME_DIR"/*
else
    mkdir -p "$ACME_DIR"
    chmod -R 755 "$ACME_DIR"
fi

# 4. 重启 Caddy 容器
echo "4. 重启 Caddy 容器..."
docker start panda-wiki-caddy || docker run -d \
  --name panda-wiki-caddy \
  --restart always \
  --network host \
  --cap-add NET_ADMIN \
  -v ./data/caddy/caddy_config:/config \
  -v ./data/caddy/caddy_data:/data \
  -v ./data/caddy/run:/var/run/caddy \
  -v ./data/caddy/run:/app/run \
  -v ./data/caddy/acme-challenge:/var/www/html/.well-known/acme-challenge \
  -e CADDY_ADMIN=unix//var/run/caddy/caddy-admin.sock \
  chaitin-registry.cn-hangzhou.cr.aliyuncs.com/chaitin/panda-wiki-caddy:2.10-alpine

# 5. 验证容器状态
echo "5. 验证 Caddy 容器状态..."
sleep 5
docker ps -a | grep panda-wiki-caddy

# 6. 触发证书申请
echo "6. 触发证书申请..."
# 创建临时文件验证路径
echo "test" > ./data/caddy/acme-challenge/test.txt
# 访问 HTTPS 触发证书申请
curl -k https://www.cryptobtc.xin/ 2>&1 | head -10

# 7. 查看证书申请日志
echo "7. 查看证书申请日志..."
docker logs panda-wiki-caddy --tail 100 | grep -i "certificate\|acme\|https"

echo "证书重新申请完成！请等待 1-2 分钟后，访问 https://www.cryptobtc.xin/ 验证新证书。"
