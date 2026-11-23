import pandas as pd, numpy as np, re
d=pd.read_csv('results.csv',dtype=str,keep_default_na=False)
d=d.drop_duplicates(subset=["experiment","series","dataset","param","algo"],keep="last").copy()
for c in ["n_tx","n_itemsets","mine_s","e2e_s","alloc_mb","peak_rss_mb","rss_delta_mb","match_rate","wall_s","n_ref","matched"]: d[c]=pd.to_numeric(d[c],errors="coerce")
L=pd.read_csv('levels.csv'); cor=pd.read_csv('tables/correctness.csv')
V={}
def f(x,n=2):
    if pd.isna(x): return "—"
    return f"{x:,.{n}f}".replace(",","·").replace(".",",").replace("·",".") if abs(x)>=1000 else f"{x:.{n}f}".replace(".",",")
def fi(x): return f"{int(x):,}".replace(",",".")
def md(df):
    cols=list(df.columns); out="| "+" | ".join(cols)+" |\n|"+"|".join(["---"]*len(cols))+"|\n"
    for _,r in df.iterrows(): out+="| "+" | ".join(str(v) for v in r.values)+" |\n"
    return out
def pnum(m): return float(m[:-1])
S=d[d.experiment=="sweep"]
order={n:sorted(set(S[S.dataset==n].param),key=lambda m:-pnum(m)) for n in ["chess","mushroom","retail","T10I4D100K"]}
def get(ds,ms,algo,col="e2e_s",exp="sweep"):
    x=d[(d.experiment==exp)&(d.series==ds)&(d.param==ms)&(d.algo==algo)]
    return x[col].iloc[0] if len(x) else np.nan
# T_DATA
ntx_m=d[(d.experiment=='sweep')&(d.series=='mushroom')&(d.algo=='bitarray')].n_tx.dropna().iloc[0]
data=[("Chess","dày",3196,75,"≈ 37"),("Mushroom","dày",int(ntx_m),119,"≈ 23"),("Retail","thưa",88162,16470,"≈ 10,3"),("T10I4D100K","thưa (tổng hợp Quest)",100000,870,"≈ 10,1")]
ntx={r.series:r.n_tx for _,r in d[(d.experiment=="sweep")&(d.algo=="bitarray")&(d.status=="ok")].drop_duplicates("series").iterrows()}
chk={"Chess":ntx["chess"],"Mushroom":ntx["mushroom"],"Retail":ntx["retail"],"T10I4D100K":ntx["T10I4D100K"]}
print("n_tx check",chk)
V["T_DATA"]=md(pd.DataFrame([(a,b,fi(c),fi(e),g) for a,b,c,e,g in data],columns=["Tập","Loại","Số giao dịch","Số item","Độ dài TB (theo mô tả công bố)"]))
# T_CORR
c=cor.copy(); c=c[["dataset","algo","#điểm minsup","#itemset SPMF","#khớp","tỉ lệ khớp (%)"]]
c["#itemset SPMF"]=c["#itemset SPMF"].map(fi); c["#khớp"]=c["#khớp"].map(fi); c["tỉ lệ khớp (%)"]=c["tỉ lệ khớp (%)"].map(lambda x:f"{x:.2f}".replace(".",","))
c.columns=["Tập","Thuật toán","Số điểm","Số itemset SPMF","Số khớp","Tỉ lệ khớp (%)"]
V["T_CORR"]=md(c)
for a,k in [("bitarray","BIT"),("basic","BAS")]:
    x=cor[cor.algo==a]; V[f"CORR_POINTS_{k}"]=str(int(x["#điểm minsup"].sum())); V[f"CORR_ITEMS_{k}"]=fi(x["#itemset SPMF"].sum())
