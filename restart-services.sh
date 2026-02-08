#!/bin/bash

# 进入项目根目录
cd "$(dirname "$0")"

# 加载环境变量
export $(grep -v '^#' .env | xargs)

echo "=== 停止所有运行的容器 ==="
# 停止所有容器
docker stop $(docker ps -q --filter "name=panda-wiki-") 2>/dev/null || echo "没有运行的容器"

# 删除所有容器
docker rm $(docker ps -aq --filter "name=panda-wiki-") 2>/dev/null || echo "没有容器需要删除"

echo "=== 开始启动服务 ==="

# 1. 网络准备
docker network create --subnet=${SUBNET_PREFIX:-169.254.15}.0/24 panda-wiki 2>/dev/null || echo "网络已存在"

# 2. 启动基础服务
echo "=== 启动基础服务 ==="

# 2.1 启动 PostgreSQL
docker run -d \
  --name panda-wiki-postgres \
  --network panda-wiki \
  --ip ${SUBNET_PREFIX:-169.254.15}.10 \
  -p 5432:5432 \
  -v ./data/postgres:/var/lib/postgresql/data \
  -e POSTGRES_USER=panda-wiki \
  -e POSTGRES_PASSWORD=$POSTGRES_PASSWORD \
  -e POSTGRES_DB=panda-wiki \
  chaitin-registry.cn-hangzhou.cr.aliyuncs.com/chaitin/postgres-zhparser:17.6-bookworm

# 等待 PostgreSQL 启动
sleep 5

# 2.2 启动 Redis
docker run -d \
  --name panda-wiki-redis \
  --network panda-wiki \
  --ip ${SUBNET_PREFIX:-169.254.15}.11 \
  -p 6379:6379 \
  -v ./data/redis:/data \
  chaitin-registry.cn-hangzhou.cr.aliyuncs.com/chaitin/panda-wiki-redis:7.4.2-alpine \
  redis-server --requirepass $REDIS_PASSWORD --appendonly yes --appendfilename appendonly.aof --save 900 1 --save 300 10 --save 60 10000

# 2.3 启动 MinIO
docker run -d \
  --name panda-wiki-minio \
  --network panda-wiki \
  --ip ${SUBNET_PREFIX:-169.254.15}.12 \
  -p 9000:9000 \
  -p 9001:9001 \
  -v ./data/minio:/data \
  -e MINIO_ACCESS_KEY=s3panda-wiki \
  -e MINIO_SECRET_KEY=$S3_SECRET_KEY \
  chaitin-registry.cn-hangzhou.cr.aliyuncs.com/chaitin/panda-wiki-minio:RELEASE.2025-04-22T22-12-26Z-cpuv1 \
  minio server /data --console-address :9001

# 2.4 启动 NATS
docker run -d \
  --name panda-wiki-nats \
  --network panda-wiki \
  --ip ${SUBNET_PREFIX:-169.254.15}.13 \
  -p 4222:4222 \
  -p 8222:8222 \
  -v ./data/nats:/data \
  chaitin-registry.cn-hangzhou.cr.aliyuncs.com/chaitin/panda-wiki-nats:2.11.3-alpine \
  nats-server -c /etc/nats/nats.conf --user panda-wiki --pass $NATS_PASSWORD

# 等待 NATS 启动
sleep 5

# 2.5 启动 Qdrant
docker run -d \
  --name panda-wiki-qdrant \
  --network panda-wiki \
  --ip ${SUBNET_PREFIX:-169.254.15}.14 \
  -p 6333:6333 \
  -v ./data/qdrant:/qdrant/storage \
  -e QDRANT__SERVICE__API_KEY=$QDRANT_API_KEY \
  chaitin-registry.cn-hangzhou.cr.aliyuncs.com/chaitin/panda-wiki-qdrant:v1.14.1

# 3. 启动依赖服务
echo "=== 启动依赖服务 ==="

# 3.1 启动 Raglite
docker run -d \
  --name panda-wiki-raglite \
  --network panda-wiki \
  --ip ${SUBNET_PREFIX:-169.254.15}.18 \
  -p 8081:8081 \
  -v ./data/raglite:/data \
  -e GIN_MODE=release \
  -e DATABASE_POSTGRESQL_HOST=panda-wiki-postgres \
  -e DATABASE_POSTGRESQL_USER=panda-wiki \
  -e DATABASE_POSTGRESQL_PASSWORD=$POSTGRES_PASSWORD \
  -e DATABASE_QDRANT_HOST=panda-wiki-qdrant \
  -e DATABASE_QDRANT_API_KEY=$QDRANT_API_KEY \
  -e STORAGE_MINIO_ENDPOINT=panda-wiki-minio:9000 \
  -e STORAGE_MINIO_ACCESS_KEY_ID=s3panda-wiki \
  -e STORAGE_MINIO_SECRET_ACCESS_KEY=$S3_SECRET_KEY \
  -e NATS_URL=nats://panda-wiki-nats:4222 \
  -e NATS_USER=panda-wiki \
  -e NATS_PASSWORD=$NATS_PASSWORD \
  chaitin-registry.cn-hangzhou.cr.aliyuncs.com/chaitin/raglite:v2.14.1

