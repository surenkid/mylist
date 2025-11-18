# mylist

本项目基于 [AList](https://github.com/AlistGo/alist) 的 v3.39.4 版本修改而来。  
原项目使用 **AGPL-3.0 License** 授权，本项目遵循相同的许可证。

---

## 快速开始

### 使用 Docker（推荐）

```bash
docker run -d \
  --name mylist \
  -p 5244:5244 \
  -v /path/to/data:/opt/mylist/data \
  ghcr.io/surenkid/mylist:latest
```

访问 `http://localhost:5244` 进行初始配置。

### 使用二进制文件

1. 从 [Releases](https://github.com/surenkid/mylist/releases) 下载对应平台的二进制文件
2. 运行：

```bash
# Linux/macOS
./mylist-linux-amd64 server

# Windows
mylist-windows-amd64.exe server
```

首次运行会自动生成配置文件，访问 `http://localhost:5244` 进行初始配置。

---

## 版权与许可（License）

本项目是 AList 的派生版本，原始版权与许可证如下：

- 原项目地址：<https://github.com/AlistGo/alist>
- 原项目许可证：**GNU Affero General Public License v3.0 (AGPL-3.0)**

依据 AGPL-3.0 的要求：

1. 若你使用或修改本项目的代码，并对外**分发**或以 **网络服务形式提供**，你必须公开对应版本的完整源代码。
2. 你对本仓库的进一步修改和再分发，仍需继续使用 **AGPL-3.0** 许可。

完整条款请见本仓库附带的 `LICENSE` 文件。

---

## 修改声明

本项目自 2025-06-30 起由 **surenkid** 基于 AList v3.39.4 进行修改和继续维护。

本项目与 AList 官方版本无直接关联。

---

## 致谢

感谢 AList 项目及其贡献者的工作。
