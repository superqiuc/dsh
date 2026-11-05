# DeepSeek Harness 控制台（dsh）

一个自包含的 **DeepSeek Harness (dsh) 管理控制台**，面向飞牛 fnOS。
它负责拉起并守护 `dsh web` 进程，并提供一套 Vue 管理界面：概览、设置、目录授权、
插件管理、Web 终端、日志、数据备份与 dsh 服务版本管理。

> 本仓库是**控制台本体**。`dsh` 服务本身是官方 `@deepseek-ai/dsh` npm 包，
> 不随 fpk 预置，由控制台在「dsh 服务」里按需从所选 npm 镜像源安装。

## 功能

- **进程守护**：启动 / 停止 / 重启 dsh，展示 PID、端口、CPU / 内存；dsh 自重启后自动重新发现 PID
- **dsh 多版本**：从阿里云 / 腾讯云 / 华为云 / 官方源安装多个版本，自由切换、删除
- **反向代理 + 登录鉴权**：网关访问与端口访问双入口，密码、会话 TTL、在线访客管理
- **Web 终端**：xterm.js + PTY，支持会话接管、移动端辅助键条、触摸滚动
- **插件管理**：列出 / 启用 / 停用 / 卸载 dsh web profile 插件，带兼容性栅栏
- **目录授权**：授权飞牛共享目录，供 dsh 读写
- **日志**：dsh 与控制台日志实时流式输出、分级着色、下载
- **备份 / 恢复**：dsh 数据异步备份，进度可取消
- **移动端适配**：软键盘、安全区、底部导航，iOS WKWebView 兼容注入
- **飞牛网关**：平台网关注入身份头免登录，端口访问照旧鉴权

## 安装

1. 下载 `harness-2.0.0-x86.fpk`（ARM 设备使用 `arm` 包）
2. 飞牛应用中心 → **手动安装**，选择该 fpk
3. 打开「DeepSeek Harness」，在设置页配置登录密码
4. 在「dsh 服务」里选择一个版本安装并切换（首次使用必须做这一步）

依赖 `nodejs_v24`，应用中心会按 `manifest` 自动安装。数据目录为
`/vol1/@appdata/Harness`，升级或重装时保留。

## 更新日志

### 2.0.0

- 修复日志页在 SSE 首帧未到时误报「日志文件不可用」的问题：增加首屏 REST 兜底与加载态
- 修复空日志时不显示「暂无日志内容」的问题
- 开发者 / 发布者：superqiuc

## 构建

依赖：Node.js ≥24、Go ≥1.26。

```bash
./build.sh            # x86_64 → dist/harness-<version>-x86.fpk
./build.sh arm        # arm64  → dist/harness-<version>-arm.fpk
```

`build.sh` 会完成前端构建、Go 单二进制编译、`app.tgz` 与 fpk 打包，并输出
`.sha256`。只构建二进制（开发用）：

```bash
make                  # 开发构建
make release V=2.0.0  # 裁剪版
```

## 目录结构

| 路径 | 说明 |
| --- | --- |
| `backend/` | Go 后端：Admin socket、反向代理、dsh 管理、鉴权、终端、备份 |
| `frontend/` | Vue 3 + TypeScript 管理界面（Vite 构建后嵌入 Go 二进制） |
| `app/ui/` | fnOS 桌面入口配置与图标 |
| `cmd/` | fnOS 生命周期脚本（install / upgrade / uninstall / main） |
| `config/` | fnOS 权限与资源配置 |
| `wizard/` | 安装 / 卸载向导 |
| `manifest` | fnOS 应用元数据 |
| `build.sh` | 构建 `.fpk` |
| `Makefile` | 开发构建 |

## 技术栈

- 后端：Go 标准库 + `github.com/creack/pty`
- 前端：Vue 3（Composition API）+ TypeScript + Vite + Pinia + Vue Router + xterm.js
- 部署：fnOS / TRIM 平台，`/var/apps/Harness`，Unix socket + nginx 网关

## License

Apache-2.0。基于 [shuangji66/dsh](https://github.com/shuangji66/dsh) 的源码构建。