# 等待 Raglite 启动
sleep 3

# 3.2 启动 Caddy
docker run -d \
  --name panda-wiki-caddy \
  --network panda-wiki \
  --ip ${SUBNET_PREFIX:-169.254.15}.5 \
  --cap-add NET_ADMIN \
  -p 80:80 \
  -p 443:443 \
  -p 2019:2019 \
  -v ./data/caddy/caddy_config:/config \
  -v ./data/caddy/caddy_data:/data \
  -v ./data/caddy/run:/var/run/caddy \
  -e CADDY_ADMIN=unix//var/run/caddy/caddy-admin.sock \
  chaitin-registry.cn-hangzhou.cr.aliyuncs.com/chaitin/panda-wiki-caddy:2.10-alpine

# 等待 Caddy 启动
sleep 3

# 4. 启动核心服务
echo "=== 启动核心服务 ==="

# 4.1 启动 API 服务（本地构建）
docker build -t panda-wiki-api -f ./backend/Dockerfile.api ./backend

# 等待构建完成
sleep 10

docker run -d \
  --name panda-wiki-api \
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
  panda-wiki-api

# 等待 API 启动
sleep 5

# 4.2 启动 Consumer
docker run -d \
  --name panda-wiki-consumer \
  --network panda-wiki \
  --ip ${SUBNET_PREFIX:-169.254.15}.3 \
  -e NATS_PASSWORD=$NATS_PASSWORD \
  -e POSTGRES_PASSWORD=$POSTGRES_PASSWORD \
  -e REDIS_PASSWORD=$REDIS_PASSWORD \
  -e S3_SECRET_KEY=$S3_SECRET_KEY \
  -e JWT_SECRET=$JWT_SECRET \
  -e SUBNET_PREFIX=${SUBNET_PREFIX:-169.254.15} \
  chaitin-registry.cn-hangzhou.cr.aliyuncs.com/chaitin/panda-wiki-consumer:v3.70.0

# 4.3 启动 Crawler
docker run -d \
  --name panda-wiki-crawler \
  --network panda-wiki \
  --ip ${SUBNET_PREFIX:-169.254.15}.17 \
  --init \
  -e GLOG_GLOBAL_LEVEL=info \
  -e NAMESPACE=anydoc \
  -e MQ_NATS_URL=nats://panda-wiki-nats:4222 \
  -e MQ_NATS_USER=panda-wiki \
  -e MQ_NATS_PASSWORD=$NATS_PASSWORD \
  -e OSS_MINIO_ACCESS_KEY=s3panda-wiki \
  -e OSS_MINIO_SECRET_KEY=$S3_SECRET_KEY \
  -e OSS_MINIO_ENDPOINT=panda-wiki-minio:9000 \
  chaitin-registry.cn-hangzhou.cr.aliyuncs.com/chaitin/anydoc:v0.9.6

# 5. 启动前端服务
echo "=== 启动前端服务 ==="

# 5.1 构建前端应用
cd ./web && NODE_OPTIONS="--max-old-space-size=8192" pnpm build

# 等待构建完成
sleep 20

# 5.2 构建并启动 App 服务
cd ./app && docker build -t panda-wiki-app .

# 等待构建完成
sleep 15

cd .. && docker run -d \
  --name panda-wiki-app \
  --network panda-wiki \
  --ip ${SUBNET_PREFIX:-169.254.15}.112 \
  -p 3001:3010 \
  panda-wiki-app

# 5.3 构建并启动 Nginx 服务
cd ./admin && docker build -t panda-wiki-nginx .

# 等待构建完成
sleep 10

cd ../.. && docker run -d \
  --name panda-wiki-nginx \
  --network panda-wiki \
  --ip ${SUBNET_PREFIX:-169.254.15}.111 \
  -p 2443:8080 \
  -v ./data/nginx/ssl:/etc/nginx/ssl \
  panda-wiki-nginx

# 6. 验证服务状态
echo "=== 服务启动完成，验证状态 ==="
sleep 5
docker ps