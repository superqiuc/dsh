#!/usr/bin/env bash
# 构建 DeepSeek Harness 控制台的 fnOS 安装包（.fpk）。
#
#   ./build.sh          # x86_64，输出 dist/harness-<version>-x86.fpk
#   ./build.sh arm      # arm64，输出 dist/harness-<version>-arm.fpk
#
# 依赖：Node.js ≥24、Go ≥1.26。无需 fnpack：按 fnOS 包结构直接用 tar 打包。
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ARCH="${1:-x86}"
case "$ARCH" in
  x86|x86_64|amd64) ARCH=x86; GOARCH=amd64; PLATFORM=x86 ;;
  arm|arm64|aarch64) ARCH=arm; GOARCH=arm64; PLATFORM=arm ;;
  *) echo "未知架构：$ARCH（可选 x86 / arm）" >&2; exit 1 ;;
esac

VERSION="$(awk -F'=' '/^version[[:space:]]*=/{gsub(/[[:space:]]/,"",$2);print $2}' "$ROOT/manifest")"
[ -n "$VERSION" ] || { echo "无法从 manifest 读取版本" >&2; exit 1; }

GO_BIN="${GO_BIN:-$(command -v go 2>/dev/null || true)}"
if [ -z "$GO_BIN" ] || [ ! -x "$GO_BIN" ]; then
  GO_BIN=/vol1/1000/harness/.toolchain/go1.27.3/bin/go
fi
[ -x "$GO_BIN" ] || { echo "缺少 Go 工具链（可用 GO_BIN 指定）" >&2; exit 1; }

NPM_BIN="${NPM_BIN:-$(command -v npm 2>/dev/null || true)}"
if [ -z "$NPM_BIN" ] || [ ! -x "$NPM_BIN" ]; then
  NPM_BIN=/var/apps/nodejs_v24/target/bin/npm
fi
[ -x "$NPM_BIN" ] || { echo "缺少 Node.js/npm（可用 NPM_BIN 指定）" >&2; exit 1; }
export PATH="$(dirname "$NPM_BIN"):$PATH"

# npm/Go 的临时目录保持在仓库内，避免只读 HOME 或受限 TMPDIR。
mkdir -p "$ROOT/.build/home" "$ROOT/.build/npm-cache" "$ROOT/.build/gocache" "$ROOT/.build/gopath"
export HOME="$ROOT/.build/home"
export npm_config_cache="$ROOT/.build/npm-cache"
export GOCACHE="$ROOT/.build/gocache"
export GOPATH="$ROOT/.build/gopath"
export GOFLAGS="-buildvcs=false"
export GOPROXY="${GOPROXY:-https://goproxy.cn,https://proxy.golang.org,direct}"

STAGE="$ROOT/.build/stage"
DIST="$ROOT/dist"
rm -rf "$STAGE"
mkdir -p "$STAGE/bin" "$STAGE/ui" "$STAGE/config" "$DIST"

echo "==> 1/4 前端构建（Vue + Vite）"
( cd "$ROOT/frontend" && "$NPM_BIN" ci --no-audit --no-fund && VITE_TERMINAL=1 "$NPM_BIN" run build )

echo "==> 2/4 后端构建（Go，嵌入前端）"
rm -rf "$ROOT/backend/embed"
mkdir -p "$ROOT/backend/embed"
cp -r "$ROOT/frontend/dist/." "$ROOT/backend/embed/"
( cd "$ROOT/backend" && CGO_ENABLED=0 GOOS=linux GOARCH="$GOARCH" \
    "$GO_BIN" build -trimpath -tags "" \
    -ldflags "-s -w -X main.harnessVersion=$VERSION" \
    -o "$STAGE/bin/harness" . )
rm -rf "$ROOT/backend/embed"

echo "==> 3/4 组装应用负载"
cp -a "$ROOT/app/ui/." "$STAGE/ui/"
cp -a "$ROOT/config/." "$STAGE/config/"
chmod 755 "$STAGE" "$STAGE/bin" "$STAGE/bin/harness"
find "$STAGE" -type d -exec chmod 755 {} +
find "$STAGE" -type f ! -name harness -exec chmod 644 {} +
tar czf "$STAGE/app.tgz" -C "$STAGE" \
  --owner=0 --group=0 --numeric-owner --sort=name bin ui config

echo "==> 4/4 生成 fpk"
cp "$ROOT/manifest" "$ROOT/ICON.PNG" "$ROOT/ICON_256.PNG" "$STAGE/"
cp -a "$ROOT/cmd" "$ROOT/wizard" "$STAGE/"
MD5="$(md5sum "$STAGE/app.tgz" | cut -d' ' -f1)"
sed -i "s/^platform[[:space:]]*=.*/platform                   = $PLATFORM/" "$STAGE/manifest"
sed -i "s/^checksum[[:space:]]*=.*/checksum                   = $MD5/" "$STAGE/manifest"

chmod 644 "$STAGE/manifest" "$STAGE/ICON.PNG" "$STAGE/ICON_256.PNG"
find "$STAGE/cmd" -type f -exec chmod 755 {} +
find "$STAGE/wizard" -type f -exec chmod 644 {} +
find "$STAGE" -type d -exec chmod 755 {} +

OUT="$DIST/harness-${VERSION}-${ARCH}.fpk"
rm -f "$OUT"
tar czf "$OUT" -C "$STAGE" \
  --owner=0 --group=0 --numeric-owner --sort=name \
  app.tgz cmd config wizard manifest ICON.PNG ICON_256.PNG
( cd "$DIST" && sha256sum "$(basename "$OUT")" > "$(basename "$OUT").sha256" )
rm -rf "$STAGE"

echo "已生成：$OUT（$(du -h "$OUT" | cut -f1)）"
cat "$OUT.sha256"
