#!/bin/bash

# 重启 PandaWiki API 容器脚本

echo "正在重启 PandaWiki API 容器..."

# 停止并移除 api 容器
echo "1. 停止并移除现有 api 容器..."
docker stop panda-wiki-api || true
docker rm panda-wiki-api || true

# 重新构建 api 容器
echo "2. 重新构建 api 容器..."
docker-compose -f docker compose.yml build api

# 启动 api 容器
echo "3. 启动 api 容器..."
docker-compose -f docker compose.yml up -d api

# 检查启动状态
echo "4. 检查 api 容器启动状态..."
sleep 3
docker ps -a | grep panda-wiki-api

echo "5. 查看 api 容器日志..."
docker logs -f panda-wiki-api --tail 50

# 退出脚本
exit 0
