#!/usr/bin/env bash
# 把内核 AnyKernel3 zip 传到 GitCode 的 release（默认 tag 2026.11.11，prerelease）
#
# 用法： ./upload-gitcode.sh [tag] [zip路径]
#   ./upload-gitcode.sh                          # 默认 tag 2026.11.11 + /cannon/dist/SusfsNew.zip
#   ./upload-gitcode.sh 2026.11.11 /cannon/dist/SusfsNew.zip
set -euo pipefail

OWNER=GodTop
REPO=cannon
API=https://api.gitcode.com/api/v5
TOKEN_FILE=/root/.gitcode_token

TAG="${1:-2026.11.11}"
ZIP="${2:-/cannon/dist/SusfsNew.zip}"

[ -s "$TOKEN_FILE" ] || { echo "缺少令牌文件 $TOKEN_FILE"; exit 1; }
[ -f "$ZIP" ] || { echo "找不到 zip: $ZIP"; exit 1; }
TOKEN=$(tr -d '\r\n ' < "$TOKEN_FILE")
FILE_NAME=$(basename "$ZIP")

echo "文件: $FILE_NAME ($(du -h "$ZIP" | cut -f1))  tag: $TAG  prerelease: true"

echo '--- 1) 查询 / 创建 release'
code=$(curl -s -o /tmp/gc_release.json -w '%{http_code}' --max-time 30 \
  -H "PRIVATE-TOKEN: $TOKEN" "$API/repos/$OWNER/$REPO/releases/tags/$TAG")
if [ "$code" = "200" ]; then
  echo "release 已存在"
else
  echo "release 不存在（HTTP $code），创建中"
  BODY="cannon (Redmi Note 9T 5G / cannong, MT6853T) 内核 — KernelSU-Next v3.4.2 + SUSFS v2.3.0（新 reboot 超调用协议）\n\n- 基线: lineage-24.0-cannon + cannon-a17-susfs-new（cherry-pick 自 next-susfs-new）\n- 工具链: clang-r596125 (clang 22.0.2)\n- 内核版本: 4.14.336 #1\n- 包格式: AnyKernel3（只换内核）\n- 构建时间: $(date +%Y-%m-%d\ %H:%M)"
  curl -s --max-time 60 -X POST -H "PRIVATE-TOKEN: $TOKEN" \
    -H 'Content-Type: application/json' \
    "$API/repos/$OWNER/$REPO/releases?access_token=$TOKEN" \
    -d "$(jq -nc --arg t "$TAG" --arg b "$BODY" '{tag_name:$t,name:$t,body:$b,prerelease:true}')" \
    | jq -r '.tag_name // .message'
fi

echo '--- 2) 获取附件上传地址'
curl -s --max-time 60 -H "PRIVATE-TOKEN: $TOKEN" \
  "$API/repos/$OWNER/$REPO/releases/$TAG/upload_url?access_token=$TOKEN&file_name=$FILE_NAME" \
  -o /tmp/gc_upload.json
UPLOAD_URL=$(jq -r '.url // empty' /tmp/gc_upload.json)
if [ -z "$UPLOAD_URL" ]; then
  echo "获取上传地址失败:"; jq . /tmp/gc_upload.json; exit 1
fi
echo "上传地址已获取（$(echo "$UPLOAD_URL" | cut -d/ -f1-3)）"

echo '--- 3) 上传'
mapfile -t HDRS < <(jq -r '.headers | to_entries[] | "\(.key): \(.value)"' /tmp/gc_upload.json)
ARGS=()
for h in "${HDRS[@]}"; do ARGS+=(-H "$h"); done
curl -# --fail --max-time 3600 -X PUT "${ARGS[@]}" -T "$ZIP" "$UPLOAD_URL"

echo '--- 4) 校验附件'
curl -s --max-time 30 -H "PRIVATE-TOKEN: $TOKEN" \
  "$API/repos/$OWNER/$REPO/releases/tags/$TAG" \
  | jq -r '.assets[]? | "\(.name)\t\(.browser_download_url)"'

echo "完成。下载页: https://gitcode.com/$OWNER/$REPO/releases"
echo "sha256: $(sha256sum "$ZIP" | cut -d' ' -f1)"