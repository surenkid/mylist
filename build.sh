appName="mylist"
builtAt="$(date +'%F %T %z')"
goVersion=$(go version | sed 's/go version //')
gitAuthor=$(git log --pretty=format:"%an <%ae>" -1 2>/dev/null || echo "unknown")
gitCommit=$(git log --pretty=format:"%h" -1 2>/dev/null || echo "unknown")

# 前端固定版本
WEB_FIXED_VERSION="3.39.2"

# 支持通过环境变量指定版本（适合 CI）
# 这些变量可以在 GitHub Actions 中设置

if [ "$1" = "dev" ]; then
  version="${VERSION:-dev}"
  webVersion="${WEB_VERSION:-$WEB_FIXED_VERSION}"
else
  version="${VERSION:-$(git describe --abbrev=0 --tags 2>/dev/null || echo "dev")}"
  webVersion="${WEB_VERSION:-$WEB_FIXED_VERSION}"
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

# 下载前端资源（固定版本）
FetchWeb() {
  echo "下载前端资源版本: $WEB_FIXED_VERSION"
  curl -L "https://github.com/AlistGo/alist-web/releases/download/$WEB_FIXED_VERSION/dist.tar.gz" -o dist.tar.gz
  if [ $? -ne 0 ]; then
    echo "错误: 下载前端资源失败"
    exit 1
  fi
  tar -zxvf dist.tar.gz
  rm -rf public/dist
  mv -f dist public
  rm -rf dist.tar.gz
  echo "前端资源已下载并放置到 public/dist"
}

# 检查前端资源是否存在，如果不存在则下载
CheckWebDist() {
  if [ ! -d "public/dist" ] || [ -z "$(ls -A public/dist 2>/dev/null)" ]; then
    echo "前端资源不存在，开始下载..."
    FetchWeb
  else
    echo "前端资源已存在: public/dist"
  fi
}

# 构建指定平台（使用系统自带的工具链）
BuildPlatform() {
  local os=$1
  local arch=$2
  local output_name=$3
  local cgo_enabled=${4:-1}
  local cc=${5:-}
  
  # 检测是否是交叉编译
  local current_os=$(go env GOOS 2>/dev/null || echo "")
  local current_arch=$(go env GOARCH 2>/dev/null || echo "")
  local is_cross_compile=false
  
  if [ "$os" != "$current_os" ] || [ "$arch" != "$current_arch" ]; then
    is_cross_compile=true
  fi
  
  # 如果是交叉编译，尝试使用交叉编译工具链
  if [ "$is_cross_compile" = "true" ] && [ "$cgo_enabled" = "1" ]; then
    # 根据目标平台选择交叉编译器
    if [ "$os" = "linux" ] && [ "$arch" = "arm64" ]; then
      # 尝试使用 aarch64-linux-gnu-gcc（Ubuntu/Debian 标准包）
      if command -v aarch64-linux-gnu-gcc >/dev/null 2>&1; then
        cc="aarch64-linux-gnu-gcc"
        echo "检测到交叉编译 ($current_os/$current_arch -> $os/$arch)，使用交叉编译器: $cc"
      else
        echo "警告: 未找到 aarch64-linux-gnu-gcc，禁用 CGO"
        cgo_enabled=0
      fi
    elif [ "$os" = "linux" ] && [ "$arch" = "386" ]; then
      if command -v i686-linux-gnu-gcc >/dev/null 2>&1; then
        cc="i686-linux-gnu-gcc"
        echo "检测到交叉编译 ($current_os/$current_arch -> $os/$arch)，使用交叉编译器: $cc"
      else
        echo "警告: 未找到 i686-linux-gnu-gcc，禁用 CGO"
        cgo_enabled=0
      fi
    elif [ "$os" = "windows" ] && [ "$arch" = "amd64" ]; then
      if command -v x86_64-w64-mingw32-gcc >/dev/null 2>&1; then
        cc="x86_64-w64-mingw32-gcc"
        echo "检测到交叉编译 ($current_os/$current_arch -> $os/$arch)，使用交叉编译器: $cc"
      else
        echo "警告: 未找到 x86_64-w64-mingw32-gcc，禁用 CGO"
        cgo_enabled=0
      fi
    else
      echo "警告: 未配置的交叉编译目标 ($os/$arch)，禁用 CGO"
      cgo_enabled=0
    fi
  fi
  
  # 如果没有指定编译器，使用默认值
  if [ -z "$cc" ] && [ "$cgo_enabled" = "1" ]; then
    cc="gcc"
  fi
  
  echo "building for $os-$arch (CGO_ENABLED=$cgo_enabled${cc:+, CC=$cc})"
  export GOOS=$os
  export GOARCH=$arch
  export CGO_ENABLED=$cgo_enabled
  
  if [ "$cgo_enabled" = "1" ] && [ -n "$cc" ]; then
    export CC=$cc
  else
    unset CC
    unset CXX
  fi
  
  local build_flags="$ldflags"
  if [ "$os" = "linux" ] && [ "$cgo_enabled" = "1" ] && [ -n "$cc" ]; then
    build_flags="--extldflags '-static -fpic' $ldflags"
  fi
  
  mkdir -p "dist"
  if go build -o ./dist/$output_name -ldflags="$build_flags" -tags=jsoniter .; then
    if [ -f "./dist/$output_name" ]; then
      echo "构建成功: ./dist/$output_name"
      ls -lh "./dist/$output_name"
    else
      echo "错误: 构建完成但文件不存在: ./dist/$output_name"
      exit 1
    fi
  else
    echo "错误: 构建失败"
    exit 1
  fi
}

