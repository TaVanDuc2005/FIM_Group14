# Apriori – Frequent Itemset Mining (Julia)

Đồ án Data Mining – Nhóm 14. Cài đặt thuật toán **Apriori** gồm hai phiên bản: cơ bản (`basic`) và tối ưu bằng tidset dạng `BitArray` (`bitarray`). Dự án gồm ba phần: cài đặt và kiểm chứng thuật toán, thực nghiệm hiệu năng, và hai ứng dụng thực tế.

## 1. Cài đặt môi trường

### Yêu cầu

- Julia 1.9 trở lên.
- Git.
- Java 25+ và SPMF (chỉ cần khi tạo hoặc chạy đối chiếu SPMF).

Tải Julia: https://julialang.org/downloads/

Kiểm tra phiên bản:

```bash
julia --version
```

Clone dự án và cài đặt các thư viện:

```bash
git clone https://github.com/TaVanDuc2005/FIM_Group14.git
cd FIM_Group14
julia --project -e 'using Pkg; Pkg.instantiate()'
```

## 2. Chương 1 – Cài đặt và kiểm chứng Apriori

### Chạy thuật toán

```bash
julia --project scripts/main.jl <input.txt> <minsup> <output.txt> [basic|bitarray]
```

- `input.txt`: dữ liệu đầu vào, mỗi dòng là một giao dịch.
- `minsup`: ngưỡng hỗ trợ tối thiểu, có thể là tỷ lệ (`50%`, `0.5`) hoặc số giao dịch tuyệt đối (`2`).
- `output.txt`: tệp lưu các tập phổ biến.
- `basic` hoặc `bitarray`: phiên bản thuật toán cần chạy.

Ví dụ:

```bash
julia --project scripts/main.jl data/toy/toy1.txt 50% output.txt bitarray
```

Chạy và so sánh hai phiên bản:

```bash
julia --project scripts/main.jl data/toy/toy1.txt 50% out_basic.txt basic
julia --project scripts/main.jl data/toy/toy1.txt 50% out_bitarray.txt bitarray
```

Định dạng kết quả tương thích SPMF, ví dụ: `1 3 #SUP: 2`.

### Sinh luật kết hợp

Ví dụ sử dụng thư viện:

```julia
using AprioriFIM

transactions, labels = encode_transactions([
    ["bread", "milk"],
    ["bread", "beer"],
    ["bread", "milk", "beer"]
])

itemsets = apriori_bitarray(transactions, 0.5)
rules = association_rules(itemsets, length(transactions);
                          minconf = 0.6, minlift = 0.0)

for rule in sort(rules; by = r -> -r.lift)
    println(format_rule(rule, labels))
end
```

Notebook minh họa thuật toán và luật kết hợp:

