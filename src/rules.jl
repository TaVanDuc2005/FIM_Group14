# Sinh luật kết hợp từ tập phổ biến (Agrawal & Srikant 1994, mục 3: ap-genrules)
# và mã hóa item dạng tên (chuỗi) sang số nguyên cho dữ liệu thật ở Chương 3.

"""
    Rule

Luật kết hợp `antecedent => consequent` (hai itemset rời nhau, đã sắp tăng dần).

- `support`    : số giao dịch chứa `antecedent ∪ consequent` (tuyệt đối, như `#SUP` của SPMF)
- `confidence` : sup(X ∪ Y) / sup(X)
- `lift`       : confidence / (sup(Y) / n), > 1 nghĩa là X và Y xuất hiện cùng nhau nhiều hơn ngẫu nhiên
"""
struct Rule
    antecedent::Vector{Int}
    consequent::Vector{Int}
    support::Int
    confidence::Float64
    lift::Float64
end

Base.:(==)(a::Rule, b::Rule) = a.antecedent == b.antecedent && a.consequent == b.consequent &&
    a.support == b.support && a.confidence == b.confidence && a.lift == b.lift
Base.hash(r::Rule, h::UInt) = hash((r.antecedent, r.consequent, r.support, r.confidence, r.lift), h)

function Base.show(io::IO, r::Rule)
    print(io, "{", join(r.antecedent, ", "), "} => {", join(r.consequent, ", "), "}",
          " (sup = ", r.support, ", conf = ", round(r.confidence; digits = 4),
          ", lift = ", round(r.lift; digits = 4), ")")
end

"""Phần bù của `sub` trong `set` (cả hai đã sắp tăng dần, `sub ⊆ set`)."""
function sorted_setdiff(set::Vector{Int}, sub::Vector{Int})
    out = Vector{Int}(undef, length(set) - length(sub))
    i, pos = 1, 0
    for x in set
        if i <= length(sub) && sub[i] == x
            i += 1
        else
            out[pos += 1] = x
        end
    end
    return out
end

function lookup_support(itemsets::ItemsetSupports, x::Vector{Int})
    s = get(itemsets, x, 0)
    s > 0 || throw(ArgumentError("thiếu support của $x: `itemsets` phải chứa mọi tập con của " *
                                 "mỗi tập phổ biến (đúng với output của apriori/apriori_bitarray)"))
    return s
end

"""
    association_rules(itemsets, n_tx; minconf, minlift = 0.0) -> Vector{Rule}

Sinh mọi luật X => Y (X, Y khác rỗng, X ∪ Y là một tập phổ biến) có
`confidence ≥ minconf` và `lift ≥ minlift`, cùng ngưỡng và cách tính như
`FPGrowth_association_rules_with_lift` của SPMF.

- `itemsets` : output của `apriori` / `apriori_bitarray` (itemset => support tuyệt đối)
- `n_tx`     : số giao dịch của CSDL (để tính lift)
- `minconf`, `minlift` : tỉ lệ, ví dụ `0.6` = 60%

Thuật toán ap-genrules (mục 3 của bài báo): với mỗi tập phổ biến l, sinh hậu tố Y theo
từng mức kích thước bằng apriori-gen. Nếu X => Y không đạt minconf thì mọi luật có hậu tố
chứa Y cũng không đạt (vì sup(l \\ Y') ≤ sup(l \\ Y)), nên chỉ mở rộng các hậu tố đã đạt.
Lift không có tính chất này, nên chỉ dùng để lọc, không dùng để cắt nhánh.

Luật được trả về theo thứ tự sinh; dùng `sort(rules; by = r -> r.lift, rev = true)` để lấy top theo lift.
"""
function association_rules(itemsets::ItemsetSupports, n_tx::Integer;
                           minconf::Real, minlift::Real = 0.0)::Vector{Rule}
    0 <= minconf <= 1 || throw(ArgumentError("minconf phải thuộc [0, 1], nhận $minconf"))
    n_tx > 0 || throw(ArgumentError("n_tx phải > 0"))
    rules = Rule[]
    for (l, sup_l) in itemsets
        k = length(l)
        k >= 2 || continue
        consequents = [[x] for x in l]               # hậu tố 1 item, đã sắp theo thứ tự từ điển
        while !isempty(consequents) && length(first(consequents)) < k
            passed = Vector{Vector{Int}}()
            for y in consequents
                x = sorted_setdiff(l, y)
                confidence = sup_l / lookup_support(itemsets, x)
                confidence >= minconf || continue
                push!(passed, y)
                lift = confidence / (lookup_support(itemsets, y) / n_tx)
                lift >= minlift && push!(rules, Rule(x, y, sup_l, confidence, lift))
            end
            consequents = generate_candidates(passed)
        end
    end
    return rules
end

"""
    write_rules(path, rules)

Ghi luật theo định dạng SPMF: `1 2 ==> 3 #SUP: 5 #CONF: 0.8 #LIFT: 1.2`.
Sắp theo (kích thước luật, X, Y) để so sánh được bằng `diff`.
"""
function write_rules(path::AbstractString, rules::AbstractVector{Rule})
    sorted = sort(rules; by = r -> (length(r.antecedent) + length(r.consequent), r.antecedent, r.consequent))
    mkpath(dirname(abspath(path)))
    open(path, "w") do io
        for r in sorted
            println(io, join(r.antecedent, " "), " ==> ", join(r.consequent, " "),
                    " #SUP: ", r.support, " #CONF: ", r.confidence, " #LIFT: ", r.lift)
        end
    end
    return path