# T_TIME + speedups
rows=[]
for ds in order:
    o=order[ds]; sel=[o[0],o[len(o)//2],o[-1]]
    for ms in sel:
        b,bi,sp=get(ds,ms,"basic"),get(ds,ms,"bitarray"),get(ds,ms,"spmf")
        rows.append((ds,ms,fi(get(ds,ms,"bitarray","n_itemsets")),("timeout (>900)" if (d[(d.experiment=='sweep')&(d.series==ds)&(d.param==ms)&(d.algo=='basic')].status=='timeout').any() else ("bỏ qua" if np.isnan(b) else f(b,2))),f(bi,3),f(sp,3),("—" if np.isnan(b) else f(b/bi,1)+"×"),f(sp/bi,2)+"×"))
V["T_TIME"]=md(pd.DataFrame(rows,columns=["Tập","minsup","#itemset","basic","bitarray","SPMF","basic/bitarray","SPMF/bitarray"]))
sb=lambda ds,ms: get(ds,ms,"basic")/get(ds,ms,"bitarray")
ss=lambda ds,ms: get(ds,ms,"spmf")/get(ds,ms,"bitarray")
V.update(SP_T10_HI=f(sb("T10I4D100K","2%"),0),SP_T10_LO=fi(sb("T10I4D100K","0.15%")),SP_RET_HI=f(sb("retail","2%"),1),SP_RET_LO=f(sb("retail","0.25%"),0),
 SP_T10_MAX=fi(sb("T10I4D100K","0.15%")),
 SP_CHESS_MAX=f(max(sb("chess",m) for m in order["chess"]),0),SP_MUSH_MAX=f(max(sb("mushroom",m) for m in order["mushroom"]),0),
 BAS_RET_025=f(get("retail","0.25%","basic"),0),BAS_T10_015=f(get("T10I4D100K","0.15%","basic"),0),BIT_T10_015=f(get("T10I4D100K","0.15%","bitarray"),2))
allr=[ss(ds,m) for ds in order for m in order[ds]]
faster=[x for x in allr if x>1]
V.update(N_FASTER=str(len(faster)),N_TOTAL=str(len(allr)),SPMF_MIN=f(min(faster),2),SPMF_MAX=f(max(faster),1),
 RET2_SPMF=f(get("retail","2%","spmf"),3),RET2_BIT=f(get("retail","2%","bitarray"),3),
 SPMF_T10_HI=f(ss("T10I4D100K","2%"),2),SPMF_T10_LO=f(ss("T10I4D100K","0.15%"),2),SPMF_RET_LO=f(ss("retail","0.15%"),1),
 SPMF_CHESS_MIN=f(min(ss("chess",m) for m in order["chess"]),2),SPMF_CHESS_MAX=f(max(ss("chess",m) for m in order["chess"]),2),
 MUSH10_SPMF=f(get("mushroom","10%","spmf"),2),MUSH10_BIT=f(get("mushroom","10%","bitarray"),2),RET01_SPMF=f(get("retail","0.1%","spmf"),1),RET01_BIT=f(get("retail","0.1%","bitarray"),2))
# T_ITEMS
typ={"chess":"dày","mushroom":"dày","retail":"thưa","T10I4D100K":"thưa"}; rows=[]
for ds in order:
    o=order[ds]; lo=get(ds,o[0],"bitarray","n_itemsets"); hi=get(ds,o[-1],"bitarray","n_itemsets")
    rows.append((ds,typ[ds],f"{o[0]}: {fi(lo)}",f"{o[-1]}: {fi(hi)}",f(hi/lo,0)+"×"))
    V["GROW_"+{"chess":"CHESS","mushroom":"MUSH","retail":"RET","T10I4D100K":"T10"}[ds]]=fi(hi/lo)
V["T_ITEMS"]=md(pd.DataFrame(rows,columns=["Tập","Loại","minsup cao nhất: #itemset","minsup thấp nhất: #itemset","Hệ số tăng"]))
# T_MEM
M=d[d.experiment=="memory"]; rows=[]
for ds,ms in [("chess","85%"),("mushroom","35%"),("retail","0.5%"),("T10I4D100K","0.5%")]:
    g=lambda a,c: M[(M.series==ds)&(M.algo==a)][c].iloc[0]
    rows.append((ds,ms,f(g("basic","alloc_mb"),1),f(g("bitarray","alloc_mb"),1),f(g("basic","rss_delta_mb"),1),f(g("bitarray","rss_delta_mb"),1),f(g("basic","peak_rss_mb"),0),f(g("bitarray","peak_rss_mb"),0),f(g("spmf","peak_rss_mb"),0)))
V["T_MEM"]=md(pd.DataFrame(rows,columns=["Tập","minsup","alloc basic","alloc bitarray","Δ basic","Δ bitarray","peak basic","peak bitarray","peak SPMF"]))
ar=[]
for ds,ms in [("chess","85%"),("mushroom","35%"),("retail","0.5%"),("T10I4D100K","0.5%")]:
    ar.append(M[(M.series==ds)&(M.algo=="basic")].alloc_mb.iloc[0]/M[(M.series==ds)&(M.algo=="bitarray")].alloc_mb.iloc[0])
V["ALLOC_RATIO_MIN"]=f(min(ar),1); V["ALLOC_RATIO_MAX"]=f(max(ar),1)
mm=lambda ds,a,c: M[(M.series==ds)&(M.algo==a)][c].iloc[0]
V.update(ALLOC_MUSH_BAS=f(mm("mushroom","basic","alloc_mb"),1),ALLOC_MUSH_BIT=f(mm("mushroom","bitarray","alloc_mb"),1),ALLOC_RET_BAS=f(mm("retail","basic","alloc_mb"),1),ALLOC_RET_BIT=f(mm("retail","bitarray","alloc_mb"),1),D_RET_BAS=f(mm("retail","basic","rss_delta_mb"),1),D_RET_BIT=f(mm("retail","bitarray","rss_delta_mb"),1))
rows=[]
for ds,ms in [("chess","65%"),("mushroom","10%"),("retail","0.15%"),("retail","0.1%"),("T10I4D100K","0.15%")]:
    r=[ds,ms]
    for a in ["basic","bitarray","spmf"]:
        x=d[(d.experiment=="sweep")&(d.series==ds)&(d.param==ms)&(d.algo==a)]
        if x.status.iloc[0]!="ok": r.append("timeout/bỏ qua"); continue
        x=x.iloc[0]; r.append(f"peak {f(x.peak_rss_mb,0)}"+("" if a=="spmf" else f"; Δ {f(x.rss_delta_mb,0)}; alloc {f(x.alloc_mb,0)}"))
    rows.append(r)
V["T_MEM_LOW"]=md(pd.DataFrame(rows,columns=["Tập","minsup","basic","bitarray","SPMF"]))
sw=lambda ds,ms,a,c: get(ds,ms,a,c)
V.update(D_M10_BIT=f(sw("mushroom","10%","bitarray","rss_delta_mb"),0),A_M10_BIT=f(sw("mushroom","10%","bitarray","alloc_mb"),0),D_M10_BAS=f(sw("mushroom","10%","basic","rss_delta_mb"),0),A_M10_BAS=f(sw("mushroom","10%","basic","alloc_mb"),0),
 D_R01_BIT=f(sw("retail","0.1%","bitarray","rss_delta_mb"),0),A_R01_BIT=fi(sw("retail","0.1%","bitarray","alloc_mb")),P_R01_SPMF=f(sw("retail","0.1%","spmf","peak_rss_mb"),0))
# scalability
sc=d[d.experiment=="scalability"]; sl=pd.read_csv('tables/scalability_slopes.csv'); rows=[]
for sid in ["retail_1pct","retail_0.3pct"]:
    for a in ["basic","bitarray","spmf"]:
        x=sc[(sc.series==sid)&(sc.algo==a)]
        if not len(x): continue
        t10=x[x.param=="10"].e2e_s.iloc[0]; t100=x[x.param=="100"].e2e_s.iloc[0]
        rows.append((sid.replace("retail_","Retail ").replace("pct","%").replace("1%","1%").replace("0.3%","0,3%"),a,f(t10,3),f(t100,3),f(t100/t10,1)+"×",f(sl[(sl.series==sid)&(sl.algo==a)]["log-log slope"].iloc[0],2)))
V["T_SCAL"]=md(pd.DataFrame(rows,columns=["Chuỗi","Thuật toán","t(10%)","t(100%)","t(100%)/t(10%)","Hệ số góc"]))
V["SCAL_ITEMS_1"]="157–161"; V["SCAL_ITEMS_03"]="1.381–1.413"
# txlen
X=d[d.experiment=="txlen"]; rows=[]
for mode in ["fixedDT","fixedD"]:
    for T in sorted(set(X[X.series==mode].param),key=int):
        g=lambda a,c="e2e_s": X[(X.series==mode)&(X.param==T)&(X.algo==a)][c].iloc[0]
        D=X[(X.series==mode)&(X.param==T)].note.iloc[0].split("D=")[1]
        rows.append((mode,T,fi(D),fi(g("bitarray","n_itemsets")),f(g("basic"),1),f(g("bitarray"),3),f(g("spmf"),3)))
V["T_TXLEN"]=md(pd.DataFrame(rows,columns=["Thiết lập","T","D","#itemset","basic","bitarray","SPMF"]))
xg=lambda mode,T,a,c="e2e_s": X[(X.series==mode)&(X.param==str(T))&(X.algo==a)][c].iloc[0]
V.update(TX_ITEMS_LO=fi(xg("fixedD",5,"bitarray","n_itemsets")),TX_ITEMS_HI=fi(xg("fixedD",30,"bitarray","n_itemsets")),TX_GROW=f(xg("fixedD",30,"bitarray","n_itemsets")/xg("fixedD",5,"bitarray","n_itemsets"),0),
 TX_SPMF_X=f(xg("fixedD",30,"spmf")/xg("fixedD",5,"spmf"),0),TX_BAS_X=f(xg("fixedD",30,"basic")/xg("fixedD",5,"basic"),0),TX_BIT_X=f(xg("fixedD",30,"bitarray")/xg("fixedD",5,"bitarray"),0),
 FDT_SPMF_LO=f(xg("fixedDT",5,"spmf"),2),FDT_SPMF_HI=f(xg("fixedDT",40,"spmf"),2),FDT_BAS_LO=f(xg("fixedDT",5,"basic"),0),FDT_BAS_HI=f(xg("fixedDT",40,"basic"),0))
fb=[xg("fixedDT",T,"bitarray") for T in [10,15,20,25,30,40]]
V["FDT_BIT_RANGE"]=f"{min(fb):.3f}–{max(fb):.3f}".replace(".",",")
fi_=X[(X.series=="fixedDT")&(X.algo=="bitarray")].n_itemsets
V["FDT_ITEMS_MIN"]=fi(fi_.min()); V["FDT_ITEMS_MAX"]=fi(fi_.max())
# levels
rows=[]; L["tot"]=L.gen_s+L.count_s
key={"chess":"CHESS","mushroom":"MUSH","retail":"RET","T10I4D100K":"T10"}
for (ds,ms),g in L.groupby(["dataset","minsup"],sort=False):
    if ds not in key: continue
    K=key[ds]; l1=int(g[g.k==1].frequent.iloc[0]); c2=int(g[g.k==2].candidates.iloc[0]); l2=int(g[g.k==2].frequent.iloc[0])
    t=g.tot.sum(); k2=g[g.k==2].tot.sum(); r3=g[g.k>=3].frequent.sum()/g[g.k>=3].candidates.sum(); maxk=int(g[g.frequent>0].k.max())
    rows.append((ds,ms,fi(l1),fi(c2),fi(l2),f(c2/l2,1),f(100*k2/t,1)+"%",f(100*g.gen_s.sum()/t,0)+"%",f(r3,2),maxk))
    V["K2_"+K]=f(100*k2/t,0); V["LC_"+K]=f(r3,2); V["GEN_"+K]=f(100*g.gen_s.sum()/t,0)
    if K in("RET","T10"): V["PCT_"+K]=f(100*l2/c2,2); V["R_"+K]=f(c2/l2,0)
    if K=="CHESS": V["SUML_CHESS"]=fi(g[g.k>=2].frequent.sum())
    if K=="T10": V["T10_K2_MS"]=f(1000*k2,0); V["T10_K2_GEN"]=f(1000*g[g.k==2].gen_s.iloc[0],0)
V["T_LEVELS"]=md(pd.DataFrame(rows,columns=["Tập","minsup","#L₁","#C₂","#L₂","#C₂ / #L₂","k=2 / tổng t","sinh ứng viên / tổng t","#L_k / #C_k (k≥3)","k tối đa"]))
s=open('template.md').read()
for k,v in V.items(): s=s.replace("@@"+k+"@@",v)
left=set(re.findall(r"@@(\w+)@@",s)); print("LEFT",left)
open('chapter2_report.md','w').write(s); print(len(s.split()),"words")
for k in ["N_FASTER","N_TOTAL","SPMF_MIN","SPMF_MAX","SP_T10_HI","SP_RET_HI","K2_RET","K2_T10","LC_RET","PCT_RET","GEN_T10","ALLOC_RATIO_MIN","ALLOC_RATIO_MAX","FDT_BIT_RANGE"]: print(k,V[k])
