# Hạ tầng chạy thực nghiệm: gọi thuật toán của nhóm (process riêng) và SPMF, có timeout,
# ghi CSV tăng dần, hỗ trợ chạy tiếp (resume) và so khớp kết quả với SPMF.
using AprioriFIM
using Random

include(joinpath(@__DIR__, "config.jl"))
include(joinpath(ROOT, "scripts", "spmf_common.jl"))     # SPMF_JAR, SPMF_JAVA

const ALGO_ORDER = ["spmf", "bitarray", "basic"]
const COLUMNS = ["experiment", "series", "dataset", "param", "minsup", "algo", "status",
                 "n_tx", "minsup_count", "n_itemsets", "mine_s", "e2e_s", "wall_s", "alloc_mb",
                 "peak_rss_mb", "rss_base_mb", "rss_delta_mb", "gc_s", "spmf_heap_mb",
                 "n_ref", "matched", "match_rate", "exact", "note"]

sanitize(s) = replace(strip(string(s)), r"[,\r\n]+" => ";")

# ---------- CSV, resume ----------
function emit_csv(path, row::Dict{String,Any})
    mkpath(dirname(path))
    is_new = !isfile(path)
    open(path, "a") do io
        is_new && println(io, join(COLUMNS, ","))
        println(io, join((sanitize(get(row, c, "")) for c in COLUMNS), ","))
    end
end

function load_rows(path)
    rows = Dict{String,String}[]
    isfile(path) || return rows
    lines = readlines(path)
    length(lines) < 2 && return rows
    header = split(lines[1], ",")
    for l in lines[2:end]
        isempty(strip(l)) && continue
        push!(rows, Dict(zip(header, split(l, ","; keepempty = true))))
    end
    return rows
end

rowkey(d, algo) = join((string(get(d, "experiment", "")), string(get(d, "series", "")),
                        string(get(d, "dataset", "")), string(get(d, "param", "")), algo), "|")
blockkey(d, algo) = join((string(get(d, "experiment", "")), string(get(d, "series", "")),
                          string(get(d, "dataset", "")), algo), "|")

mutable struct Tracker
    path::String
    done::Set{String}
    blocked::Set{String}      # (thí nghiệm, series, dataset, algo) đã timeout -> bỏ qua điểm khó hơn
end

function Tracker(path::String)
    done, blocked = Set{String}(), Set{String}()
    for r in load_rows(path)
        get(r, "status", "") == "fail" && continue
        push!(done, rowkey(r, get(r, "algo", "")))
        get(r, "status", "") == "timeout" && push!(blocked, blockkey(r, get(r, "algo", "")))
    end
    return Tracker(path, done, blocked)
end

function emit!(tr::Tracker, row::Dict{String,Any})
    emit_csv(tr.path, row)
    get(row, "status", "") != "fail" && push!(tr.done, rowkey(row, row["algo"]))
    println("  [", row["experiment"], "] ", row["dataset"], " ", row["series"], " param=", row["param"],
            " minsup=", row["minsup"], "  ", rpad(row["algo"], 9), rpad(row["status"], 8),
            " t=", get(row, "e2e_s", ""), "s  n=", get(row, "n_itemsets", ""),
            "  rss=", get(row, "peak_rss_mb", ""), "MB  match=", get(row, "match_rate", ""))
end

# ---------- chạy tiến trình có timeout ----------
function wait_timeout(proc, timeout; on_kill = () -> nothing)
    t0 = time()
    while process_running(proc)
        if time() - t0 > timeout
            kill(proc, Base.SIGKILL)
            on_kill()
            wait(proc)
            return :timeout
        end
        sleep(0.25)
    end
    return success(proc) ? :ok : :failed
end

function parse_kv(text)
    d = Dict{String,String}()
    for l in split(text, '\n')
        startswith(l, "R:") || continue
        kv = split(l[3:end], "="; limit = 2)
        length(kv) == 2 && (d[kv[1]] = strip(kv[2]))
    end
    return d
end

function run_ours(algo, input, minsup, out; timeout, reps = 3)
    log = tempname(TMP)
    cmd = `$(Base.julia_cmd()) --project=$ROOT $RUN_ONE $algo $input $minsup $out $reps`
    t0 = time()
    proc = run(pipeline(cmd; stdout = log * ".out", stderr = log * ".err"), wait = false)
    st = wait_timeout(proc, timeout)
    res = Dict{String,Any}("wall_s" => round(time() - t0; digits = 3))
    if st == :timeout
        res["status"] = "timeout"
    elseif st == :failed
        res["status"] = "fail"
        res["note"] = first(read(log * ".err", String), 200)
    else
        kv = parse_kv(read(log * ".out", String))
        res["status"] = "ok"
        for k in ("n_tx", "minsup_count", "n_itemsets", "mine_s", "e2e_s", "alloc_mb",
                  "peak_rss_mb", "rss_base_mb", "rss_delta_mb", "gc_s")
            res[k] = get(kv, k, "")
        end
    end
    rm(log * ".out"; force = true); rm(log * ".err"; force = true)
    return res
end

