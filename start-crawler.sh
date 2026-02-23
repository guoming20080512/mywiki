#!/bin/bash

# 启动 Crawler 服务脚本
# 使用 .env 文件中的环境变量配置

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

# 停止并移除现有的 Crawler 容器
echo "=== 停止并移除现有的 Crawler 容器 ==="
docker stop panda-wiki-crawler 2>/dev/null || echo "Crawler 容器未运行"
docker rm panda-wiki-crawler 2>/dev/null || echo "Crawler 容器不存在"

# 确保网络存在
echo "=== 确保网络存在 ==="
docker network create --subnet=${SUBNET_PREFIX:-169.254.15}.0/24 panda-wiki 2>/dev/null || echo "网络已存在"

# 启动 Crawler 服务
echo "=== 启动 Crawler 服务 ==="
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

# 等待 Crawler 启动
sleep 5

# 验证服务状态
echo "=== 服务启动完成，验证状态 ==="
docker ps --filter "name=panda-wiki-crawler"

# 检查 Crawler 日志
echo "=== 检查 Crawler 日志 ==="
docker logs panda-wiki-crawler --tail 15

echo "\n🎉 Crawler 服务启动完成！"
