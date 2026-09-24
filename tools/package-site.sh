#!/bin/sh
# 生成网站部署包：dist/iexif-site-日期.zip
# 包内：iexif/（网站根目录）、nginx-iexif.conf、README.md（部署说明）
set -eu
cd "$(dirname "$0")/.."

name="iexif-site-$(date +%Y%m%d)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

mkdir -p "$tmp/iexif-site" dist
cp -R web "$tmp/iexif-site/iexif"
cp deploy/nginx-iexif.conf "$tmp/iexif-site/"
cp deploy/部署说明.md "$tmp/iexif-site/README.md"
find "$tmp" \( -name .DS_Store -o -name '._*' \) -delete

rm -f "dist/$name.zip"
(cd "$tmp" && COPYFILE_DISABLE=1 zip -rqX "$OLDPWD/dist/$name.zip" iexif-site)
echo "dist/$name.zip"
