# Chương 2 - Thực nghiệm và đánh giá

Đặt thư mục `experiments/` này vào **gốc repo** (cạnh `src/`, `scripts/`, `test/`).

## 0. Chuẩn bị
```
bash experiments/download_data.sh            # chess, mushroom, retail, T10I4D100K -> data/raw/
bash experiments/download_data.sh accidents  # (tuỳ chọn) thêm accidents
```
Script in số giao dịch từng tập; so với bảng đề bài (3196 / 8124 / 88162 / 100000 / 340183).

### SPMF + Java (quan trọng)
Máy bạn có Java 21, README ghi SPMF bản mới cần Java 25+. Hai cách:
- Cài JDK mới: `brew install --cask temurin@25`, rồi
  `export SPMF_JAVA=$(/usr/libexec/java_home -v 25)/bin/java`
- Hoặc dùng bản SPMF cũ hơn chạy được trên Java 21.
Đặt `spmf.jar` vào `tools/spmf/spmf.jar` (hoặc `export SPMF_JAR=/đường/dẫn/spmf.jar`).
Nếu gặp `UnsupportedClassVersionError`, script sẽ dừng và nhắc lại điều này.

## 1. Chạy thử (bắt buộc làm trước)
```
julia --project experiments/run_all.jl all --smoke --quick
python3 experiments/plot_results.py --smoke
```
Chạy trên `test/data/db/quest_medium.txt`, mất vài phút. Kiểm tra `experiments/results/logs/*.txt`:
phải thấy dòng `Total time ~ ... ms` và `Maximum memory usage` của SPMF (script đọc thời gian SPMF từ đó).
Nếu SPMF in khác, báo lại để chỉnh regex trong `common.jl`.

## 2. Chạy thật (theo từng phần, có thể ngắt và chạy tiếp)
```
julia --project experiments/run_all.jl sweep        # thời gian, số itemset, correctness
julia --project experiments/run_all.jl memory
julia --project experiments/run_all.jl scalability
julia --project experiments/run_all.jl txlen
julia --project experiments/run_all.jl levels
# thêm accidents:  --datasets=chess,mushroom,retail,T10I4D100K,accidents
# đổi timeout:     --basic-timeout=600 --timeout=1200
```
Nên chạy khi máy rảnh, không mở app nặng (ảnh hưởng thời gian và RAM đo được).
Kết quả: `experiments/results/results.csv`, `levels.csv`. Chạy lại lệnh sẽ bỏ qua điểm đã xong.
Một lần chạy basic quá timeout sẽ ghi `timeout` và bỏ qua các điểm khó hơn của cùng series.

## 3. Vẽ hình, bảng
```
pip install pandas numpy matplotlib tabulate
python3 experiments/plot_results.py
```
Hình: `experiments/figures/` (PNG + PDF), bảng: `experiments/tables/`.

## Ghi chú phương pháp
- Mỗi lần chạy thuật toán của nhóm là một process Julia mới (peak RAM sạch), có khởi động JIT trước khi đo.
- `mine_s` chỉ tính khai thác; `e2e_s` = đọc + khai thác + ghi file. "Total time" của SPMF gồm cả I/O
  nên so sánh với `e2e_s`. Đồ thị vẽ cả hai.
- Peak RAM: `peak_rss_mb` là đỉnh RSS cả process (Julia runtime ~250-300 MB; JVM của SPMF cũng có
  overhead riêng); `rss_delta_mb` là phần tăng so với ngay trước khi khai thác.
- Correctness: mọi điểm chạy đều so toàn bộ (itemset, support) với output SPMF.
- Seed cố định = 14 (lấy mẫu scalability, bộ sinh dữ liệu tổng hợp).
- Các mốc minsup trong `config.jl` là ước lượng ban đầu; sửa nếu một điểm chạy quá lâu hoặc output quá lớn.
