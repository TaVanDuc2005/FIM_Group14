# Apriori - Khai thác tập phổ biến (Julia)

Đồ án Data Mining. Thuật toán: **Apriori** (Agrawal & Srikant, 1994), gồm bản cơ bản
và bản tối ưu dùng tidset dạng BitArray.

## Cài đặt
Cần Julia ≥ 1.9. Project chỉ dùng thư viện chuẩn, không dùng thư viện FIM nào.
```
julia --project -e 'using Pkg; Pkg.instantiate()'
```

## Chạy thuật toán
```
julia --project scripts/main.jl <input.txt> <minsup> <output.txt> [basic|bitarray]
```
- Định dạng vào/ra giống SPMF: mỗi dòng một giao dịch; kết quả dạng `1 3 #SUP: 2`.
- `minsup`: `50%` hoặc `0.5` là tỉ lệ (giống SPMF, `1.0` = 100%); `2` là số giao dịch tuyệt đối.
  Ngưỡng tuyệt đối = `ceil(minsup * số_giao_dịch)`, cùng công thức với SPMF.

Ví dụ (CSDL ở Figure 3 của bài báo):
```
$ julia --project scripts/main.jl data/toy/toy1.txt 50% out.txt bitarray
[bitarray] 4 transactions, minsup = 2 -> 9 frequent itemsets
  mining time: 0.03 ms (read: 0.33 ms, GC: 0.0 ms)
  allocated by mining: 0.0 MB, peak RAM of process: 277.3 MB
```
- `mining time` chỉ tính phần khai thác: thuật toán được chạy khởi động trên CSDL nhỏ trước
  để loại thời gian biên dịch JIT; không gồm đọc/ghi file.
- `allocated by mining`: tổng bộ nhớ thuật toán cấp phát. `peak RAM of process`: đỉnh bộ nhớ
  của cả process, gồm khoảng 250–300 MB của Julia runtime, nên chỉ phản ánh thuật toán khi CSDL lớn.

## Luật kết hợp và item dạng tên
[src/rules.jl](src/rules.jl), dùng cho Chương 3:
```julia
using AprioriFIM
tx, labels = encode_transactions([["bread", "milk"], ["bread", "beer"], ["bread", "milk", "beer"]])
itemsets = apriori_bitarray(tx, 0.5)
rules = association_rules(itemsets, length(tx); minconf = 0.6, minlift = 0.0)
for r in sort(rules; by = r -> -r.lift)
    println(format_rule(r, labels))      # {milk} => {bread}  sup = 2, conf = 1.0, lift = 1.0
end
```
- `association_rules`: thủ tục ap-genrules (mục 3 của bài báo); trả về `Rule` gồm `antecedent`,
  `consequent`, `support` (tuyệt đối), `confidence`, `lift`. Cùng ngưỡng và công thức với
  `FPGrowth_association_rules_with_lift` của SPMF.
- `encode_transactions` / `decode` / `format_rule`: đổi item dạng bất kỳ (chuỗi, mã visual word, ...)
  sang số nguyên và ngược lại. `read_labeled_transactions(path; delim = ',')` đọc file mỗi dòng
  một giao dịch có item là chuỗi.
- `write_rules` / `read_rules`: định dạng SPMF `1 2 ==> 3 #SUP: 5 #CONF: 0.8 #LIFT: 1.2`.

Notebook mẫu: [notebooks/demo_apriori_rules.ipynb](notebooks/demo_apriori_rules.ipynb).

## Các bản cài đặt
| Bản | File | Đếm support |
|---|---|---|
| `apriori` | [src/apriori.jl](src/apriori.jl) | Quét lại CSDL ở mỗi lượt, kiểm tra ứng viên ⊆ giao dịch |
| `apriori_bitarray` | [src/apriori_bitarray.jl](src/apriori_bitarray.jl) | `tid(c) = tid(cha1) AND tid(cha2)` trên BitVector, không quét lại CSDL |

Hai bản dùng chung `apriori-gen` (join + prune). Các kỹ thuật tối ưu của bản BitArray:
1. Tidset dạng BitVector; phép AND và đếm bit chạy trên word 64 bit (`count_ones`, `@inbounds @simd`).
2. Chỉ tạo tidset cho item phổ biến (item không phổ biến không tốn `n` bit).
3. Lưu chỉ số hai itemset cha của mỗi ứng viên (trường *generators*, mục 2.2.2 của bài báo),
   nên lấy tidset của cha theo chỉ số thay vì tra `Dict` bằng itemset.
4. Prune chỉ kiểm tra k-2 tập con (hai tập con còn lại chính là hai cha), dùng lại một buffer.

Đo mức cải thiện (trung vị 5 lần chạy, Julia 1.12.6):
```
julia --project benchmarks/optimization.jl
```
| dataset | minsup | #itemsets | basic | bitarray | speedup | alloc basic | alloc bitarray |
|---|---|---|---|---|---|---|---|
| quest_medium | 2% | 920 | 338 ms | 6.1 ms | 55.4x | 7.6 MB | 2.8 MB |
| sparse | 0.3% | 338 | 632 ms | 38.8 ms | 16.3x | 21.0 MB | 18.4 MB |
| long_tx | 60% | 1725 | 16.9 ms | 6.1 ms | 2.8x | 2.8 MB | 2.7 MB |

Kết quả đầy đủ ghi ở `benchmarks/results/optimization.csv`. Các tập chess, mushroom,
retail, T10I4D100K được đo thêm khi đã có trong `data/raw/`.

