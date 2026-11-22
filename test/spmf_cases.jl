# Danh sách case so sánh với SPMF, dùng chung cho:
#   - scripts/spmf_reference.jl : chạy SPMF để tạo file tham chiếu test/data/spmf/<name>.txt
#   - test/test_spmf.jl         : so sánh kết quả của nhóm với các file tham chiếu đó
#
# minsup viết theo cú pháp SPMF (tỉ lệ phần trăm) để hai bên dùng đúng một ngưỡng.

const TEST_DATA_DIR = joinpath(@__DIR__, "data")
const SPMF_REF_DIR = joinpath(TEST_DATA_DIR, "spmf")
const TOY_DB = joinpath(@__DIR__, "..", "data", "toy", "toy1.txt")

db(name) = joinpath(TEST_DATA_DIR, "db", name * ".txt")

# (tên case, file CSDL, minsup)
const SPMF_CASES = [
    ("toy1_50",          TOY_DB,             "50%"),  # ví dụ Fig. 3 của bài báo
    ("toy1_25",          TOY_DB,             "25%"),
    ("toy1_100",         TOY_DB,             "100%"), # không có itemset nào
    ("single_100",       db("single"),       "100%"), # 1 giao dịch: 31 tập con
    ("dense_small_10",   db("dense_small"),  "10%"),
    ("dense_small_50",   db("dense_small"),  "50%"),
    ("long_tx_70",       db("long_tx"),      "70%"),  # dày, itemset dài
    ("sparse_1",         db("sparse"),       "1%"),
    ("sparse_0.3",       db("sparse"),       "0.3%"),
    ("quest_medium_5",   db("quest_medium"), "5%"),
    ("quest_medium_2",   db("quest_medium"), "2%"),
    ("quest_medium_7",   db("quest_medium"), "7%"),   # 0.07*3000 = 210.00000000000003 -> ceil = 211

]

spmf_reference_path(name) = joinpath(SPMF_REF_DIR, name * ".txt")
