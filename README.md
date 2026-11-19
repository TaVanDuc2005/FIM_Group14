# Apriori - Khai thác tập phổ biến (Julia)

Đồ án Data Mining. Thuật toán: **Apriori** (bản cơ bản + bản tối ưu BitArray).

## Cài đặt
```
julia --project -e 'using Pkg; Pkg.instantiate()'
```

## Chạy thuật toán
```
julia --project scripts/main.jl data/toy/toy1.txt 0.5 out.txt bitarray
```

## Chạy test
```
julia --project test/runtests.jl
```
<!-- TODO: dán output lần chạy test cuối cùng ở đây -->

## Cấu trúc
- `src/` mã nguồn (io, apriori, apriori_bitarray)
- `test/` unit test, `benchmarks/` thực nghiệm, `applications/` 2 ứng dụng
- `notebooks/` notebook Colab, `docs/Report.pdf` báo cáo
- `data/` dữ liệu nhỏ; dữ liệu lớn: TODO link Hugging Face/Kaggle

## Colab
TODO: link notebook công khai

## Thành viên
TODO