# 构建当前平台（使用系统自带的工具链）
BuildLocal() {
  local os=${GOOS:-$(go env GOOS)}
  local arch=${GOARCH:-$(go env GOARCH)}
  local output_name="$appName-$os-$arch"
  
  # 如果是 Windows，添加 .exe 后缀
  if [ "$os" = "windows" ]; then
    output_name="$output_name.exe"
  fi
  
  BuildPlatform "$os" "$arch" "$output_name"
  
  cd dist
  find . -type f -print0 | xargs -0 md5sum >md5.txt 2>/dev/null || find . -type f -exec md5sum {} \; >md5.txt
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
  elif [ -n "$2" ] && [ -n "$3" ]; then
    # 支持指定平台: ./build.sh dev linux amd64
    local output_name="$appName-$2-$3"
    if [ "$2" = "windows" ]; then
      output_name="$output_name.exe"
    fi
    BuildPlatform "$2" "$3" "$output_name"
  else
    BuildLocal
  fi
elif [ "$1" = "release" ]; then
  CheckWebDist
  if [ "$2" = "docker" ]; then
    BuildDocker
  elif [ -n "$2" ] && [ -n "$3" ]; then
    # 支持指定平台: ./build.sh release linux amd64
    local output_name="$appName-$2-$3"
    if [ "$2" = "windows" ]; then
      output_name="$output_name.exe"
    fi
    BuildPlatform "$2" "$3" "$output_name"
  else
    BuildLocal
  fi
else
  echo "用法: $0 [dev|release] [docker|平台] [架构]"
  echo ""
  echo "示例:"
  echo "  $0 dev                    # 构建当前平台"
  echo "  $0 dev docker             # Docker 构建模式"
  echo "  $0 dev linux amd64        # 构建指定平台"
  echo "  $0 release windows amd64  # 构建 Windows 版本"
  echo ""
  echo "环境变量:"
  echo "  VERSION      - 指定后端版本号"
  echo "  WEB_VERSION  - 指定前端版本号"
  echo "  GOOS         - 指定目标操作系统"
  echo "  GOARCH       - 指定目标架构"
  echo ""
  echo "注意: 此脚本依赖本地资源，适合在 GitHub Actions 中使用"
fi
