# Đọc/ghi định dạng SPMF.
# Đầu vào : mỗi dòng là một giao dịch, các item (số nguyên) cách nhau bởi dấu cách.
# Đầu ra  : mỗi dòng "i1 i2 i3 #SUP: n" (item sắp tăng dần).

const ItemsetSupports = Dict{Vector{Int},Int}

"""
    read_transactions(path) -> Vector{Vector{Int}}

Bỏ dòng trống và dòng chú thích (bắt đầu bằng '#', '@', '%').
Mỗi giao dịch được bỏ item trùng và sắp tăng dần.
"""
function read_transactions(path::AbstractString)::Vector{Vector{Int}}
    transactions = Vector{Vector{Int}}()
    open(path) do io
        for line in eachline(io)
            s = strip(line)
            (isempty(s) || s[1] in ('#', '@', '%')) && continue
            items = sort!(unique!(parse.(Int, split(s))))
            push!(transactions, items)
        end
    end
    return transactions
end

"""
    write_itemsets(path, itemsets::Dict{Vector{Int},Int})

Ghi kết quả theo định dạng SPMF, sắp xếp để dễ so sánh bằng `diff`.
"""
function write_itemsets(path::AbstractString, itemsets::ItemsetSupports)
    keys_sorted = sort!(collect(keys(itemsets)); by = x -> (length(x), x))
    mkpath(dirname(abspath(path)))
    open(path, "w") do io
        for k in keys_sorted
            println(io, join(k, " "), " #SUP: ", itemsets[k])
        end
    end
    return path
end

"""
    read_itemsets(path) -> Dict{Vector{Int},Int}

Đọc file kết quả định dạng SPMF ("i1 i2 #SUP: n"), ví dụ output của
`java -jar spmf.jar run Apriori ...`. Item trong itemset được sắp tăng dần
để so sánh được với kết quả của nhóm bất kể thứ tự SPMF ghi ra.
"""
function read_itemsets(path::AbstractString)::ItemsetSupports
    itemsets = ItemsetSupports()
    open(path) do io
        for line in eachline(io)
            s = strip(line)
            # SPMF bản mới ghi dòng metadata đầu file: @FILETYPE=..., @SOURCE=...
            (isempty(s) || startswith(s, '@')) && continue
            parts = split(s, "#SUP:")
            length(parts) == 2 || error("Dòng không đúng định dạng SPMF: \"$s\"")
            items = sort!(parse.(Int, split(parts[1])))
            itemsets[items] = parse(Int, strip(parts[2]))
        end
    end
    return itemsets
end

"""
    min_support_count(minsup, n) -> Int

Đổi ngưỡng minsup sang số giao dịch tuyệt đối, phân biệt theo kiểu:

- `minsup::Integer`       : đã là số đếm tuyệt đối (ví dụ `2`).
- `minsup::AbstractFloat` : tỉ lệ trong [0, 1] như SPMF (`0.4` = 40%, `1.0` = 100%).

Công thức giống hệt SPMF (`Math.ceil(minsup * databaseSize)`, cùng phép nhân
Float64) để ngưỡng khớp tuyệt đối với SPMF. Ngưỡng tối thiểu là 1 giao dịch.
"""
min_support_count(minsup::Integer, n::Integer) =
    minsup >= 0 ? max(1, Int(minsup)) : throw(ArgumentError("minsup phải ≥ 0, nhận $minsup"))

function min_support_count(minsup::AbstractFloat, n::Integer)
    0 <= minsup <= 1 ||
        throw(ArgumentError("minsup dạng tỉ lệ phải thuộc [0, 1], nhận $minsup; dùng số nguyên cho số đếm tuyệt đối"))
    return max(1, ceil(Int, minsup * n))
end

"""
    parse_minsup(s) -> Union{Int,Float64}

Đọc minsup từ dòng lệnh:
- `"40%"`  -> 0.4 (tỉ lệ, giống cú pháp SPMF)
- `"0.4"`  -> 0.4 (tỉ lệ; `"1.0"` nghĩa là 100%)
- `"2"`    -> 2   (số giao dịch tuyệt đối)
"""
function parse_minsup(s::AbstractString)::Union{Int,Float64}
    t = strip(s)
    endswith(t, "%") && return parse(Float64, chop(t)) / 100
    occursin(r"^\d+$", t) && return parse(Int, t)
    return parse(Float64, t)
end

"""
    compare_itemsets(ours, reference) -> NamedTuple

So sánh kết quả của nhóm với kết quả tham chiếu (SPMF). Trả về số itemset
của mỗi bên, số khớp cả itemset lẫn support, danh sách thiếu/thừa/sai support,
`match_rate` = số khớp / |ours ∪ reference| (1.0 khi cả hai rỗng) và `exact`.
"""
function compare_itemsets(ours::ItemsetSupports, reference::ItemsetSupports)
    missing_sets = [k for k in keys(reference) if !haskey(ours, k)]
    extra_sets = [k for k in keys(ours) if !haskey(reference, k)]
    wrong_support = [(k, ours[k], reference[k]) for k in keys(reference)
                     if haskey(ours, k) && ours[k] != reference[k]]
    union_size = length(reference) + length(extra_sets)
    matched = length(reference) - length(missing_sets) - length(wrong_support)
    return (n_ours = length(ours),
            n_reference = length(reference),
            matched = matched,
            missing = missing_sets,
            extra = extra_sets,
            wrong_support = wrong_support,
            match_rate = union_size == 0 ? 1.0 : matched / union_size,
            exact = matched == union_size)
end
