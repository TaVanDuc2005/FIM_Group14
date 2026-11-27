# Ứng dụng 1: Market Basket Analysis trên dữ liệu Groceries.
# Pipeline: đọc dữ liệu -> mã hóa -> Apriori -> sinh luật -> lọc -> Top-10.
using AprioriFIM

const DEFAULT_MINSUP = 0.005
const DEFAULT_MINCONF = 0.3

const MARKET_DATA = joinpath(@__DIR__, "..", "data", "market", "groceries.csv")

"""
    load_groceries(path = MARKET_DATA)

Đọc mỗi dòng là một giao dịch, mã hóa tên sản phẩm thành số nguyên 1..N.
Trả về `(transactions, labels)`, trong đó `labels[id]` là tên sản phẩm.
"""
function load_groceries(path::AbstractString = MARKET_DATA)
    isfile(path) || error("Không tìm thấy dữ liệu: $path")
    raw = read_labeled_transactions(path)
    return encode_transactions(raw)
end

"""
    run_market_basket(transactions; minsup = 0.005, minconf = 0.3)

Chạy Apriori của nhóm để tìm frequent itemsets, sau đó sinh association rules.
`minsup` là tỉ lệ (ví dụ 0.01) hoặc số giao dịch tuyệt đối (ví dụ 10).
Trả về `(itemsets, rules)`.
"""
function run_market_basket(transactions::Vector{Vector{Int}};
                           minsup::Real = 0.005, minconf::Real = 0.3)
    itemsets = apriori(transactions, minsup)
    rules = association_rules(itemsets, length(transactions); minconf)
    return itemsets, rules
end

# Lưới khảo sát ban đầu; có thể truyền lưới khác khi gọi sweep_thresholds.
const SWEEP_MINSUPS = [0.05, 0.02, 0.01, 0.005, 0.003, 0.002, 0.001]
const SWEEP_MINCONFS = [0.2, 0.3, 0.4, 0.5, 0.6]

"""
    sweep_thresholds(transactions; minsups = SWEEP_MINSUPS,
                     minconfs = SWEEP_MINCONFS)

Khảo sát nhiều cặp (minsup, minconf) trước khi chọn ngưỡng cuối cùng.
Với mỗi minsup, Apriori chỉ chạy một lần; sau đó sinh luật cho từng minconf.
Trả về số itemset, số luật thô, số luật có lift > 1, số luật sau curate,
median/max lift. Hàm chỉ cung cấp bằng chứng để người phân tích chọn ngưỡng,
không tự động chọn minsup/minconf.
"""
function sweep_thresholds(transactions::Vector{Vector{Int}};
                          minsups = SWEEP_MINSUPS,
                          minconfs = SWEEP_MINCONFS)
    n = length(transactions)
    rows = NamedTuple[]

    for minsup in minsups
        itemsets = apriori(transactions, minsup)

        for minconf in minconfs
            rules = association_rules(itemsets, n; minconf)
            positive_rules = filter(r -> r.lift > 1, rules)
            curated = curate_rules(rules)
            lifts = sort!([r.lift for r in curated])
            consequent_counts = [itemsets[r.consequent] for r in positive_rules]
            median_lift = isempty(lifts) ? 0.0 :
                (length(lifts) % 2 == 1 ? lifts[(length(lifts) + 1) ÷ 2] :
                 (lifts[length(lifts) ÷ 2] + lifts[length(lifts) ÷ 2 + 1]) / 2)

            push!(rows, (
                minsup = minsup,
                minsup_count = min_support_count(minsup, n),
                minconf = minconf,
                n_itemsets = length(itemsets),
                n_rules = length(rules),
                n_lift_gt1 = length(positive_rules),
                n_curated = length(curated),
                min_consequent_count = isempty(consequent_counts) ? 0 : minimum(consequent_counts),
                median_lift = median_lift,
                max_lift = isempty(lifts) ? 0.0 : last(lifts),
            ))
        end
    end
    return rows
end

# Kiểm tra một vector đã sắp tăng dần có phải tập con của vector khác không.
is_subset(a::Vector{Int}, b::Vector{Int}) = all(x -> x in b, a)

