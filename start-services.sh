#!/bin/bash

# 启动脚本 - 使用 .env 文件配置
# 按照正确顺序启动所有服务
# 解决 NATS 授权错误问题

# 进入项目根目录
cd "$(dirname "$0")"

# 加载环境变量
if [ -f ".env" ]; then
    export $(grep -v '^#' .env | xargs)
    echo "✅ 加载环境变量成功"
else
    echo "❌ 未找到 .env 文件"
    exit 1
fi

# 停止所有运行的容器
echo "=== 停止所有运行的容器 ==="
docker stop $(docker ps -q --filter "name=panda-wiki-") 2>/dev/null || echo "没有运行的容器"
docker rm $(docker ps -aq --filter "name=panda-wiki-") 2>/dev/null || echo "没有容器需要删除"

# 创建网络
echo "=== 创建网络 ==="
docker network create --subnet=${SUBNET_PREFIX:-169.254.15}.0/24 panda-wiki 2>/dev/null || echo "网络已存在"

# 1. 启动基础服务
echo "=== 启动基础服务 ==="

# 1.1 启动 PostgreSQL
echo "启动 PostgreSQL..."
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
sleep 8

# 1.2 启动 Redis
echo "启动 Redis..."
docker run -d \
  --name panda-wiki-redis \
  --network panda-wiki \
  --ip ${SUBNET_PREFIX:-169.254.15}.11 \
  -p 6379:6379 \
  -v ./data/redis:/data \
  chaitin-registry.cn-hangzhou.cr.aliyuncs.com/chaitin/panda-wiki-redis:7.4.2-alpine \
  redis-server --requirepass $REDIS_PASSWORD --appendonly yes --appendfilename appendonly.aof --save 900 1 --save 300 10 --save 60 10000

# 等待 Redis 启动
sleep 3

# 1.3 启动 MinIO
echo "启动 MinIO..."
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

# 等待 MinIO 启动
sleep 5

# 1.4 启动 NATS
echo "启动 NATS..."
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
sleep 8

# 1.5 启动 Qdrant
echo "启动 Qdrant..."
docker run -d \
  --name panda-wiki-qdrant \
  --network panda-wiki \
  --ip ${SUBNET_PREFIX:-169.254.15}.14 \
  -p 6333:6333 \
  -v ./data/qdrant:/qdrant/storage \
  -e QDRANT__SERVICE__API_KEY=$QDRANT_API_KEY \
  chaitin-registry.cn-hangzhou.cr.aliyuncs.com/chaitin/panda-wiki-qdrant:v1.14.1

# 等待 Qdrant 启动
sleep 5

# 2. 启动依赖服务
echo "=== 启动依赖服务 ==="

# 2.1 启动 Raglite
echo "启动 Raglite..."
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
sleep 8

# 2.2 启动 Crawler
echo "启动 Crawler..."
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

# 等待 Crawler 启动
sleep 8

# 2.3 启动 API
echo "启动 API..."
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
  chaitin-registry.cn-hangzhou.cr.aliyuncs.com/chaitin/panda-wiki-api:v3.70.0

# 等待 API 启动
sleep 10

# 2.4 启动 Consumer
echo "启动 Consumer..."
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

# 等待 Consumer 启动
sleep 5

# 2.5 启动 Caddy
echo "启动 Caddy..."
docker run -d \
  --name panda-wiki-caddy \
  --restart always \
  --cap-add NET_ADMIN \
  -p 80:80 \
  -p 443:443 \
  -p 2019:2019 \
  -v ./data/caddy/caddy_config:/config \
  -v ./data/caddy/caddy_data:/data \
  -v ./data/caddy/run:/var/run/caddy \
  -e CADDY_ADMIN=unix//var/run/caddy/caddy-admin.sock \
  --network host \
  chaitin-registry.cn-hangzhou.cr.aliyuncs.com/chaitin/panda-wiki-caddy:2.10-alpine

# 等待 Caddy 启动
sleep 3

# 3. 验证服务状态
echo "=== 服务启动完成，验证状态 ==="
sleep 5
docker ps --filter "name=panda-wiki-"

# 4. 检查关键服务日志
echo "=== 检查关键服务日志 ==="
echo "NATS 日志:"
docker logs panda-wiki-nats --tail 10
echo "\nCrawler 日志:"
docker logs panda-wiki-crawler --tail 15

# 5. 总结
echo "\n🎉 所有服务启动完成！"
echo "\n服务访问地址:"
echo "- API: http://localhost:8000"
echo "- Admin: http://localhost:${ADMIN_PORT:-2443}"
echo "- App: http://localhost:3000"
echo "- MinIO: http://localhost:9001"
echo "- NATS: http://localhost:8222"
echo "\n如果遇到 NATS 授权错误，请检查环境变量是否正确加载"
echo "或尝试重新运行此脚本"
