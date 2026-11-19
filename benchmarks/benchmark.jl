# julia --project benchmarks/benchmark.jl
# TODO: với mỗi dataset trong data/raw/ và mỗi minsup (5-7 điểm):
#   - đo thời gian (@elapsed) và bộ nhớ (@allocated) của basic và bitarray
#   - so sánh với SPMF, ghi CSV vào benchmarks/results.csv
using AprioriFIM

const DATASETS = ["chess", "mushroom", "retail", "T10I4D100K"]
println("TODO: benchmark ", DATASETS)
