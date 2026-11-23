#!/usr/bin/env bash
# Tải các tập benchmark vào data/raw/ (định dạng: mỗi dòng một giao dịch, item cách nhau dấu cách).
# Chạy từ thư mục gốc repo:  bash experiments/download_data.sh [accidents]
# Nguồn chính: SPMF datasets; dự phòng: FIMI repository.
set -u
cd "$(dirname "$0")/.."
mkdir -p data/raw
SPMF="https://www.philippe-fournier-viger.com/spmf/datasets"
FIMI="http://fimi.uantwerpen.be/data"

fetch() {  # fetch <tên> <số giao dịch mong đợi>
  local name="$1" expect="$2" out="data/raw/$1.txt"
  if [ -s "$out" ]; then echo "[có sẵn] $out"; else
    echo "[tải] $name"
    curl -fL --retry 3 -o "$out" "$SPMF/$name.txt" 2>/dev/null \
      || curl -fL --retry 3 -o "$out" "$FIMI/$name.dat" 2>/dev/null \
      || { curl -fL --retry 3 -o "$out.gz" "$FIMI/$name.dat.gz" 2>/dev/null && gunzip -f "$out.gz"; } \
      || { echo "  !! không tải được $name — tải tay rồi lưu thành $out"; rm -f "$out" "$out.gz"; return; }
  fi
  local n; n=$(grep -c . "$out")
  echo "  $name: $n giao dịch (mong đợi $expect)"
}

fetch chess 3196
fetch mushroom 8124
fetch retail 88162
fetch T10I4D100K 100000
[ "${1:-}" = "accidents" ] && fetch accidents 340183
echo "Xong. Nếu số giao dịch lệch so với mong đợi, kiểm tra lại file (có thể là bản khác của tập dữ liệu)."
