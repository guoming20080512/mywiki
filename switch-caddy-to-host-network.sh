#!/bin/bash

# 将 Caddy 容器切换到 host 网络模式脚本

echo "正在将 Caddy 容器切换到 host 网络模式..."

# 停止并移除现有 Caddy 容器
echo "1. 停止并移除现有 Caddy 容器..."
docker stop panda-wiki-caddy || true
docker rm panda-wiki-caddy || true

# 创建必要的目录
echo "2. 确保必要的目录存在..."
mkdir -p /data/wiki/mywiki/data/caddy/{caddy_config,caddy_data,run}
chmod -R 755 /data/wiki/mywiki/data/caddy/

# 以 host 网络模式重新创建 Caddy 容器
echo "3. 以 host 网络模式创建新的 Caddy 容器..."
docker run -d \
  --name panda-wiki-caddy \
  --restart always \
  --network host \
  --cap-add NET_ADMIN \
  -v ./data/caddy/caddy_config:/config \
  -v ./data/caddy/caddy_data:/data \
  -v ./data/caddy/run:/var/run/caddy \
  -v ./data/caddy/run:/app/run \
  -e CADDY_ADMIN=unix//var/run/caddy/caddy-admin.sock \
  chaitin-registry.cn-hangzhou.cr.aliyuncs.com/chaitin/panda-wiki-caddy:2.10-alpine

# 检查启动状态
echo "4. 检查 Caddy 容器启动状态..."
sleep 3
docker ps -a | grep panda-wiki-caddy

# 查看 Caddy 容器日志
echo "5. 查看 Caddy 容器日志..."
docker logs -f panda-wiki-caddy --tail 50

# 退出脚本
exit 0
