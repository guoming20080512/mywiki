#!/bin/bash

# 配置 Caddy 自动 HTTPS 和证书管理脚本

echo "正在配置 Caddy 自动 HTTPS 和证书管理..."

# 1. 停止并移除现有 Caddy 容器
echo "1. 停止并移除现有 Caddy 容器..."
docker stop panda-wiki-caddy || true
docker rm panda-wiki-caddy || true

# 2. 清理现有配置和证书
echo "2. 清理现有配置和证书..."
rm -rf ./data/caddy/caddy_config/*
rm -rf ./data/caddy/caddy_data/certificates/*
mkdir -p ./data/caddy/{caddy_config,caddy_data,run}
chmod -R 755 ./data/caddy/

# 3. 创建 Caddyfile 配置模板
echo "3. 创建 Caddyfile 配置模板..."
cat > ./data/caddy/caddy_config/Caddyfile << 'EOF2'
{
    # 启用自动 HTTPS
    auto_https {
        disable_redirects false
        disable_certs false
    }
    
    # 配置管理接口
    admin unix//var/run/caddy/caddy-admin.sock
}

# 这个配置会被后端 API 动态更新
# 当在 Admin 中修改域名和端口设置时
# 后端会自动同步配置到 Caddy
EOF2

# 4. 以 host 网络模式启动 Caddy 容器
echo "4. 以 host 网络模式启动 Caddy 容器..."
docker run -d \
  --name panda-wiki-caddy \
  --restart always \
  --network host \
  --cap-add NET_ADMIN \
  -v ./data/caddy/caddy_config:/config \
  -v ./data/caddy/caddy_data:/data \
  -v ./data/caddy/run:/var/run/caddy \
  -v ./data/caddy/run:/app/run \
  chaitin-registry.cn-hangzhou.cr.aliyuncs.com/chaitin/panda-wiki-caddy:2.10-alpine

# 5. 重启 API 服务以确保配置同步
echo "5. 重启 API 服务以确保配置同步..."
docker restart panda-wiki-api || true

# 6. 等待服务启动
echo "6. 等待服务启动..."
sleep 10

# 7. 验证服务状态
echo "7. 验证服务状态..."
docker ps -a | grep -E "(caddy|api)"

# 8. 查看 Caddy 日志
echo "8. 查看 Caddy 容器日志..."
docker logs panda-wiki-caddy --tail 50

echo "✓ Caddy 自动 HTTPS 配置完成！"
echo "现在您可以在 Admin 界面中："
echo "1. 进入 '设置' -> '机器人设置' -> '网页组件'"
echo "2. 更新域名和端口设置"
echo "3. 保存后，系统会自动同步到 Caddy"
echo "4. Caddy 会自动为新域名申请 Let's Encrypt 证书"
echo "5. 证书会在到期前 30 天自动续期"