end

"""
    read_rules(path) -> Vector{Rule}

Đọc file luật định dạng SPMF (output của `FPGrowth_association_rules_with_lift` hoặc
`write_rules`). File không có `#LIFT` thì lift = NaN.
"""
function read_rules(path::AbstractString)::Vector{Rule}
    rules = Rule[]
    open(path) do io
        for line in eachline(io)
            s = strip(line)
            (isempty(s) || startswith(s, '@')) && continue
            m = match(r"^(.*?)==>(.*?)#SUP:\s*(\d+)\s*#CONF:\s*(\S+)(?:\s*#LIFT:\s*(\S+))?", s)
            m === nothing && error("Dòng không đúng định dạng luật SPMF: \"$s\"")
            lift = m[5] === nothing ? NaN : parse(Float64, m[5])
            push!(rules, Rule(sort!(parse.(Int, split(m[1]))), sort!(parse.(Int, split(m[2]))),
                              parse(Int, m[3]), parse(Float64, m[4]), lift))
        end
    end
    return rules
end

"""
    compare_rules(ours, reference; atol = 1e-9) -> NamedTuple

So sánh hai tập luật theo (X, Y): khớp khi cùng support và confidence/lift lệch ≤ `atol`
(SPMF tính lift theo công thức tương đương nhưng thứ tự phép tính khác, có thể lệch ở bit cuối).
"""
function compare_rules(ours::AbstractVector{Rule}, reference::AbstractVector{Rule}; atol::Real = 1e-9)
    key(r) = (r.antecedent, r.consequent)
    ref = Dict(key(r) => r for r in reference)
    own = Dict(key(r) => r for r in ours)
    close(a, b) = (isnan(a) && isnan(b)) || isapprox(a, b; atol = atol)
    missing_rules = [r for r in reference if !haskey(own, key(r))]
    extra = [r for r in ours if !haskey(ref, key(r))]
    wrong = [(own[k], r) for (k, r) in ref if haskey(own, k) &&
             !(own[k].support == r.support && close(own[k].confidence, r.confidence) &&
               (isnan(r.lift) || close(own[k].lift, r.lift)))]
    matched = length(ref) - length(missing_rules) - length(wrong)
    total = length(ref) + length(extra)
    return (n_ours = length(own), n_reference = length(ref), matched = matched,
            missing = missing_rules, extra = extra, wrong = wrong,
            match_rate = total == 0 ? 1.0 : matched / total, exact = matched == total)
end

# ---------------------------------------------------------------- item dạng tên

"""
    encode_transactions(raw) -> (transactions, labels)

Đổi giao dịch có item dạng bất kỳ (chuỗi tên sản phẩm, tên sự kiện, visual word, ...)
sang dạng số nguyên mà `apriori` / `apriori_bitarray` dùng.

- `transactions::Vector{Vector{Int}}` : mỗi giao dịch đã bỏ trùng và sắp tăng dần
- `labels::Vector`                    : `labels[id]` là item gốc của mã `id`

Mã được gán theo thứ tự sắp xếp của item gốc, nên cùng dữ liệu luôn cho cùng mã.
"""
function encode_transactions(raw::AbstractVector{<:AbstractVector})
    labels = sort!(unique(Iterators.flatten(raw)))
    id = Dict(item => i for (i, item) in enumerate(labels))
    transactions = [sort!(unique!([id[item] for item in t])) for t in raw]
    return transactions, labels
end

"""
    decode(itemset, labels) -> Vector

Đổi itemset dạng mã số về item gốc. Ví dụ `decode(r.antecedent, labels)`.
"""
decode(itemset::AbstractVector{<:Integer}, labels::AbstractVector) = labels[itemset]

"""
    format_rule(rule, labels) -> String

Chuỗi dễ đọc dùng tên item gốc, ví dụ
`"{whole milk, yogurt} => {rolls/buns}  sup = 120, conf = 0.41, lift = 1.62"`.
"""
format_rule(r::Rule, labels::AbstractVector; digits::Int = 3) = string(
    "{", join(decode(r.antecedent, labels), ", "), "} => {", join(decode(r.consequent, labels), ", "), "}",
    "  sup = ", r.support, ", conf = ", round(r.confidence; digits = digits),
    ", lift = ", round(r.lift; digits = digits))

"""
    read_labeled_transactions(path; delim = ',') -> Vector{Vector{String}}

Đọc CSDL mà mỗi dòng là một giao dịch, item là chuỗi cách nhau bởi `delim`
(ví dụ Groceries dạng basket: `citrus fruit,semi-finished bread,margarine`).
Bỏ khoảng trắng hai đầu item, item rỗng và dòng trống. Kết hợp với `encode_transactions`.
"""
function read_labeled_transactions(path::AbstractString; delim = ',')::Vector{Vector{String}}
    transactions = Vector{Vector{String}}()
    open(path) do io
        for line in eachline(io)
            items = [String(strip(x)) for x in split(line, delim)]
            filter!(!isempty, items)
            isempty(items) || push!(transactions, items)
        end
    end
    return transactions
end
