# Luật kết hợp (src/rules.jl): kiểm tra tay, vét cạn, I/O, mã hóa item và so với SPMF.
# Cần spmf_cases.jl đã được include (runtests.jl làm việc này).

"""Vét cạn: mọi cách tách X ∪ Y = l của mọi tập phổ biến l (để đối chiếu với ap-genrules)."""
function brute_force_rules(itemsets, n_tx; minconf, minlift = 0.0)
    rules = Rule[]
    for (l, sup_l) in itemsets
        k = length(l)
        for mask in 1:(2^k - 2)                      # bỏ X rỗng và X = l
            x = [l[i] for i in 1:k if (mask >> (i - 1)) & 1 == 1]
            y = [l[i] for i in 1:k if (mask >> (i - 1)) & 1 == 0]
            conf = sup_l / itemsets[x]
            lift = conf / (itemsets[y] / n_tx)
            conf >= minconf && lift >= minlift && push!(rules, Rule(x, y, sup_l, conf, lift))
        end
    end
    return rules
end

as_set(rules) = Set((r.antecedent, r.consequent, r.support) for r in rules)

@testset "association rules" begin
    @testset "toy1 kiểm tra tay" begin
        tx = read_transactions(TOY_DB)                     # 4 giao dịch, Fig. 3 của bài báo
        rules = association_rules(apriori(tx, 0.5), length(tx); minconf = 0.6)
        @test length(rules) == 14
        r = only(filter(r -> r.antecedent == [1] && r.consequent == [3], rules))
        @test r.support == 2 && r.confidence == 1.0 && r.lift ≈ 4 / 3   # sup({3}) = 3/4
        r = only(filter(r -> r.antecedent == [5] && r.consequent == [2, 3], rules))
        @test r.support == 2 && r.confidence ≈ 2 / 3
        @test isempty(association_rules(apriori(tx, 0.5), length(tx); minconf = 1.0, minlift = 2.0))
        @test all(r -> r.confidence == 1.0, association_rules(apriori(tx, 0.5), length(tx); minconf = 1.0))
    end

    @testset "ap-genrules = vét cạn" begin
        # (CSDL, minsup): tối đa ~200 nghìn cách tách. long_tx ở minsup thấp hơn bùng nổ số itemset.
        for (name, minsup) in (("dense_small", 0.3), ("long_tx", 0.5), ("quest_medium", 0.03))
            tx = read_transactions(db(name))
            itemsets = apriori_bitarray(tx, minsup)
            for minconf in (0.0, 0.5, 0.9, 1.0), minlift in (0.0, 1.0)
                ours = association_rules(itemsets, length(tx); minconf, minlift)
                @test as_set(ours) == as_set(brute_force_rules(itemsets, length(tx); minconf, minlift))
                @test length(ours) == length(as_set(ours))       # không sinh trùng luật
            end
        end
    end

    @testset "biên và lỗi" begin
        @test isempty(association_rules(Dict([1] => 3, [2] => 2), 5; minconf = 0.0))  # chỉ có 1-itemset
        @test isempty(association_rules(Dict{Vector{Int},Int}(), 5; minconf = 0.5))
        @test_throws ArgumentError association_rules(Dict([1] => 2), 5; minconf = 1.5)
        @test_throws ArgumentError association_rules(Dict([1] => 2), 0; minconf = 0.5)
        # thiếu tập con {2} -> báo lỗi rõ ràng thay vì chia cho 0
        @test_throws ArgumentError association_rules(Dict([1] => 3, [1, 2] => 2), 5; minconf = 0.0)
    end

    @testset "write_rules / read_rules" begin
        tx = read_transactions(db("dense_small"))
        rules = association_rules(apriori_bitarray(tx, 0.5), length(tx); minconf = 0.8)
        path = tempname() * "_rules.txt"
        write_rules(path, rules)
        back = read_rules(path)
        @test as_set(back) == as_set(rules)
        @test compare_rules(back, rules).exact
        @test Set(back) == Set(rules)                    # Float64 in/đọc lại không mất bit
        write(path, "1 2 #SUP: 3\n")                      # file itemset, không phải file luật
        @test_throws ErrorException read_rules(path)
        rm(path)
    end

    @testset "compare_rules phát hiện sai lệch" begin
        a = Rule([1], [2], 3, 0.75, 1.5)
        @test compare_rules([a], [a]).exact
        @test !compare_rules([Rule([1], [2], 3, 0.70, 1.5)], [a]).exact     # sai confidence
        @test length(compare_rules(Rule[], [a]).missing) == 1
        @test length(compare_rules([a, Rule([2], [1], 3, 0.6, 1.5)], [a]).extra) == 1
    end
end

@testset "item dạng tên" begin
    raw = [["milk", "bread"], ["bread", "beer", "bread"], ["milk", "bread", "beer"]]
    tx, labels = encode_transactions(raw)
    @test labels == ["beer", "bread", "milk"]                # mã theo thứ tự sắp xếp
    @test tx == [[2, 3], [1, 2], [1, 2, 3]]                  # bỏ trùng, sắp tăng dần
    @test decode([1, 3], labels) == ["beer", "milk"]
    @test encode_transactions(reverse(raw))[2] == labels     # cùng dữ liệu -> cùng mã

    rules = association_rules(apriori(tx, 2), length(tx); minconf = 1.0)
    r = only(filter(r -> decode(r.antecedent, labels) == ["milk"], rules))
    @test format_rule(r, labels) == "{milk} => {bread}  sup = 2, conf = 1.0, lift = 1.0"

    # item không phải chuỗi (ví dụ mã visual word) cũng dùng được
    tx2, labels2 = encode_transactions([[30, 10], [10]])
    @test tx2 == [[1, 2], [1]] && labels2 == [10, 30]

    path = tempname() * "_basket.csv"
    write(path, "citrus fruit, semi-finished bread,margarine\n\nwhole milk,,yogurt \n")
    @test read_labeled_transactions(path) ==
          [["citrus fruit", "semi-finished bread", "margarine"], ["whole milk", "yogurt"]]
    write(path, "a;b\nc\n")
    @test read_labeled_transactions(path; delim = ';') == [["a", "b"], ["c"]]
    rm(path)
end

@testset "SPMF reference (rules)" begin
    rows = String[]
    for (name, input, minsup_str, minconf_str) in SPMF_RULE_CASES
        ref_path = spmf_reference_path(name)
        @testset "$name" begin
            if !isfile(ref_path)
                @warn "Thiếu file tham chiếu SPMF $ref_path; chạy scripts/spmf_reference.jl"
                @test_skip false
            else
                reference = read_rules(ref_path)
                tx = read_transactions(input)
                minconf = parse_minsup(minconf_str)
                for (label, algo) in (("basic", apriori), ("bitarray", apriori_bitarray))
                    rules = association_rules(algo(tx, parse_minsup(minsup_str)), length(tx); minconf)
                    cmp = compare_rules(rules, reference)
                    @test cmp.exact
                    push!(rows, string(rpad(name, 26), rpad(label, 10), lpad(cmp.n_reference, 7),
                                       lpad(cmp.matched, 9), "   ", round(100 * cmp.match_rate; digits = 2), "%"))
                end
            end
        end
    end
    if !isempty(rows)
        println("\nTỉ lệ khớp luật với SPMF")
        println(rpad("case", 26), rpad("algo", 10), lpad("spmf", 7), lpad("matched", 9), "   rate")
        foreach(println, rows)
    end
end
