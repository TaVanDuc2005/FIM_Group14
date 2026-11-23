# Chạy MỘT thuật toán của nhóm trong một process Julia riêng (để đo peak RAM sạch).
#   julia --project experiments/run_one.jl <basic|bitarray> <input> <minsup> <output|-> [reps]
# In ra các dòng "R:key=value" để runner đọc. output "-" = không ghi file.
#
# Đo:
#  - mine_s   : trung vị thời gian khai thác (sau khởi động JIT, không gồm I/O)
#  - e2e_s    : đọc + khai thác + ghi file (so sánh công bằng với "Total time" của SPMF, vốn gồm I/O)
#  - alloc_mb : tổng bộ nhớ cấp phát khi khai thác
#  - peak_rss_mb : đỉnh RSS cả process (gồm ~250-300 MB runtime Julia)
#  - rss_base_mb : maxrss ngay trước khai thác (runtime + CSDL đã nạp); rss_delta = peak - base
using AprioriFIM
using Statistics: median

const ALGOS = Dict("basic" => apriori, "bitarray" => apriori_bitarray)

function main(args)
    algo = ALGOS[args[1]]
    input, minsup_s, output = args[2], args[3], args[4]
    reps = length(args) >= 5 ? parse(Int, args[5]) : 1
    minsup = parse_minsup(minsup_s)

    algo([[1, 2], [1, 2, 3]], minsup isa Integer ? 1 : 0.5)      # khởi động JIT

    t_read = @elapsed tx = read_transactions(input)
    GC.gc()
    rss_base = Sys.maxrss()
    stats = @timed algo(tx, minsup)
    rss_peak = Sys.maxrss()
    result = stats.value
    times = Float64[stats.time]
    if stats.time < 5.0                       # chạy lặp để lấy trung vị khi đủ nhanh
        for _ in 2:reps
            push!(times, @elapsed algo(tx, minsup))
        end
    end
    t_write = output == "-" ? 0.0 : @elapsed write_itemsets(output, result)

    mb(x) = round(x / 2^20; digits = 2)
    t_mine = median(times)
    println("R:n_tx=", length(tx))
    println("R:minsup_count=", min_support_count(minsup, length(tx)))
    println("R:n_itemsets=", length(result))
    println("R:mine_s=", round(t_mine; digits = 5))
    println("R:e2e_s=", round(t_read + t_mine + t_write; digits = 5))
    println("R:alloc_mb=", mb(stats.bytes))
    println("R:gc_s=", round(stats.gctime; digits = 5))
    println("R:peak_rss_mb=", mb(rss_peak))
    println("R:rss_base_mb=", mb(rss_base))
    println("R:rss_delta_mb=", mb(max(rss_peak - rss_base, 0)))
    return 0
end

exit(main(ARGS))
