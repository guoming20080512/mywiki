#!/bin/bash

# 重启 PandaWiki API 容器脚本

echo "正在重启 PandaWiki API 容器..."
  
# 加载环境变量
if [ -f .env ]; then
  echo "正在加载环境变量..."
  export $(cat .env | grep -v '^#' | xargs)
else
  echo "警告: .env 文件不存在，使用默认环境变量"
fi

# 停止并移除 api 容器
echo "1. 停止并移除现有 api 容器..."
docker stop wiki-api || true
docker rm wiki-api || true

# 删除未编译完成的临时文件
echo "2. 清理临时文件..."
# 删除 Docker 构建缓存和临时文件
rm -rf ./backend/output 2>/dev/null || true
# 删除可能的临时编译文件
find ./backend -name "*.tmp" -o -name "*.temp" | xargs rm -f 2>/dev/null || true
# 清理 Go 构建缓存
go clean -cache -modcache 2>/dev/null || true

echo "3. 开始构建 Docker 镜像..."
docker build -t  wiki-api -f ./backend/Dockerfile.api ./backend

# 等待构建完成
sleep 10

docker run -d \
  --name wiki-api \
  --network panda-wiki \
  --ip ${SUBNET_PREFIX:-169.254.15}.2 \
  -p 8000:8000 \
  -v ./data/caddy/run:/app/run \
  -v ./data/nginx/ssl:/app/etc/nginx/ssl \
  -v ./data/conf/api:/data \
  -e NATS_PASSWORD=$NATS_PASSWORD \
  -e POSTGRES_PASSWORD=$POSTGRES_PASSWORD \
  -e REDIS_PASSWORD=$REDIS_PASSWORD \
  -e S3_SECRET_KEY=$S3_SECRET_KEY \
  -e JWT_SECRET=$JWT_SECRET \
  -e ADMIN_PASSWORD=$ADMIN_PASSWORD \
  -e SUBNET_PREFIX=${SUBNET_PREFIX:-169.254.15} \
  wiki-api


# 检查启动状态
echo "4. 检查 api 容器启动状态..."
sleep 3
docker ps -a | grep wiki-api

echo "5. 查看 api 容器日志..."
docker logs -f wiki-api --tail 50

# 退出脚本
exit 0
