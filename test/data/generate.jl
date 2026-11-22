# Sinh các CSDL test (định dạng SPMF) với seed cố định để tái lập được.
#   julia --project test/data/generate.jl
# Các file sinh ra được commit cùng repo; chỉ cần chạy lại khi muốn đổi bộ test.
using Random

const OUT_DIR = joinpath(@__DIR__, "db")

function write_db(name, transactions)
    path = joinpath(OUT_DIR, name * ".txt")
    open(path, "w") do io
        for t in transactions
            println(io, join(sort(unique(t)), " "))
        end
    end
    println("wrote $path ($(length(transactions)) transactions)")
end

"""Mỗi item xuất hiện độc lập với xác suất p (giao dịch rỗng được thay bằng 1 item)."""
function bernoulli_db(rng, n_tx, n_items, p)
    [begin
         t = [i for i in 1:n_items if rand(rng) < p]
         isempty(t) ? [rand(rng, 1:n_items)] : t
     end for _ in 1:n_tx]
end

"""
Bản rút gọn của bộ sinh dữ liệu tổng hợp trong bài báo (mục 4.3): mỗi giao dịch
ghép một vài "mẫu tiềm năng" (pattern) có trọng số, bỏ bớt item theo mức corruption,
rồi thêm nhiễu ngẫu nhiên.
"""
function quest_like_db(rng, n_tx, n_items, n_patterns, avg_pattern, avg_tx)
    patterns = [randperm(rng, n_items)[1:max(1, avg_pattern + rand(rng, -1:1))] for _ in 1:n_patterns]
    weights = cumsum(normalize_weights(-log.(rand(rng, n_patterns))))
    map(1:n_tx) do _
        t = Int[]
        target = max(1, avg_tx + rand(rng, -2:2))
        while length(t) < target
            pattern = patterns[searchsortedfirst(weights, rand(rng) * weights[end])]
            kept = [i for i in pattern if rand(rng) > 0.25]
            append!(t, kept)
            rand(rng) < 0.3 && push!(t, rand(rng, 1:n_items))
        end
        t
    end
end

normalize_weights(w) = w ./ sum(w)

function main()
    mkpath(OUT_DIR)
    rng = MersenneTwister(14)  # seed cố định (nhóm 14)

    # 1 giao dịch duy nhất: mọi tập con khác rỗng đều phổ biến.
    write_db("single", [[1, 2, 3, 4, 5]])
    # Nhỏ và dày: 30 giao dịch, 10 item, mỗi item có mặt 75%.
    write_db("dense_small", bernoulli_db(rng, 30, 10, 0.75))
    # Giao dịch dài, itemset phổ biến dài (giống chess/mushroom thu nhỏ).
    write_db("long_tx", bernoulli_db(rng, 60, 22, 0.85))
    # Thưa: 1000 giao dịch, 300 item, khoảng 4 item/giao dịch.
    write_db("sparse", bernoulli_db(rng, 1000, 300, 4 / 300))
    # Lớn hơn, có cấu trúc mẫu như T10I4 thu nhỏ.
    write_db("quest_medium", quest_like_db(rng, 3000, 120, 40, 4, 8))
end

main()
