#!/bin/bash

# 从Dockerfile.api提取的本地编译脚本
# 用于在宿主机上直接编译可执行文件

# 设置工作目录
cd "$(dirname "$0")"

# 检查Go是否安装
if ! command -v go &> /dev/null; then
    echo "错误: 未找到Go编译器，请先安装Go"
    exit 1
fi

# 显示Go版本信息
echo "=== Go版本信息 ==="
go version
go env

# 设置环境变量
export CGO_ENABLED=0

# 定义构建参数
HOST_OS=$(uname -s | tr '[:upper:]' '[:lower:]')
HOST_ARCH=$(uname -m)

# 标准化架构名称
case "$HOST_ARCH" in
    x86_64|amd64) TARGETARCH="amd64" ;;
    aarch64|arm64) TARGETARCH="arm64" ;;
    *) TARGETARCH="$HOST_ARCH" ;;
esac

# 标准化操作系统名称
case "$HOST_OS" in
    linux) TARGETOS="linux" ;;
    darwin) TARGETOS="darwin" ;;
    windows) TARGETOS="windows" ;;
    *) TARGETOS="$HOST_OS" ;;
esac

VERSION=$(git describe --tags --always 2>/dev/null || echo "local-dev")

echo "=== 开始编译可执行文件 ==="
echo "主机平台: $HOST_OS/$HOST_ARCH"
echo "目标平台: $TARGETOS/$TARGETARCH"
echo "版本: $VERSION"

# 创建输出目录
mkdir -p ./output

# 编译 panda-wiki-api
echo "=== 编译 panda-wiki-api ==="
if GOOS=$TARGETOS GOARCH=$TARGETARCH go build -ldflags "-s -w -extldflags '-static' -X github.com/chaitin/panda-wiki/telemetry.Version=${VERSION}" -o ./output/panda-wiki-api cmd/api/main.go cmd/api/wire_gen.go; then
    echo "✓ panda-wiki-api 编译成功"
else
    echo "✗ panda-wiki-api 编译失败，尝试不指定GOOS/GOARCH"
    if go build -ldflags "-s -w -extldflags '-static' -X github.com/chaitin/panda-wiki/telemetry.Version=${VERSION}" -o ./output/panda-wiki-api cmd/api/main.go cmd/api/wire_gen.go; then
        echo "✓ panda-wiki-api 编译成功（使用默认平台）"
    else
        echo "✗ panda-wiki-api 编译失败"
    fi
fi

# 编译 panda-wiki-migrate
echo "=== 编译 panda-wiki-migrate ==="
if GOOS=$TARGETOS GOARCH=$TARGETARCH go build -ldflags "-s -w -extldflags '-static' -X github.com/chaitin/panda-wiki/telemetry.Version=${VERSION}" -o ./output/panda-wiki-migrate cmd/migrate/main.go cmd/migrate/wire_gen.go; then
    echo "✓ panda-wiki-migrate 编译成功"
else
    echo "✗ panda-wiki-migrate 编译失败，尝试不指定GOOS/GOARCH"
    if go build -ldflags "-s -w -extldflags '-static' -X github.com/chaitin/panda-wiki/telemetry.Version=${VERSION}" -o ./output/panda-wiki-migrate cmd/migrate/main.go cmd/migrate/wire_gen.go; then
        echo "✓ panda-wiki-migrate 编译成功（使用默认平台）"
    else
        echo "✗ panda-wiki-migrate 编译失败"
    fi
fi

# 检查编译结果
echo "=== 编译完成 ==="
echo "可执行文件位置: ./output/"
ls -la ./output/
if [ -f "./output/panda-wiki-api" ]; then
    echo "- panda-wiki-api: API服务主程序（已编译）"
else
    echo "- panda-wiki-api: API服务主程序（编译失败）"
fi
if [ -f "./output/panda-wiki-migrate" ]; then
    echo "- panda-wiki-migrate: 数据库迁移工具（已编译）"
else
    echo "- panda-wiki-migrate: 数据库迁移工具（编译失败）"
fi
