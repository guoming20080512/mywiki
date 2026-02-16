#!/bin/bash

# 从Dockerfile.api提取的本地编译脚本
# 用于在宿主机上直接编译可执行文件

# 设置工作目录
cd "$(dirname "$0")"

# 设置环境变量
export CGO_ENABLED=0

# 定义构建参数
TARGETOS=$(uname -s | tr '[:upper:]' '[:lower:]')
TARGETARCH=$(uname -m)
VERSION=$(git describe --tags --always 2>/dev/null || echo "local-dev")

echo "=== 开始编译可执行文件 ==="
echo "目标平台: $TARGETOS/$TARGETARCH"
echo "版本: $VERSION"

# 创建输出目录
mkdir -p ./output

# 编译 panda-wiki-api
echo "=== 编译 panda-wiki-api ==="
GOOS=$TARGETOS GOARCH=$TARGETARCH go build -ldflags "-s -w -extldflags '-static' -X github.com/chaitin/panda-wiki/telemetry.Version=${VERSION}" -o ./output/panda-wiki-api cmd/api/main.go cmd/api/wire_gen.go

# 编译 panda-wiki-migrate
echo "=== 编译 panda-wiki-migrate ==="
GOOS=$TARGETOS GOARCH=$TARGETARCH go build -ldflags "-s -w -extldflags '-static' -X github.com/chaitin/panda-wiki/telemetry.Version=${VERSION}" -o ./output/panda-wiki-migrate cmd/migrate/main.go cmd/migrate/wire_gen.go

echo "=== 编译完成 ==="
echo "可执行文件位置: ./output/"
echo "- panda-wiki-api: API服务主程序"
echo "- panda-wiki-migrate: 数据库迁移工具"
