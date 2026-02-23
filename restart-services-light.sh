#!/bin/bash

# 容器用途说明：
# 1. PostgreSQL (panda-wiki-postgres)：关系型数据库，存储系统结构化数据，支持中文全文搜索
# 2. Redis (panda-wiki-redis)：内存缓存数据库，提高系统响应速度，存储会话信息
# 3. MinIO (panda-wiki-minio)：对象存储服务，存储文档文件等非结构化数据
# 4. NATS (panda-wiki-nats)：轻量级消息队列系统，实现组件间异步通信
# 5. Qdrant (panda-wiki-qdrant)：向量数据库，存储文档向量嵌入，支持语义搜索
# 6. Raglite (panda-wiki-raglite)：检索增强生成服务，处理文档向量和检索
# 7. Crawler (panda-wiki-crawler)：文档爬取服务，处理文档内容的抓取和解析
# 8. API (panda-wiki-api)：后端API服务，处理业务逻辑
# 9. Consumer (panda-wiki-consumer)：消息消费者服务，处理异步任务

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

# 3.1 启动 Crawler (panda-wiki-crawler)
docker run -d \
  --name panda-wiki-crawler \
  --network panda-wiki \
  --ip ${SUBNET_PREFIX:-169.254.15}.17 \
  -e GLOG_GLOBAL_LEVEL=info \
  -e NAMESPACE=anydoc \
  -e MQ_NATS_URL=nats://panda-wiki-nats:4222 \
  -e MQ_NATS_USER=panda-wiki \
  -e MQ_NATS_PASSWORD=$NATS_PASSWORD \
  -e OSS_MINIO_ACCESS_KEY=s3panda-wiki \
  -e OSS_MINIO_SECRET_KEY=$S3_SECRET_KEY \
  -e OSS_MINIO_ENDPOINT=panda-wiki-minio:9000 \
  chaitin-registry.cn-hangzhou.cr.aliyuncs.com/chaitin/anydoc:v0.9.6

# 3.2 启动 Raglite
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

# 3.3 启动 Consumer
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

# 3.4 启动 Caddy
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

# 3.5 启动 API
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

# 4. 验证服务状态
echo "=== 服务启动完成，验证状态 ==="
sleep 5
docker ps
