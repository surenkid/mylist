appName="mylist"
builtAt="$(date +'%F %T %z')"
goVersion=$(go version | sed 's/go version //')
gitAuthor=$(git log --pretty=format:"%an <%ae>" -1)
gitCommit=$(git log --pretty=format:"%h" -1)

if [ "$1" = "dev" ]; then
  version="dev"
  webVersion="dev"
else
  version=$(git describe --abbrev=0 --tags 2>/dev/null || echo "dev")
  webVersion="local"
fi

echo "backend version: $version"
echo "frontend version: $webVersion"

ldflags="\
-w -s \
-X 'github.com/alist-org/alist/v3/internal/conf.BuiltAt=$builtAt' \
-X 'github.com/alist-org/alist/v3/internal/conf.GoVersion=$goVersion' \
-X 'github.com/alist-org/alist/v3/internal/conf.GitAuthor=$gitAuthor' \
-X 'github.com/alist-org/alist/v3/internal/conf.GitCommit=$gitCommit' \
-X 'github.com/alist-org/alist/v3/internal/conf.Version=$version' \
-X 'github.com/alist-org/alist/v3/internal/conf.WebVersion=$webVersion' \
"

# 检查前端资源是否存在
CheckWebDist() {
  if [ ! -d "public/dist" ] || [ -z "$(ls -A public/dist 2>/dev/null)" ]; then
    echo "警告: public/dist 目录不存在或为空，请确保前端资源已准备好"
    echo "如果需要前端资源，请手动放置到 public/dist 目录"
  else
    echo "前端资源已存在: public/dist"
  fi
}

# 简单的本地构建（使用系统自带的 gcc）
BuildLocal() {
  mkdir -p "dist"
  muslflags="--extldflags '-static -fpic' $ldflags"
  echo "building for linux-musl-amd64 (使用本地 gcc)"
  export GOOS=linux
  export GOARCH=amd64
  export CC=gcc
  export CGO_ENABLED=1
  go build -o ./dist/$appName-linux-musl-amd64 -ldflags="$muslflags" -tags=jsoniter .
  cd dist
  find . -type f -print0 | xargs -0 md5sum >md5.txt
  cat md5.txt
  cd ..
}

# Docker 构建
BuildDocker() {
  go build -o ./bin/$appName -ldflags="$ldflags" -tags=jsoniter .
}

if [ "$1" = "dev" ]; then
  CheckWebDist
  if [ "$2" = "docker" ]; then
    BuildDocker
  else
    BuildLocal
  fi
elif [ "$1" = "release" ]; then
  CheckWebDist
  if [ "$2" = "docker" ]; then
    BuildDocker
  else
    BuildLocal
  fi
else
  echo "用法: $0 [dev|release] [docker]"
  echo "  dev     - 开发版本构建"
  echo "  release - 发布版本构建"
  echo "  docker  - Docker 构建模式（可选）"
  echo ""
  echo "注意: 此脚本已简化为仅依赖本地资源，不再下载第三方组件"
fi
