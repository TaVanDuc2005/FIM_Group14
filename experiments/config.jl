# Cấu hình chung cho các thực nghiệm Chương 2.
# Sửa lưới minsup / timeout ở đây nếu máy chạy quá chậm hoặc quá nhanh.

const ROOT    = abspath(joinpath(@__DIR__, ".."))
const RAW     = joinpath(ROOT, "data", "raw")
const RESULTS = joinpath(@__DIR__, "results")
const TMP     = joinpath(RESULTS, "tmp")
const LOGS    = joinpath(RESULTS, "logs")
mkpath(TMP); mkpath(LOGS)

const SEED    = 14                                   # seed cố định (nhóm 14)
const RUN_ONE = joinpath(@__DIR__, "run_one.jl")

# grid: minsup giảm dần (cao -> thấp), 7 điểm. mem: minsup "trung bình" cho thực nghiệm RAM,
# chọn đủ cao để bản basic còn chạy xong. Các mốc này là ước lượng: nếu bản bitarray/SPMF
# chạy quá lâu hoặc output quá lớn, hãy nâng mốc thấp nhất.
const DATASETS = [
    (name = "chess",      path = joinpath(RAW, "chess.txt"),
     grid = ["95%", "90%", "85%", "80%", "75%", "70%", "65%"],        mem = "85%"),
    (name = "mushroom",   path = joinpath(RAW, "mushroom.txt"),
     grid = ["50%", "40%", "30%", "25%", "20%", "15%", "10%"],        mem = "35%"),
    (name = "retail",     path = joinpath(RAW, "retail.txt"),
     grid = ["2%", "1%", "0.5%", "0.35%", "0.25%", "0.15%", "0.1%"],  mem = "0.5%"),
    (name = "T10I4D100K", path = joinpath(RAW, "T10I4D100K.txt"),
     grid = ["2%", "1%", "0.75%", "0.5%", "0.35%", "0.25%", "0.15%"], mem = "0.5%"),
    (name = "accidents",  path = joinpath(RAW, "accidents.txt"),
     grid = ["90%", "80%", "70%", "60%", "50%", "45%", "40%"],        mem = "70%"),
]

# Bộ nhỏ để chạy thử toàn bộ pipeline (không cần tải dữ liệu): --smoke
const SMOKE_DATASETS = [
    (name = "quest_medium", path = joinpath(ROOT, "test", "data", "db", "quest_medium.txt"),
     grid = ["10%", "7%", "5%", "3%", "2%"], mem = "5%"),
]

# Scalability: tập con 10..100% giao dịch (lấy mẫu ngẫu nhiên có seed, lồng nhau).
const SIZES = [10, 25, 50, 75, 100]
const SCAL = [
    (id = "retail_1pct",      dataset = "retail",    minsup = "1%",   algos = ["spmf", "bitarray", "basic"]),
    (id = "retail_0.3pct",    dataset = "retail",    minsup = "0.3%", algos = ["spmf", "bitarray"]),
    (id = "accidents_60pct",  dataset = "accidents", minsup = "60%",  algos = ["spmf", "bitarray"]),
    (id = "quest_medium_5pct", dataset = "quest_medium", minsup = "5%", algos = ["spmf", "bitarray", "basic"]),
]

# Độ dài giao dịch: bộ sinh kiểu IBM Quest (mục 4.3 bài báo).
#  fixedDT: D*T không đổi, minsup là số đếm tuyệt đối (như bài báo, mục 4.8).
#  fixedD : D không đổi, minsup tương đối không đổi.
const TXLEN = (N = 1000, L = 2000, I = 4,
               DT = 500_000, count = 500, T_dt = [5, 10, 15, 20, 25, 30, 40],
               D_fixed = 20_000, rel = "1%", T_d = [5, 10, 15, 20, 25, 30])

# Phân tích theo từng mức k (|C_k| vs |L_k|): (dataset, minsup)
const LEVELS = [("chess", "80%"), ("mushroom", "30%"), ("retail", "0.3%"),
                ("T10I4D100K", "0.35%"), ("accidents", "60%"), ("quest_medium", "3%")]

# Timeout (giây) cho mỗi lần chạy. Quá hạn -> ghi "timeout" và bỏ qua các điểm khó hơn.
const TIMEOUTS = Dict("basic" => 900.0, "bitarray" => 1800.0, "spmf" => 1800.0)
