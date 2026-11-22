# Cách chạy:
#   julia --project scripts/main.jl <input.txt> <minsup> <output.txt> [basic|bitarray]
#
# minsup: "40%" hoặc "0.4" = tỉ lệ (giống SPMF, "1.0" = 100%); "2" = số giao dịch tuyệt đối.
# Ví dụ:
#   julia --project scripts/main.jl data/toy/toy1.txt 50% out.txt bitarray
#
# Thời gian in ra chỉ tính phần khai thác (không gồm đọc file, ghi file, và biên dịch JIT:
# thuật toán được chạy khởi động trên một CSDL nhỏ trước khi đo).
# Bộ nhớ:
# - "allocated by mining": tổng byte thuật toán cấp phát (@timed), so sánh được giữa basic/bitarray.
# - "peak RAM of process": đỉnh bộ nhớ của cả process Julia (Sys.maxrss). Gồm cả runtime/JIT
#   (khoảng 250-300 MB), nên chỉ phản ánh thuật toán khi CSDL lớn và phần khai thác chiếm ưu thế.
using AprioriFIM

const ALGORITHMS = Dict("basic" => apriori, "bitarray" => apriori_bitarray)

function main(args)
    if length(args) < 3 || (length(args) >= 4 && !haskey(ALGORITHMS, args[4]))
        println("Usage: main.jl <input> <minsup> <output> [basic|bitarray]")
        println("  minsup: 40% | 0.4 (tỉ lệ) | 2 (số giao dịch)")
        return 1
    end
    input, minsup, output = args[1], parse_minsup(args[2]), args[3]
    mode = length(args) >= 4 ? args[4] : "bitarray"
    algo = ALGORITHMS[mode]

    # Khởi động: biên dịch JIT với cùng kiểu tham số (minsup Int hoặc Float64) trên CSDL nhỏ.
    algo([[1, 2], [1, 2, 3]], minsup isa Integer ? 1 : 0.5)

    t_read = @elapsed tx = read_transactions(input)
    stats = @timed algo(tx, minsup)
    res = stats.value
    write_itemsets(output, res)

    mb(x) = round(x / 2^20; digits = 1)
    println("[$mode] $(length(tx)) transactions, minsup = $(min_support_count(minsup, length(tx))) ",
            "-> $(length(res)) frequent itemsets")
    println("  mining time: $(round(stats.time * 1000; digits = 2)) ms",
            " (read: $(round(t_read * 1000; digits = 2)) ms, GC: $(round(stats.gctime * 1000; digits = 2)) ms)")
    println("  allocated by mining: $(mb(stats.bytes)) MB, peak RAM of process: $(mb(Sys.maxrss())) MB")
    return 0
end

exit(main(ARGS))
