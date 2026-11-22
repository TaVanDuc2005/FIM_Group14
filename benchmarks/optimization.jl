# Đo mức cải thiện của bản tối ưu (BitArray) so với bản cơ bản: thời gian và bộ nhớ cấp phát.
#   julia --project benchmarks/optimization.jl [số_lần_lặp]
# Kết quả: in bảng ra màn hình và ghi benchmarks/results/optimization.csv
#
# - Thời gian: trung vị của N lần chạy (mặc định 5) sau 1 lần chạy khởi động (loại thời gian biên dịch JIT).
# - Bộ nhớ: tổng số byte cấp phát (@allocated) trong một lần chạy.
#   (Peak RAM theo process được đo riêng ở Chương 2.)
# - Tập benchmark trong data/raw/ (chess, mushroom, ...) được dùng nếu đã tải về.
using AprioriFIM
using Statistics: median

const ROOT = joinpath(@__DIR__, "..")
const RAW = joinpath(ROOT, "data", "raw")
const TESTDB = joinpath(ROOT, "test", "data", "db")

# (tên, file, minsup) — minsup chọn để bản basic vẫn chạy xong trong thời gian hợp lý.
const CASES = [
    ("quest_medium", joinpath(TESTDB, "quest_medium.txt"), "2%"),
    ("sparse",       joinpath(TESTDB, "sparse.txt"),       "0.3%"),
    ("long_tx",      joinpath(TESTDB, "long_tx.txt"),      "60%"),
    ("chess",        joinpath(RAW, "chess.txt"),           "90%"),
    ("mushroom",     joinpath(RAW, "mushroom.txt"),        "40%"),
    ("T10I4D100K",   joinpath(RAW, "T10I4D100K.txt"),      "1%"),
    ("retail",       joinpath(RAW, "retail.txt"),          "2%"),
]

const ALGORITHMS = [("basic", apriori), ("bitarray", apriori_bitarray)]

function measure(algo, tx, minsup, runs)
    result = algo(tx, minsup)                      # khởi động + lấy kết quả
    bytes = @allocated algo(tx, minsup)
    times = [@elapsed(algo(tx, minsup)) for _ in 1:runs]
    return (n = length(result), time = median(times), bytes = bytes, result = result)
end

fmt_time(t) = t < 1 ? "$(round(t * 1000; digits = 1)) ms" : "$(round(t; digits = 2)) s"
fmt_mb(b) = "$(round(b / 2^20; digits = 1)) MB"

function main(args)
    runs = isempty(args) ? 5 : parse(Int, args[1])
    rows = NamedTuple[]
    println(rpad("dataset", 14), rpad("minsup", 7), rpad("#tx", 8), rpad("#itemsets", 10),
            rpad("basic", 11), rpad("bitarray", 11), rpad("speedup", 9),
            rpad("alloc basic", 13), rpad("alloc bit", 12), "giảm alloc")
    for (name, path, minsup_str) in CASES
        if !isfile(path)
            println(rpad(name, 14), "(bỏ qua: chưa có $(relpath(path, ROOT)))")
            continue
        end
        tx = read_transactions(path)
        minsup = parse_minsup(minsup_str)
        m = Dict(label => measure(algo, tx, minsup, runs) for (label, algo) in ALGORITHMS)
        b, f = m["basic"], m["bitarray"]
        b.result == f.result || error("$name: basic và bitarray cho kết quả khác nhau!")
        speedup = b.time / f.time
        alloc_ratio = b.bytes / max(f.bytes, 1)
        println(rpad(name, 14), rpad(minsup_str, 7), rpad(length(tx), 8), rpad(b.n, 10),
                rpad(fmt_time(b.time), 11), rpad(fmt_time(f.time), 11),
                rpad("$(round(speedup; digits = 1))x", 9),
                rpad(fmt_mb(b.bytes), 13), rpad(fmt_mb(f.bytes), 12), "$(round(alloc_ratio; digits = 1))x")
        push!(rows, (dataset = name, minsup = minsup_str, transactions = length(tx), itemsets = b.n,
                     basic_s = b.time, bitarray_s = f.time, speedup = speedup,
                     basic_alloc_bytes = b.bytes, bitarray_alloc_bytes = f.bytes, alloc_ratio = alloc_ratio))
    end

    out = joinpath(@__DIR__, "results", "optimization.csv")
    mkpath(dirname(out))
    open(out, "w") do io
        isempty(rows) && return
        println(io, join(keys(first(rows)), ","))
        foreach(r -> println(io, join(values(r), ",")), rows)
    end
    println("\nĐã ghi $(relpath(out, ROOT)) (julia $(VERSION), $(Sys.CPU_NAME), $runs lần lặp, trung vị)")
end

main(ARGS)
