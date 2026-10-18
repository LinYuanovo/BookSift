#!/usr/bin/env bash
# 扫书汇 BookSift —— Linux 桌面 release 一键打包（Ubuntu 22.04+ x86_64）。
#
# 流程：
#   版本号（app/pubspec.yaml，剥 +build）
#   → preflight（flutter 在 PATH / pubspec 在位）
#   → flutter build linux --release（timeout 墙钟看门狗，日志 tee 到 app/build/release_logs/）
#   → 产物闸门（booksift 可执行 / lib/libsqlite3.so / data/flutter_assets）
#   → 打包 dist_release/linux-x64-v<VERSION>.tar.gz + .sha256（纯 64 位 hex 一行）
#   → 打印 dist_release 清单
#
# 退出码：0 成功 / 2 preflight 受阻 / 3 构建失败 / 4 产物闸门未过或打包失败
#
# 环境变量：
#   FLUTTER_BIN         flutter 可执行文件，默认 flutter（PATH 中查找）
#   BUILD_TIMEOUT_SEC   构建墙钟上限秒数，默认 1800
#
# 用法：
#   tools/make_release_linux.sh
#   FLUTTER_BIN=/opt/flutter/bin/flutter BUILD_TIMEOUT_SEC=2400 tools/make_release_linux.sh

set -euo pipefail

# ── 路径与参数 ──────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"
APP_DIR="$REPO_ROOT/app"
DIST_DIR="$REPO_ROOT/dist_release"
LOG_DIR="$APP_DIR/build/release_logs"
BUNDLE_DIR="$APP_DIR/build/linux/x64/release/bundle"

FLUTTER_BIN="${FLUTTER_BIN:-flutter}"
BUILD_TIMEOUT_SEC="${BUILD_TIMEOUT_SEC:-1800}"

step() { printf '\n── %s ──\n' "$1"; }
fail() { printf '✗ %s\n' "$1" >&2; exit "${2:-1}"; }

# ── 1. 版本号与 preflight ───────────────────────────────────────────────
step '1/4 版本号与 preflight'
if ! command -v "$FLUTTER_BIN" >/dev/null 2>&1; then
  fail "找不到 flutter（FLUTTER_BIN=$FLUTTER_BIN）——装好 Flutter SDK 或指定 FLUTTER_BIN=/path/to/flutter 后重跑。" 2
fi
if [[ ! -f "$APP_DIR/pubspec.yaml" ]]; then
  fail "缺 $APP_DIR/pubspec.yaml ——仓库不完整，请确认脚本位于仓库 tools/ 目录内。" 2
fi
# 版本号形如 `version: 1.0.0+1`，取 1.0.0（剥 +build）
VERSION="$(awk '/^version:/{gsub(/[+].*/,"",$2); print $2; exit}' "$APP_DIR/pubspec.yaml")"
if [[ ! "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  fail "无法从 app/pubspec.yaml 解析 version（期望形如 version: 1.0.0+1，实际得到 '$VERSION'）。" 2
fi
echo "  版本 $VERSION  →  dist_release/linux-x64-v$VERSION.tar.gz"

mkdir -p "$DIST_DIR" "$LOG_DIR"

HAS_TIMEOUT=0
if command -v timeout >/dev/null 2>&1; then
  HAS_TIMEOUT=1
else
  echo "  ! 未找到 timeout 命令，本次跳过 ${BUILD_TIMEOUT_SEC}s 墙钟看门狗"
fi

# ── 2. 构建 ─────────────────────────────────────────────────────────────
step "2/4 flutter build linux --release（墙钟上限 ${BUILD_TIMEOUT_SEC}s）"
STAMP="$(date +%Y%m%d-%H%M%S)"
LOG_FILE="$LOG_DIR/linux-release-$VERSION-$STAMP.log"
BUILD_CMD=("$FLUTTER_BIN" build linux --release)
if [[ "$HAS_TIMEOUT" -eq 1 ]]; then
  BUILD_CMD=(timeout --kill-after=30 "$BUILD_TIMEOUT_SEC" "${BUILD_CMD[@]}")
fi
echo "  日志 $LOG_FILE"

cd "$APP_DIR"
set +e
"${BUILD_CMD[@]}" 2>&1 | tee "$LOG_FILE"
BUILD_CODE=${PIPESTATUS[0]}
set -e

if [[ "$BUILD_CODE" -ne 0 ]]; then
  printf '\n✗ 构建失败 exit=%s。日志尾部（%s）：\n' "$BUILD_CODE" "$LOG_FILE" >&2
  tail -n 40 "$LOG_FILE" >&2 || true
  if [[ "$BUILD_CODE" -eq 124 || "$BUILD_CODE" -eq 137 ]]; then
    printf '  提示：%ss 墙钟看门狗触发（timeout exit=%s），可用 BUILD_TIMEOUT_SEC=3600 调大后重跑。\n' "$BUILD_TIMEOUT_SEC" "$BUILD_CODE" >&2
  fi
  exit 3
fi
echo '  ── 构建日志尾部 ──'
tail -n 5 "$LOG_FILE"

# ── 3. 产物闸门与打包 ───────────────────────────────────────────────────
step '3/4 产物闸门与打包'
if [[ ! -x "$BUNDLE_DIR/booksift" ]]; then
  fail "产物闸门未过：缺可执行文件 $BUNDLE_DIR/booksift——bundle 不完整，检查上方构建日志。" 4
fi
if [[ ! -f "$BUNDLE_DIR/lib/libsqlite3.so" ]]; then
  fail "产物闸门未过：缺 $BUNDLE_DIR/lib/libsqlite3.so——sqlite3 native assets 未产出；确认构建机有 C 编译工具链（clang/gcc）并回看构建日志里 sqlite3 钩子的报错。" 4
fi
if [[ ! -d "$BUNDLE_DIR/data/flutter_assets" ]]; then
  fail "产物闸门未过：缺 $BUNDLE_DIR/data/flutter_assets——bundle 不完整，拒绝打包。" 4
fi
echo '  ✓ booksift（可执行）/ lib/libsqlite3.so / data/flutter_assets 均在位'

PKG_NAME="linux-x64-v$VERSION"
TAR_PATH="$DIST_DIR/$PKG_NAME.tar.gz"
# GNU tar --transform：包内顶层目录固定为 $PKG_NAME/（Ubuntu 自带 GNU tar）
if ! tar -czf "$TAR_PATH" -C "$(dirname -- "$BUNDLE_DIR")" \
  --transform "s,^$(basename -- "$BUNDLE_DIR"),$PKG_NAME," "$(basename -- "$BUNDLE_DIR")"; then
  fail "打包失败：tar 未生成 $TAR_PATH（需要 GNU tar 的 --transform，Ubuntu 自带）。" 4
fi

SHA256="$(sha256sum "$TAR_PATH" | awk '{print $1}')"
if [[ ! "$SHA256" =~ ^[0-9a-f]{64}$ ]]; then
  fail "打包失败：sha256 结果异常 '$SHA256'。" 4
fi
# .sha256 口径与 tools/make_release.ps1 的 Write-Sha256File 一致：纯 64 位 hex 一行
printf '%s\n' "$SHA256" > "$TAR_PATH.sha256"
echo "  ✓ $PKG_NAME.tar.gz  $(du -h "$TAR_PATH" | cut -f1)"
echo "    sha256 $SHA256"

# ── 4. 清单 ─────────────────────────────────────────────────────────────
step '4/4 dist_release 清单'
ls -lh "$DIST_DIR"
printf '\n✓ 完成：%s（校验文件 %s.sha256）\n' "$TAR_PATH" "$TAR_PATH"
exit 0