[Demo Apriori và Association Rules trên Google Colab](https://colab.research.google.com/github/TaVanDuc2005/FIM_Group14/blob/main/notebooks/demo_apriori_rules.ipynb)

### Kiểm chứng với SPMF

SPMF được dùng làm kết quả tham chiếu. Các kết quả tham chiếu đã được lưu trong `test/data/spmf/`, vì vậy chạy bộ test thông thường không cần Java.

Để tự tạo lại kết quả tham chiếu, đặt `spmf.jar` tại `tools/spmf/spmf.jar` hoặc cấu hình biến môi trường `SPMF_JAR`, sau đó chạy:

```bash
julia --project scripts/spmf_reference.jl
```

So sánh trên một bộ dữ liệu:

```bash
julia --project scripts/compare_spmf.jl data/raw/chess.txt 80% --algo=bitarray
```

## 3. Chương 2 – Thực nghiệm và đánh giá hiệu năng

Các thực nghiệm được thực hiện bằng script Julia trong thư mục `experiments/`, không cần notebook Colab riêng.

### Chạy thử pipeline

```bash
julia --project experiments/run_all.jl all --smoke --quick
```

Chế độ `--smoke` sử dụng dữ liệu nhỏ `test/data/db/quest_medium.txt`. Pipeline có bước đối chiếu SPMF nên cần chuẩn bị SPMF và Java tương thích.

### Chuẩn bị dữ liệu benchmark

Tải các bộ dữ liệu từ [SPMF Datasets](https://www.philippe-fournier-viger.com/spmf/index.php?link=datasets.php) và đặt vào `data/raw/` với tên:

| Tệp | Bộ dữ liệu |
|---|---|
| `chess.txt` | Chess |
| `mushroom.txt` | Mushroom |
| `retail.txt` | Retail |
| `T10I4D100K.txt` | T10I4D100K |

### Chạy thực nghiệm

```bash
# Khảo sát ngưỡng minsup
julia --project experiments/run_all.jl sweep

# Đo bộ nhớ
julia --project experiments/run_all.jl memory

# Đánh giá khả năng mở rộng
julia --project experiments/run_all.jl scalability

# Khảo sát độ dài giao dịch
julia --project experiments/run_all.jl txlen

# Phân tích số ứng viên và tập phổ biến theo từng mức k
julia --project experiments/run_all.jl levels

# Chạy toàn bộ thực nghiệm
julia --project experiments/run_all.jl all
```

Có thể thêm `--quick` để chạy nhanh các điểm đại diện:

```bash
julia --project experiments/run_all.jl all --quick
```

Kết quả được lưu trong `experiments/results/`, gồm các tệp CSV và log. Xem thêm [hướng dẫn thực nghiệm](experiments/README.md) và [báo cáo Chương 2](docs/chapter2_report.md).

## 4. Chương 3 – Ứng dụng thực tế

Đồ án triển khai hai ứng dụng: phân tích giỏ hàng và tìm motif bảo tồn trong protein kinase.

### Ứng dụng 1: Market Basket Analysis

Dữ liệu Groceries gồm 9.835 giao dịch và 169 nhóm sản phẩm.

Kiểm tra và chuẩn bị dữ liệu:

```bash
julia --project applications/prepare_groceries_data.jl
```

Chạy phân tích với ngưỡng mặc định (`minsup = 0.005`, `minconf = 0.3`):

```bash
julia --project applications/market_basket.jl
```

Khảo sát 35 tổ hợp ngưỡng `minsup × minconf`:

```bash
julia --project applications/market_basket.jl --sweep
```

Notebook demo:

[Market Basket Analysis trên Google Colab](https://colab.research.google.com/github/TaVanDuc2005/FIM_Group14/blob/main/notebooks/app1_market_basket.ipynb)

Báo cáo: [Ứng dụng 1](docs/chapter3_app1_report.md).

### Ứng dụng 2: Protein Kinase Motifs

Dữ liệu gồm 344 protein kinase người và 1.000 protein người không phải kinase làm nền, lấy từ UniProt Swiss-Prot.

Chuẩn bị dữ liệu (cần Internet nếu phải tải lại):

```bash
julia --project applications/prepare_protein_data.jl
```

Mở notebook và chạy toàn bộ:

[Protein Kinase Motifs trên Google Colab](https://colab.research.google.com/github/TaVanDuc2005/FIM_Group14/blob/main/notebooks/app2_protein_motifs.ipynb)

Trong Colab, chọn runtime Julia theo hướng dẫn ở đầu notebook, sau đó chọn **Runtime → Run all**.

Ứng dụng biểu diễn mỗi protein bằng các đoạn 3 amino acid (3-mer), khai thác tập phổ biến và phân tích các motif liên quan đến kinase.

Báo cáo: [Ứng dụng 2](docs/chapter3_app2_report.md).

## 5. Chạy bộ kiểm thử

Chạy toàn bộ unit test và kiểm chứng:

```bash
julia --project test/runtests.jl
```

Bộ test gồm kiểm thử thuật toán, đối chiếu tập phổ biến và luật kết hợp với SPMF, kiểm tra thuật toán sinh luật và tham số `maxlen`.

### Kết quả kiểm thử

<text>**Môi trường:** Julia 1.13.4.</text>

**Đối chiếu tập phổ biến với SPMF:**

| Case | Minsup | Algorithm | SPMF | Matched | Rate |
|---|---:|---|---:|---:|---:|
| toy1_50 | 50% | basic | 9 | 9 | 100% |
| toy1_50 | 50% | bitarray | 9 | 9 | 100% |
| toy1_25 | 25% | basic | 19 | 19 | 100% |
| toy1_25 | 25% | bitarray | 19 | 19 | 100% |
| toy1_100 | 100% | basic | 0 | 0 | 100% |
| toy1_100 | 100% | bitarray | 0 | 0 | 100% |
| single_100 | 100% | basic | 31 | 31 | 100% |
| single_100 | 100% | bitarray | 31 | 31 | 100% |
| dense_small_10 | 10% | basic | 1023 | 1023 | 100% |
| dense_small_10 | 10% | bitarray | 1023 | 1023 | 100% |
| dense_small_50 | 50% | basic | 150 | 150 | 100% |
| dense_small_50 | 50% | bitarray | 150 | 150 | 100% |
| long_tx_70 | 70% | basic | 292 | 292 | 100% |
| long_tx_70 | 70% | bitarray | 292 | 292 | 100% |
| sparse_1 | 1% | basic | 258 | 258 | 100% |
| sparse_1 | 1% | bitarray | 258 | 258 | 100% |
| sparse_0.3 | 0.3% | basic | 338 | 338 | 100% |
| sparse_0.3 | 0.3% | bitarray | 338 | 338 | 100% |
| quest_medium_5 | 5% | basic | 242 | 242 | 100% |
| quest_medium_5 | 5% | bitarray | 242 | 242 | 100% |
| quest_medium_2 | 2% | basic | 920 | 920 | 100% |
| quest_medium_2 | 2% | bitarray | 920 | 920 | 100% |
| quest_medium_7 | 7% | basic | 144 | 144 | 100% |
| quest_medium_7 | 7% | bitarray | 144 | 144 | 100% |

**Đối chiếu luật kết hợp với SPMF:**

| Case | Algorithm | SPMF | Matched | Rate |
|---|---|---:|---:|---:|
| rules_toy1_50_60 | basic | 14 | 14 | 100% |
| rules_toy1_50_60 | bitarray | 14 | 14 | 100% |
| rules_toy1_25_0 | basic | 60 | 60 | 100% |
| rules_toy1_25_0 | bitarray | 60 | 60 | 100% |
| rules_toy1_50_100 | basic | 5 | 5 | 100% |
| rules_toy1_50_100 | bitarray | 5 | 5 | 100% |
| rules_single_100_50 | basic | 180 | 180 | 100% |
| rules_single_100_50 | bitarray | 180 | 180 | 100% |
| rules_dense_small_50_80 | basic | 373 | 373 | 100% |
| rules_dense_small_50_80 | bitarray | 373 | 373 | 100% |
| rules_long_tx_70_90 | basic | 298 | 298 | 100% |
| rules_long_tx_70_90 | bitarray | 298 | 298 | 100% |
| rules_sparse_0.3_10 | basic | 76 | 76 | 100% |
| rules_sparse_0.3_10 | bitarray | 76 | 76 | 100% |
| rules_quest_medium_2_50 | basic | 1873 | 1873 | 100% |
| rules_quest_medium_2_50 | bitarray | 1873 | 1873 | 100% |

**Tổng kết lần chạy:**

```text
Test Summary: | Pass  Total   Time
AprioriFIM    |  215    215  23.9s
```

Tất cả 215 kiểm thử đều PASS. Hai phiên bản `basic` và `bitarray` đạt tỷ lệ khớp 100% với kết quả tham chiếu SPMF trên các trường hợp được kiểm tra.

## 6. Demo notebook trên Google Colab

| Chương | Nội dung | Notebook |
|---|---|---|
| Chương 1 | Apriori và luật kết hợp | [Mở Colab](https://colab.research.google.com/github/TaVanDuc2005/FIM_Group14/blob/main/notebooks/demo_apriori_rules.ipynb) |
| Chương 2 | Benchmark và đánh giá hiệu năng | Chạy bằng các script trong `experiments/`; hiện không có notebook riêng |
| Chương 3 | Market Basket Analysis | [Mở Colab](https://colab.research.google.com/github/TaVanDuc2005/FIM_Group14/blob/main/notebooks/app1_market_basket.ipynb) |
| Chương 3 | Protein Kinase Motifs | [Mở Colab](https://colab.research.google.com/github/TaVanDuc2005/FIM_Group14/blob/main/notebooks/app2_protein_motifs.ipynb) |


## 7. Cấu trúc repository

```text
src/            Mã nguồn Apriori và luật kết hợp
scripts/        CLI và công cụ đối chiếu SPMF
test/           Unit test, dữ liệu test và kết quả tham chiếu
benchmarks/     Đo mức cải thiện của phiên bản tối ưu
experiments/    Thực nghiệm Chương 2
applications/   Hai ứng dụng Chương 3
notebooks/      Notebook demo cho thuật toán và ứng dụng
data/           Dữ liệu test, market basket, bioinformatics
docs/           Báo cáo các chương và ứng dụng
```

## Thành viên

- 24127541 – Lỗ Chí Thành
- 24127280 – Nguyễn Khang Hy
- 23127528 – Tạ Văn Đức