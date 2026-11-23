#!/usr/bin/env python3
"""Vẽ biểu đồ và bảng Chương 2 từ experiments/results/results.csv (+ levels.csv).
    python3 experiments/plot_results.py [--results experiments/results] [--smoke]
Cần: pandas, numpy, matplotlib. Xuất PNG + PDF vào experiments/figures/, bảng markdown vào experiments/tables/.
"""
import argparse, os
import numpy as np, pandas as pd
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

ap = argparse.ArgumentParser()
ap.add_argument("--results", default=os.path.join(os.path.dirname(__file__), "results"))
ap.add_argument("--smoke", action="store_true")
args = ap.parse_args()
sfx = "_smoke" if args.smoke else ""
FIG = os.path.join(os.path.dirname(__file__), "figures" + sfx)
TAB = os.path.join(os.path.dirname(__file__), "tables" + sfx)
os.makedirs(FIG, exist_ok=True); os.makedirs(TAB, exist_ok=True)

STYLE = {"basic": ("tab:red", "s", "Apriori cơ bản (basic)"),
         "bitarray": ("tab:blue", "o", "Apriori BitArray (tối ưu)"),
         "spmf": ("tab:green", "^", "SPMF Apriori")}
DENSE = {"chess": "dày", "mushroom": "dày", "accidents": "dày", "retail": "thưa",
         "T10I4D100K": "thưa", "quest_medium": "thưa (thử nghiệm)"}
plt.rcParams.update({"font.size": 9, "axes.grid": True, "grid.alpha": .3, "figure.dpi": 120})


def save(fig, name):
    fig.tight_layout()
    for ext in ("png", "pdf"):
        fig.savefig(os.path.join(FIG, f"{name}.{ext}"), dpi=200)
    plt.close(fig)
    print("saved", name)


def ms_pct(s):
    s = str(s).strip()
    return float(s[:-1]) if s.endswith("%") else float(s) * 100


df = pd.read_csv(os.path.join(args.results, f"results{sfx}.csv"), dtype=str, keep_default_na=False)
key = ["experiment", "series", "dataset", "param", "algo"]
df = df.drop_duplicates(subset=key, keep="last").copy()       # dòng cuối của điểm chạy lại
for c in ["n_tx", "minsup_count", "n_itemsets", "mine_s", "e2e_s", "wall_s", "alloc_mb", "peak_rss_mb",
          "rss_base_mb", "rss_delta_mb", "gc_s", "spmf_heap_mb", "n_ref", "matched", "match_rate"]:
    df[c] = pd.to_numeric(df[c], errors="coerce")

# ---------- 1) Correctness ----------
sw = df[(df.experiment.isin(["sweep", "memory", "scalability", "txlen"])) & (df.algo != "spmf")
        & (df.status == "ok") & df.n_ref.notna()]
rows = []
for (ds, algo), g in sw.groupby(["dataset", "algo"]):
    rows.append((ds, algo, len(g), int(g.n_ref.sum()), int(g.matched.sum()),
                 100 * g.matched.sum() / max(g.n_ref.sum(), 1), (g.exact == "true").all()))
cor = pd.DataFrame(rows, columns=["dataset", "algo", "#điểm minsup", "#itemset SPMF", "#khớp", "tỉ lệ khớp (%)", "mọi điểm khớp 100%"])
if len(cor):
    # tỉ lệ theo công thức: khớp / |hợp| ở từng điểm, lấy min để thể hiện trường hợp xấu nhất
    mn = sw.groupby(["dataset", "algo"]).match_rate.min().reset_index(name="min match_rate")
    cor = cor.merge(mn, on=["dataset", "algo"])
    cor["min match_rate"] = (100 * cor["min match_rate"]).round(3)
    cor["tỉ lệ khớp (%)"] = cor["tỉ lệ khớp (%)"].round(3)
    open(os.path.join(TAB, "correctness.md"), "w").write(cor.to_markdown(index=False))
    cor.to_csv(os.path.join(TAB, "correctness.csv"), index=False)
    print(cor.to_string(index=False))

