# Kiểm thử các chức năng cốt lõi của ứng dụng Market Basket Analysis.
include(joinpath(@__DIR__, "..", "applications", "market_basket.jl"))

const TOY_BASKETS = [["A", "B", "C"], ["A", "B", "C"], ["A", "B", "C"],
                     ["A", "B"], ["A"], ["B"]]

@testset "Market Basket Analysis" begin
    @testset "Đọc và mã hóa dữ liệu" begin
        transactions, labels = load_groceries()
        @test length(transactions) == 9835
        @test length(labels) == 169
        @test all(all(x -> 1 <= x <= length(labels), transaction) for transaction in transactions)
        @test issorted(labels)
    end

    @testset "Chạy Apriori và sinh luật" begin
        transactions, labels = encode_transactions(TOY_BASKETS)
        itemsets, rules = run_market_basket(transactions; minsup = 2, minconf = 0.5)

        @test itemsets == apriori(transactions, 2)
        @test !isempty(rules)
        @test all(rule -> rule.support >= 2 && rule.confidence >= 0.5, rules)
        @test all(rule -> rule.lift > 0, rules)
    end

    @testset "Khảo sát minsup và minconf" begin
        transactions, _ = encode_transactions(TOY_BASKETS)
        rows = sweep_thresholds(transactions; minsups = [2, 3], minconfs = [0.0, 0.5])

        @test length(rows) == 4
        @test all(row -> row.n_itemsets >= 0 && row.n_rules >= 0, rows)
        @test all(row -> row.n_lift_gt1 <= row.n_rules, rows)
        @test all(row -> row.n_curated <= row.n_lift_gt1, rows)
        @test all(row -> row.min_consequent_count == 0 || row.min_consequent_count >= row.minsup_count, rows)

        # Với cùng minsup, tăng minconf không thể làm số luật tăng.
        for minsup in [2, 3]
            low = only(filter(row -> row.minsup == minsup && row.minconf == 0.0, rows))
            high = only(filter(row -> row.minsup == minsup && row.minconf == 0.5, rows))
            @test high.n_rules <= low.n_rules
        end

        # Với cùng minconf, tăng minsup không thể làm số frequent itemsets tăng.
        for minconf in [0.0, 0.5]
            low = only(filter(row -> row.minsup == 2 && row.minconf == minconf, rows))
            high = only(filter(row -> row.minsup == 3 && row.minconf == minconf, rows))
            @test high.n_itemsets <= low.n_itemsets
        end
    end

    @testset "Lọc luật dư và trùng itemset" begin
        transactions, _ = encode_transactions(TOY_BASKETS)
        _, rules = run_market_basket(transactions; minsup = 2, minconf = 0.0)
        curated = curate_rules(rules)

        @test all(rule -> rule.lift > 1, curated)
        itemsets = [Tuple(sort(vcat(rule.antecedent, rule.consequent))) for rule in curated]
        @test length(itemsets) == length(unique(itemsets))

        # Mỗi itemset 3 món có thể sinh nhiều hướng luật; kết quả chỉ giữ một luật đại diện.
        triple_rules = filter(rule -> length(rule.antecedent) + length(rule.consequent) == 3, curated)
        triple_itemsets = [Tuple(sort(vcat(rule.antecedent, rule.consequent))) for rule in triple_rules]
        @test length(triple_itemsets) == length(unique(triple_itemsets))
        @test length(triple_rules) == 1  # ABC chỉ còn một luật đại diện

        # Luật {A,B} => {C} dư nếu {A} => {C} đã có confidence không thấp hơn.
        broad = Rule([1], [3], 4, 1.0, 1.5)
        specific = Rule([1, 2], [3], 4, 1.0, 1.5)
        @test curate_rules([broad, specific]) == [broad]
    end

    @testset "Top-k và in bảng" begin
        transactions, labels = encode_transactions(TOY_BASKETS)
        _, rules = run_market_basket(transactions; minsup = 2, minconf = 0.0)
        curated = curate_rules(rules)

        by_lift = top_rules(curated, 10; by = :lift)
        by_support = top_rules(curated, 10; by = :support)
        @test issorted(getproperty.(by_lift, :lift); rev = true)
        @test issorted(getproperty.(by_support, :support); rev = true)
        @test length(top_rules(curated, 100; by = :lift)) == length(curated)
        @test isempty(top_rules(curated, 0; by = :lift))
        @test_throws ArgumentError top_rules(curated, 10; by = :confidence)

        output = IOBuffer()
        print_rules(by_lift, labels; io = output)
        @test occursin("Association rule", String(take!(output)))
    end
end