# SPMF: thời gian lấy từ dòng "Total time ~ X ms" SPMF tự in (gồm đọc + ghi file, không gồm JVM
# khởi động); peak RSS lấy từ `/usr/bin/time` (macOS: -l, byte; Linux: -v, KB).
function run_spmf_measured(input, out, minsup; timeout, tag)
    isfile(SPMF_JAR) || error("Không tìm thấy $SPMF_JAR. Đặt spmf.jar vào tools/spmf/ hoặc đặt SPMF_JAR.")
    log = tempname(TMP)
    timecmd = Sys.isapple() ? `/usr/bin/time -l` : `/usr/bin/time -v`
    cmd = `$timecmd $SPMF_JAVA -jar $SPMF_JAR run Apriori $input $out $minsup`
    t0 = time()
    proc = run(pipeline(cmd; stdout = log * ".out", stderr = log * ".err"), wait = false)
    # SIGKILL chỉ diệt `time`; JVM con phải diệt riêng.
    st = wait_timeout(proc, timeout; on_kill = () -> run(ignorestatus(`pkill -f $SPMF_JAR`)))
    res = Dict{String,Any}("wall_s" => round(time() - t0; digits = 3))
    stdout_txt = isfile(log * ".out") ? read(log * ".out", String) : ""
    stderr_txt = isfile(log * ".err") ? read(log * ".err", String) : ""
    if st == :timeout
        res["status"] = "timeout"
    elseif st == :failed
        res["status"] = "fail"
        res["note"] = first(stderr_txt, 200)
        occursin("UnsupportedClassVersionError", stderr_txt) &&
            error("spmf.jar cần Java mới hơn `$SPMF_JAVA`. Cài JDK mới hơn rồi đặt biến môi trường SPMF_JAVA.")
    else
        res["status"] = "ok"
        m = match(r"Total time ~\s*([\d.]+)\s*ms", stdout_txt)
        t = m === nothing ? res["wall_s"] : parse(Float64, m.captures[1]) / 1000
        res["mine_s"] = round(t; digits = 5); res["e2e_s"] = res["mine_s"]
        m = match(r"Maximum memory usage\s*:\s*([\d.]+)\s*mb", stdout_txt)
        m === nothing || (res["spmf_heap_mb"] = m.captures[1])
        m = match(r"Frequent itemsets count\s*:\s*(\d+)", stdout_txt)
        m === nothing || (res["n_itemsets"] = m.captures[1])
        if Sys.isapple()
            m = match(r"(\d+)\s+maximum resident set size", stderr_txt)
            m === nothing || (res["peak_rss_mb"] = round(parse(Float64, m.captures[1]) / 2^20; digits = 2))
        else
            m = match(r"Maximum resident set size \(kbytes\):\s*(\d+)", stderr_txt)
            m === nothing || (res["peak_rss_mb"] = round(parse(Float64, m.captures[1]) / 1024; digits = 2))
        end
        m === nothing && (res["note"] = "khong doc duoc RSS")
        isfile(log * ".out") && cp(log * ".out", joinpath(LOGS, replace(tag, r"[^A-Za-z0-9_.-]" => "-") * ".txt"); force = true)
    end
    rm(log * ".out"; force = true); rm(log * ".err"; force = true)
    return res
end

# ---------- một "điểm" thí nghiệm: SPMF + bitarray + basic trên cùng input/minsup ----------
function run_group!(tr::Tracker, base::Dict{String,Any}, input, minsup, algos; reps = 3)
    pending = [a for a in algos if !(blockkey(base, a) in tr.blocked)]
    if all(a -> rowkey(base, a) in tr.done, pending)
        return                                   # điểm này đã xong ở lần chạy trước
    end
    tag = join((base["experiment"], base["series"], base["dataset"], base["param"]), "_")
    ref_path = joinpath(TMP, "ref_$(getpid()).txt")
    out_path = joinpath(TMP, "out_$(getpid()).txt")
    ref = nothing
    spmf_ok = false
    for a in ALGO_ORDER
        a in algos || continue
        row = copy(base); row["algo"] = a; row["minsup"] = minsup
        if blockkey(base, a) in tr.blocked
            row["status"] = "skipped"
            emit!(tr, row)
            continue
        end
        res = a == "spmf" ?
              run_spmf_measured(input, ref_path, minsup; timeout = TIMEOUTS["spmf"], tag = tag * "_spmf") :
              run_ours(a, input, minsup, out_path; timeout = TIMEOUTS[a], reps = reps)
        merge!(row, res)
        row["status"] == "timeout" && push!(tr.blocked, blockkey(base, a))
        if a == "spmf"
            spmf_ok = row["status"] == "ok"
        elseif row["status"] == "ok" && spmf_ok
            ref === nothing && (ref = read_itemsets(ref_path))
            cmp = compare_itemsets(read_itemsets(out_path), ref)
            row["n_ref"] = cmp.n_reference
            row["matched"] = cmp.matched
            row["match_rate"] = round(cmp.match_rate; digits = 6)
            row["exact"] = cmp.exact
            cmp.exact || println("  !! KẾT QUẢ LỆCH SPMF: ", tag, " ", a, " (xem print_comparison trong scripts/)")
        end
        emit!(tr, row)
        rm(out_path; force = true)
    end
    rm(ref_path; force = true)
    return nothing
end