# ---------- 2) Thời gian theo minsup (mỗi dataset một hình) ----------
S = df[df.experiment == "sweep"].copy()
S["x"] = S.minsup.map(ms_pct)
names = [d for d in ["chess", "mushroom", "retail", "T10I4D100K", "accidents", "quest_medium"] if d in set(S.dataset)]
for ds in names:
    fig, ax = plt.subplots(figsize=(4.2, 3.2))
    g = S[S.dataset == ds]
    for algo, (col, mk, lab) in STYLE.items():
        a = g[g.algo == algo].sort_values("x")
        ok = a[a.status == "ok"]
        if len(ok):
            ax.plot(ok.x, ok.e2e_s, color=col, marker=mk, label=lab + " (đọc+khai thác+ghi)" if algo != "spmf" else lab)
            if algo != "spmf":
                ax.plot(ok.x, ok.mine_s, color=col, marker=mk, ls=":", alpha=.6, ms=3, label=lab.split(" (")[0] + " (chỉ khai thác)")
        to = a[a.status == "timeout"]
        if len(to):
            ax.scatter(to.x, to.wall_s, color=col, marker="x", s=60, zorder=5, label=f"{algo}: quá hạn")
    ax.set_xscale("log"); ax.set_yscale("log"); ax.invert_xaxis()
    ax.set_xlabel("minsup (%), giảm dần →"); ax.set_ylabel("thời gian (s)")
    ax.set_title(f"{ds} ({DENSE.get(ds, '')})")
    ax.legend(fontsize=6)
    save(fig, f"runtime_{ds}")

# ---------- 3) Số itemset theo minsup ----------
if names:
    fig, axes = plt.subplots(1, len(names), figsize=(3.2 * len(names), 3.0), squeeze=False)
    for ax, ds in zip(axes[0], names):
        g = S[(S.dataset == ds) & (S.status == "ok")]
        n = g[g.algo.isin(["bitarray", "spmf", "basic"])].groupby("x").n_itemsets.max().sort_index()
        ax.plot(n.index, n.values, "o-", color="tab:purple")
        ax.set_xscale("log"); ax.set_yscale("log"); ax.invert_xaxis()
        ax.set_title(f"{ds} ({DENSE.get(ds, '')})"); ax.set_xlabel("minsup (%)")
    axes[0][0].set_ylabel("số frequent itemset")
    save(fig, "itemsets_vs_minsup")

# ---------- 4) Peak RAM ----------
M = df[(df.experiment == "memory") & (df.status == "ok")]
if len(M):
    ds_list = [d for d in names if d in set(M.dataset)]
    fig, axes = plt.subplots(1, 2, figsize=(7.5, 3.2))
    w = 0.27
    for i, algo in enumerate(["basic", "bitarray", "spmf"]):
        col, _, lab = STYLE[algo]
        v = [M[(M.dataset == d) & (M.algo == algo)].peak_rss_mb.mean() for d in ds_list]
        axes[0].bar(np.arange(len(ds_list)) + (i - 1) * w, v, w, color=col, label=lab)
    axes[0].set_xticks(range(len(ds_list))); axes[0].set_xticklabels(ds_list, rotation=15)
    axes[0].set_ylabel("peak RSS của process (MB)"); axes[0].legend(fontsize=6); axes[0].set_title("Peak RAM toàn process")
    for i, algo in enumerate(["basic", "bitarray"]):
        col, _, lab = STYLE[algo]
        v = [M[(M.dataset == d) & (M.algo == algo)].rss_delta_mb.mean() for d in ds_list]
        axes[1].bar(np.arange(len(ds_list)) + (i - .5) * w * 1.3, v, w * 1.3, color=col, label=lab)
    axes[1].set_xticks(range(len(ds_list))); axes[1].set_xticklabels(ds_list, rotation=15)
    axes[1].set_ylabel("tăng RSS khi khai thác (MB)"); axes[1].set_yscale("symlog"); axes[1].set_title("Phần tăng do thuật toán")
    axes[1].legend(fontsize=6)
    save(fig, "memory")
    t = M.pivot_table(index="dataset", columns="algo", values=["peak_rss_mb", "rss_delta_mb", "alloc_mb", "e2e_s"], aggfunc="mean").round(2)
    t.to_csv(os.path.join(TAB, "memory.csv")); open(os.path.join(TAB, "memory.md"), "w").write(t.to_markdown())