"""
    curate_rules(rules)

Giữ luật có Lift > 1, bỏ luật dư (cùng vế phải nhưng có vế trái tổng quát hơn
với confidence không thấp hơn), và chỉ giữ một luật tốt nhất cho mỗi itemset.
"""
function curate_rules(rules::AbstractVector{Rule})
    candidates = filter(r -> r.lift > 1, rules)
    # Luật Lift cao hơn được xét trước; nếu bằng nhau ưu tiên confidence rồi vế trái ngắn.
    sort!(candidates; by = r -> (-r.lift, -r.confidence, length(r.antecedent),
                                  r.antecedent, r.consequent))

    kept = Rule[]
    seen_itemsets = Set{Tuple{Vararg{Int}}}()

    for rule in candidates
        itemset = Tuple(sort(vcat(rule.antecedent, rule.consequent)))
        itemset in seen_itemsets && continue

        redundant = any(kept) do better
            better.consequent == rule.consequent &&
            length(better.antecedent) < length(rule.antecedent) &&
            better.confidence >= rule.confidence &&
            is_subset(better.antecedent, rule.antecedent)
        end
        redundant && continue

        push!(kept, rule)
        push!(seen_itemsets, itemset)
    end

    return kept
end

"""Sắp xếp giảm dần theo `:lift` hoặc `:support`, rồi lấy tối đa `k` luật."""
function top_rules(rules::AbstractVector{Rule}, k::Integer = 10; by::Symbol = :lift)
    key = if by == :lift
        r -> (-r.lift, -r.support, -r.confidence, r.antecedent, r.consequent)
    elseif by == :support
        r -> (-r.support, -r.lift, -r.confidence, r.antecedent, r.consequent)
    else
        throw(ArgumentError("by chỉ nhận :lift hoặc :support"))
    end

    sorted = sort(collect(rules); by = key)
    return sorted[1:min(max(k, 0), length(sorted))]
end

# Định nghĩa có điều kiện để không ghi đè print_table trong App 2 nếu cùng include.
if !isdefined(@__MODULE__, :print_table)
    """In bảng text căn cột, không cần thư viện ngoài."""
    function print_table(header, rows; io::IO = stdout)
        data = Vector{Vector{String}}()
        push!(data, string.(collect(header)))
        append!(data, [string.(collect(row)) for row in rows])
        widths = [maximum(length(row[i]) for row in data) for i in eachindex(header)]
        border = "+" * join(("-"^(w + 2) for w in widths), "+") * "+"
        println(io, border)
        for (index, row) in enumerate(data)
            println(io, "| " * join((rpad(value, widths[i]) for (i, value) in enumerate(row)), " | ") * " |")
            index == 1 && println(io, border)
        end
        println(io, border)
    end
end

"""In danh sách luật với tên sản phẩm thay vì mã số."""
function print_rules(rules::AbstractVector{Rule}, labels; io::IO = stdout)
    rows = [(i, format_rule(rule, labels; digits = 3), rule.support,
             round(rule.confidence; digits = 3), round(rule.lift; digits = 3))
            for (i, rule) in enumerate(rules)]
    print_table(("#", "Association rule", "Support count", "Confidence", "Lift"), rows; io)
end


function main()
    transactions, labels = load_groceries()

    println("Market Basket Analysis")
    println("Transactions: ", length(transactions))

    # MODE 1: Chỉ khảo sát ngưỡng
    if "--sweep" in ARGS
        println("\nKhảo sát ngưỡng minsup × minconf")

        # Bước 1: Gọi hàm khảo sát đã viết
        sweep = sweep_thresholds(transactions)

        # Bước 2: Chuyển kết quả thành các dòng để in
        sweep_rows = [
            (
                r.minsup,
                r.minsup_count,
                r.minconf,
                r.n_itemsets,
                r.n_rules,
                r.n_lift_gt1,
                r.n_curated,
                r.min_consequent_count,
                round(r.median_lift; digits = 3),
                round(r.max_lift; digits = 3)
            )
            for r in sweep
        ]

        # Bước 3: In bảng
        print_table(
            (
                "minsup",
                "minsup count",
                "minconf",
                "itemsets",
                "rules",
                "lift > 1",
                "curated",
                "min sup(Y)",
                "median lift",
                "max lift"
            ),
            sweep_rows
        )

        # Không chạy pipeline Top 10
        return
    end

    # MODE 2: Phân tích với ngưỡng mặc định
    println("Minsup: ", DEFAULT_MINSUP)
    println("Minconf: ", DEFAULT_MINCONF)

    itemsets, rules = run_market_basket(
        transactions;
        minsup = DEFAULT_MINSUP,
        minconf = DEFAULT_MINCONF
    )

    curated = curate_rules(rules)

    println("\nTop 10 Rules by Lift:")
    print_rules(top_rules(curated, 10; by = :lift), labels)

    println("\nTop 10 Rules by Support:")
    print_rules(top_rules(curated, 10; by = :support), labels)
end

if abspath(PROGRAM_FILE) == abspath(@__FILE__)
    main()
end