## Kiểm tra tính đúng so với SPMF
SPMF chỉ dùng làm kết quả tham chiếu, không phải là một phần của cài đặt.
1. Tải `spmf.jar` từ https://www.philippe-fournier-viger.com/spmf/ vào `tools/spmf/spmf.jar`
   hoặc đặt biến môi trường `SPMF_JAR`. Bản SPMF mới cần **Java 25+**; nếu `java` trong PATH
   là bản cũ, đặt `SPMF_JAVA` trỏ tới `java.exe` của JDK mới.
2. Sinh kết quả tham chiếu cho các case trong [test/spmf_cases.jl](test/spmf_cases.jl):
   ```
   julia --project scripts/spmf_reference.jl
   ```
   Kết quả nằm ở `test/data/spmf/` và được commit, nên chạy test không cần Java.
3. So sánh trên một tập bất kỳ, ví dụ tập benchmark:
   ```
   julia --project scripts/compare_spmf.jl data/raw/chess.txt 80% --algo=bitarray
   ```

CSDL test ([test/data/db/](test/data/db/)) được sinh với seed cố định bởi
`julia --project test/data/generate.jl`:

| CSDL | #giao dịch | Đặc điểm |
|---|---|---|
| toy1 | 4 | Ví dụ Figure 3 của bài báo |
| single | 1 | Một giao dịch, mọi tập con đều phổ biến |
| dense_small | 30 | Nhỏ, dày (mỗi item có mặt 75%) |
| long_tx | 60 | Giao dịch dài, itemset phổ biến dài |
| sparse | 1000 | Thưa, 300 item, khoảng 4 item mỗi giao dịch |
| quest_medium | 3000 | Có cấu trúc mẫu, mô phỏng bộ sinh dữ liệu ở mục 4.3 của bài báo |

## Chạy test
```
julia --project test/runtests.jl
```
Gồm: unit test, đối chiếu tập phổ biến với SPMF (12 case), đối chiếu luật kết hợp với SPMF
(8 case, `FPGrowth_association_rules_with_lift`) và so ap-genrules với vét cạn mọi cách tách luật.
Output lần chạy test cuối (Julia 1.12.6, SPMF chạy trên Java 25):
```
Tỉ lệ khớp với SPMF
case              minsup  algo         spmf  matched   rate
toy1_50           50%     basic           9        9   100.0%
toy1_50           50%     bitarray        9        9   100.0%
toy1_25           25%     basic          19       19   100.0%
toy1_25           25%     bitarray       19       19   100.0%
toy1_100          100%    basic           0        0   100.0%
toy1_100          100%    bitarray        0        0   100.0%
single_100        100%    basic          31       31   100.0%
single_100        100%    bitarray       31       31   100.0%
dense_small_10    10%     basic        1023     1023   100.0%
dense_small_10    10%     bitarray     1023     1023   100.0%
dense_small_50    50%     basic         150      150   100.0%
dense_small_50    50%     bitarray      150      150   100.0%
long_tx_70        70%     basic         292      292   100.0%
long_tx_70        70%     bitarray      292      292   100.0%
sparse_1          1%      basic         258      258   100.0%
sparse_1          1%      bitarray      258      258   100.0%
sparse_0.3        0.3%    basic         338      338   100.0%
sparse_0.3        0.3%    bitarray      338      338   100.0%
quest_medium_5    5%      basic         242      242   100.0%
quest_medium_5    5%      bitarray      242      242   100.0%
quest_medium_2    2%      basic         920      920   100.0%
quest_medium_2    2%      bitarray      920      920   100.0%
quest_medium_7    7%      basic         144      144   100.0%
quest_medium_7    7%      bitarray      144      144   100.0%

Tỉ lệ khớp luật với SPMF
case                      algo         spmf  matched   rate
rules_toy1_50_60          basic          14       14   100.0%
rules_toy1_50_60          bitarray       14       14   100.0%
rules_toy1_25_0           basic          60       60   100.0%
rules_toy1_25_0           bitarray       60       60   100.0%
rules_toy1_50_100         basic           5        5   100.0%
rules_toy1_50_100         bitarray        5        5   100.0%
rules_single_100_50       basic         180      180   100.0%
rules_single_100_50       bitarray      180      180   100.0%
rules_dense_small_50_80   basic         373      373   100.0%
rules_dense_small_50_80   bitarray      373      373   100.0%
rules_long_tx_70_90       basic         298      298   100.0%
rules_long_tx_70_90       bitarray      298      298   100.0%
rules_sparse_0.3_10       basic          76       76   100.0%
rules_sparse_0.3_10       bitarray       76       76   100.0%
rules_quest_medium_2_50   basic        1873     1873   100.0%
rules_quest_medium_2_50   bitarray     1873     1873   100.0%
Test Summary: | Pass  Total  Time
AprioriFIM    |  161    161  9.5s
```

## Cấu trúc
- `src/`: mã nguồn (io, apriori, apriori_bitarray, rules)
- `scripts/`: CLI (`main.jl`) và công cụ đối chiếu SPMF
- `test/`: unit test, CSDL test và kết quả tham chiếu SPMF
- `benchmarks/`: thực nghiệm; `applications/`: 2 ứng dụng
- `notebooks/`: notebook Colab; `docs/Report.pdf`: báo cáo
- `data/`: dữ liệu nhỏ; dữ liệu lớn: TODO link Hugging Face/Kaggle

## Colab
Notebook mẫu (cài gói từ GitHub, khai thác tập phổ biến và luật): [mở trên Colab](https://colab.research.google.com/github/TaVanDuc2005/FIM_Group14/blob/main/notebooks/demo_apriori_rules.ipynb).
Trên Colab chọn *Runtime → Change runtime type → Julia* (Colab dùng Julia 1.10 LTS).

## Thành viên
TODO