# ---------- 5) Scalability ----------
Sc = df[(df.experiment == "scalability") & (df.status == "ok")].copy()
if len(Sc):
    Sc["p"] = pd.to_numeric(Sc.param)
    series = sorted(set(Sc.series))
    fig, axes = plt.subplots(1, 2, figsize=(7.5, 3.2))
    slopes = []
    for sid in series:
        for algo, (col, mk, lab) in STYLE.items():
            a = Sc[(Sc.series == sid) & (Sc.algo == algo)].sort_values("p")
            if len(a) < 2: continue
            ls = {0: "-", 1: "--", 2: "-.", 3: ":"}[series.index(sid) % 4]
            axes[0].plot(a.p, a.e2e_s, color=col, marker=mk, ls=ls, label=f"{sid} / {algo}")
            axes[1].plot(a.p, a.e2e_s / a.e2e_s.iloc[-1], color=col, marker=mk, ls=ls)
            if len(a) >= 3:
                sl = np.polyfit(np.log(a.p), np.log(a.e2e_s), 1)[0]
                slopes.append((sid, algo, round(sl, 2)))
    axes[1].plot([10, 100], [.1, 1], "k--", lw=1, label="tuyến tính lý tưởng")
    axes[0].set_xlabel("% giao dịch"); axes[0].set_ylabel("thời gian (s)"); axes[0].legend(fontsize=5)
    axes[1].set_xlabel("% giao dịch"); axes[1].set_ylabel("t(p) / t(100%)"); axes[1].legend(fontsize=6)
    axes[0].set_title("Thời gian theo kích thước CSDL"); axes[1].set_title("Chuẩn hoá (so với tuyến tính)")
    save(fig, "scalability")
    pd.DataFrame(slopes, columns=["series", "algo", "log-log slope"]).to_csv(os.path.join(TAB, "scalability_slopes.csv"), index=False)
    print("slopes (1.0 = tuyến tính):", slopes)

# ---------- 6) Độ dài giao dịch ----------
X = df[df.experiment == "txlen"].copy()
if len(X):
    X["T"] = pd.to_numeric(X.param)
    modes = sorted(set(X.series))
    fig, axes = plt.subplots(len(modes), 2, figsize=(7.5, 3.0 * len(modes)), squeeze=False)
    for r, mode in enumerate(modes):
        g = X[X.series == mode]
        for algo, (col, mk, lab) in STYLE.items():
            a = g[(g.algo == algo)].sort_values("T")
            ok = a[a.status == "ok"]
            axes[r][0].plot(ok["T"], ok.e2e_s, color=col, marker=mk, label=lab)
            to = a[a.status == "timeout"]
            if len(to): axes[r][0].scatter(to["T"], to.wall_s, color=col, marker="x", s=60)
        n = g[g.status == "ok"].groupby("T").n_itemsets.max()
        axes[r][1].plot(n.index, n.values, "o-", color="tab:purple")
        title = "D×T không đổi, minsup tuyệt đối" if mode == "fixedDT" else "D không đổi, minsup tương đối"
        axes[r][0].set_title(title); axes[r][0].set_yscale("log"); axes[r][1].set_yscale("log")
        axes[r][0].set_xlabel("độ dài giao dịch TB (T)"); axes[r][0].set_ylabel("thời gian (s)")
        axes[r][1].set_xlabel("T"); axes[r][1].set_ylabel("số frequent itemset")
        axes[r][0].legend(fontsize=6)
    save(fig, "txlen")

# ---------- 7) Hồ sơ theo mức k ----------
lv_path = os.path.join(args.results, f"levels{sfx}.csv")
if os.path.exists(lv_path):
    L = pd.read_csv(lv_path)
    groups = list(L.groupby(["dataset", "minsup"], sort=False))
    nc = min(3, len(groups)); nr = int(np.ceil(len(groups) / nc))
    fig, axes = plt.subplots(nr, nc, figsize=(3.3 * nc, 2.7 * nr), squeeze=False)
    for ax, ((ds, ms), g) in zip(axes.flat, groups):
        ax.bar(g.k - .2, g.candidates.clip(lower=.5), .4, color="tab:orange", label="|C_k| ứng viên")
        ax.bar(g.k + .2, g.frequent.clip(lower=.5), .4, color="tab:blue", label="|L_k| phổ biến")
        ax.set_yscale("log"); ax.set_title(f"{ds} @ {ms}", fontsize=8); ax.set_xlabel("k")
    axes.flat[0].legend(fontsize=6)
    for ax in list(axes.flat)[len(groups):]: ax.axis("off")
    save(fig, "levels")
print("Xong.")
