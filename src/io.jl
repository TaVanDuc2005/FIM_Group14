# Đọc/ghi định dạng SPMF.
# Đầu vào : mỗi dòng là một giao dịch, các item (số nguyên) cách nhau bởi dấu cách.
# Đầu ra  : mỗi dòng "i1 i2 i3 #SUP: n" (item sắp tăng dần).

"""
    read_transactions(path) -> Vector{Vector{Int}}

Bỏ dòng trống và dòng chú thích (bắt đầu bằng '#', '@', '%').
Mỗi giao dịch được bỏ item trùng và sắp tăng dần.
"""
function read_transactions(path::AbstractString)::Vector{Vector{Int}}
    transactions = Vector{Vector{Int}}()
    for line in eachline(path)
        s = strip(line)
        (isempty(s) || s[1] in ('#', '@', '%')) && continue
        items = sort!(unique!(parse.(Int, split(s))))
        push!(transactions, items)
    end
    return transactions
end

"""
    write_itemsets(path, itemsets::Dict{Vector{Int},Int})

Ghi kết quả theo định dạng SPMF, sắp xếp để dễ so sánh bằng `diff`.
"""
function write_itemsets(path::AbstractString, itemsets::Dict{Vector{Int},Int})
    keys_sorted = sort!(collect(keys(itemsets)); by = x -> (length(x), x))
    open(path, "w") do io
        for k in keys_sorted
            println(io, join(k, " "), " #SUP: ", itemsets[k])
        end
    end
    return path
end

"""
    min_support_count(minsup, n) -> Int

SPMF dùng minsup dạng tỉ lệ (0.4 = 40%). Đổi sang số đếm tuyệt đối.
Nếu `minsup >= 1` thì coi như đã là số đếm.
"""
min_support_count(minsup::Real, n::Integer) =
    minsup < 1 ? max(1, ceil(Int, minsup * n)) : Int(minsup)
