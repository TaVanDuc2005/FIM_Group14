# Chạy các thực nghiệm Chương 2.
#   julia --project experiments/run_all.jl <sweep|memory|scalability|txlen|levels|all> [tuỳ chọn]
# Tuỳ chọn:
#   --datasets=chess,mushroom,retail,T10I4D100K   (mặc định; thêm accidents nếu muốn)
#   --smoke                chạy thử trên bộ nhỏ test/data/db/quest_medium.txt (không cần tải dữ liệu)
#   --quick                chỉ 3 điểm minsup / 3 kích thước / 3 giá trị T (để thử nhanh)
#   --basic-timeout=900  --timeout=1800   (giây; --timeout áp dụng cho bitarray và SPMF)
# Kết quả ghi tăng dần vào experiments/results/results.csv (hoặc results_smoke.csv). Chạy lại sẽ
# bỏ qua các điểm đã xong; một điểm dang dở được chạy lại toàn bộ (plot_results.py giữ dòng cuối).
include(joinpath(@__DIR__, "common.jl"))
include(joinpath(@__DIR__, "gen_quest.jl"))
include(joinpath(@__DIR__, "levels.jl"))

function parse_cli(args)
    opts, pos = Dict{String,String}(), String[]
    for a in args
        if startswith(a, "--")
            kv = split(a[3:end], "="; limit = 2)
            opts[kv[1]] = length(kv) == 2 ? kv[2] : "true"
        else
            push!(pos, a)
        end
    end
    return pos, opts
end

select_pts(v, quick) = quick ? v[unique([1, cld(length(v), 2), length(v)])] : v

# ---------- 1) quét minsup: thời gian, số itemset, correctness ----------
function exp_sweep(tr, datasets, quick)
    for ds in datasets
        isfile(ds.path) || (println("[bỏ qua] chưa có ", ds.path); continue)
        println("== sweep: ", ds.name)
        for ms in select_pts(ds.grid, quick)
            base = Dict{String,Any}("experiment" => "sweep", "series" => ds.name,
                                    "dataset" => ds.name, "param" => ms)
            run_group!(tr, base, ds.path, ms, ["spmf", "bitarray", "basic"])
        end
    end
end

# ---------- 2) bộ nhớ: basic vs bitarray vs SPMF tại minsup trung bình ----------
function exp_memory(tr, datasets)
    for ds in datasets
        isfile(ds.path) || continue
        println("== memory: ", ds.name, " @ ", ds.mem)
        base = Dict{String,Any}("experiment" => "memory", "series" => ds.name,
                                "dataset" => ds.name, "param" => ds.mem)
        run_group!(tr, base, ds.path, ds.mem, ["spmf", "bitarray", "basic"])
    end
end

# ---------- 3) scalability: 10%..100% giao dịch ----------
function exp_scalability(tr, datasets, quick)
    paths = Dict(ds.name => ds.path for ds in datasets)
    for cfg in SCAL
        haskey(paths, cfg.dataset) && isfile(paths[cfg.dataset]) || continue
        println("== scalability: ", cfg.id)
        tx = read_transactions(paths[cfg.dataset])
        perm = randperm(MersenneTwister(SEED), length(tx))      # tập con lồng nhau, tái lập được
        for pct in select_pts(SIZES, quick)
            m = max(1, round(Int, length(tx) * pct / 100))
            file = joinpath(TMP, "scal_$(cfg.id)_$(pct).txt")
            open(file, "w") do io
                for i in sort(perm[1:m])
                    println(io, join(tx[i], " "))
                end
            end
            base = Dict{String,Any}("experiment" => "scalability", "series" => cfg.id,
                                    "dataset" => cfg.dataset, "param" => pct)
            run_group!(tr, base, file, cfg.minsup, cfg.algos)
            rm(file; force = true)
        end
    end
end

# ---------- 4) ảnh hưởng độ dài giao dịch trung bình T (dữ liệu tổng hợp) ----------
function exp_txlen(tr, quick)
    c = TXLEN
    modes = [("fixedDT", c.T_dt), ("fixedD", c.T_d)]
    for (mode, Ts) in modes
        println("== txlen: ", mode)
        for T in select_pts(Ts, quick)
            D = mode == "fixedDT" ? c.DT ÷ T : c.D_fixed
            # fixedDT: ngưỡng tuyệt đối = c.count giao dịch. Dùng (count - 0.5)/D để ceil(minsup*D) = count
            # chắc chắn, không bị sai số dấu phẩy động; SPMF không nhận số đếm tuyệt đối.
            minsup = mode == "fixedDT" ? string((c.count - 0.5) / D) : c.rel
            file = joinpath(TMP, "quest_$(mode)_T$(T).txt")
            gen_quest(file; D = D, T = T, I = c.I, L = c.L, N = c.N, seed = SEED + T)
            # "dataset" cố định = "synthetic" để khoá chặn timeout theo series (T tăng dần = khó dần)
            base2 = Dict{String,Any}("experiment" => "txlen", "series" => mode, "dataset" => "synthetic",
                                     "param" => T, "note" => "T=$T D=$D")
            run_group!(tr, base2, file, minsup, ["spmf", "bitarray", "basic"])
            rm(file; force = true)
        end
    end
end

# ---------- 5) hồ sơ theo mức k ----------
function exp_levels(datasets, smoke)
    paths = Dict(ds.name => ds.path for ds in datasets)
    out = joinpath(RESULTS, smoke ? "levels_smoke.csv" : "levels.csv")
    level_profile([[1, 2], [1, 2, 3]], 0.5)                     # khởi động JIT
    open(out, "w") do io
        println(io, "dataset,minsup,k,candidates,frequent,gen_s,count_s")
        for (name, ms) in LEVELS
            haskey(paths, name) && isfile(paths[name]) || continue
            println("== levels: ", name, " @ ", ms)
            tx = read_transactions(paths[name])
            for r in level_profile(tx, parse_minsup(ms))
                println(io, join((name, ms, r.k, r.candidates, r.frequent,
                                  round(r.gen_s; digits = 5), round(r.count_s; digits = 5)), ","))
            end
        end
    end
    println("Đã ghi ", out)
end

function main(args)
    pos, opts = parse_cli(args)
    what = isempty(pos) ? "all" : pos[1]
    quick = haskey(opts, "quick")
    smoke = haskey(opts, "smoke")
    haskey(opts, "basic-timeout") && (TIMEOUTS["basic"] = parse(Float64, opts["basic-timeout"]))
    if haskey(opts, "timeout")
        TIMEOUTS["bitarray"] = TIMEOUTS["spmf"] = parse(Float64, opts["timeout"])
    end
    names = String.(split(get(opts, "datasets", "chess,mushroom,retail,T10I4D100K"), ","))
    datasets = smoke ? SMOKE_DATASETS : [ds for ds in DATASETS if ds.name in names]
    tr = Tracker(joinpath(RESULTS, smoke ? "results_smoke.csv" : "results.csv"))

    println("Julia $(VERSION), seed = $SEED, timeout = $TIMEOUTS")
    what in ("sweep", "all")       && exp_sweep(tr, datasets, quick)
    what in ("memory", "all")      && exp_memory(tr, datasets)
    what in ("scalability", "all") && exp_scalability(tr, datasets, quick)
    what in ("txlen", "all")       && exp_txlen(tr, quick)
    what in ("levels", "all")      && exp_levels(datasets, smoke)
    println("Xong. Kết quả: ", tr.path)
end

main(ARGS)
