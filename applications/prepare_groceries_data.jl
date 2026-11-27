# Ứng dụng 1: lấy dữ liệu giỏ hàng Groceries. File đã được lưu sẵn trong data/market/groceries.csv,
# nên KHÔNG cần chạy script này để chạy notebook hay test. Chỉ chạy khi file bị mất/hỏng, hoặc để
# kiểm chứng lại nguồn.
#   julia --project applications/prepare_groceries_data.jl           # có file hợp lệ thì bỏ qua; thiếu hoặc hỏng thì tải
#   julia --project applications/prepare_groceries_data.jl --force   # luôn tải lại
#
# Dữ liệu tải về chỉ được ghi vào data/market/ khi qua kiểm tra: đúng số giỏ, số item và checksum.
# Checksum tính trên nội dung đã bỏ ký tự CR cuối dòng, nên không đổi nếu Git trên Windows
# tự chuyển LF thành CRLF.
using Downloads, SHA, AprioriFIM

const OUT = joinpath(@__DIR__, "..", "data", "market", "groceries.csv")
const URL = "https://raw.githubusercontent.com/PacktPublishing/Machine-Learning-with-R-Second-Edition/master/Chapter%2008/groceries.csv"
const N_TX = 9835
const N_ITEMS = 169
const SHA256 = "f8a7074231acf5f3de6bdb7ec63fed03c28745d76bd49aa8ddc0c5d1cfa3da91"

"""Checksum nội dung: SHA-256 của các dòng nối bằng LF (không phụ thuộc kiểu xuống dòng)."""
content_sha256(path::AbstractString) = bytes2hex(sha256(join(eachline(path), "\n") * "\n"))

"""
    validate(path) -> (ok, thông báo)

Đọc bằng chính `read_labeled_transactions` + `encode_transactions` của thư viện (cùng đường đi với
notebook), rồi so số giỏ, số item và checksum với giá trị đã ghi.
"""
function validate(path::AbstractString)
    isfile(path) || return false, "không có file $path"
    raw = read_labeled_transactions(path)
    _, labels = encode_transactions(raw)
    length(raw) == N_TX || return false, "có $(length(raw)) giỏ, cần $N_TX"
    length(labels) == N_ITEMS || return false, "có $(length(labels)) item, cần $N_ITEMS"
    content_sha256(path) == SHA256 || return false,
        "đủ $N_TX giỏ và $N_ITEMS item nhưng checksum khác bản gốc (có thể là bản khác, ví dụ đổi tên một nhóm hàng)"
    return true, "$N_TX giỏ, $N_ITEMS item, checksum khớp"
end

function main(args)
    force = "--force" in args
    if !force
        ok, msg = validate(OUT)
        if ok
            println("Đã có và hợp lệ: ", msg, ". Không cần tải lại (dùng --force để tải lại).")
            return
        end
        println("File hiện có chưa dùng được (", msg, "), tải lại.")
    end
    tmp = tempname()
    try
        Downloads.download(URL, tmp)
    catch err
        error("Không tải được $URL ($(sprint(showerror, err))). Tải tay file này rồi lưu thành $(abspath(OUT)).")
    end
    ok, msg = validate(tmp)
    ok || error("Dữ liệu tải về không đạt kiểm tra: $msg")
    mkpath(dirname(OUT))
    cp(tmp, OUT; force = true)
    println("Đã lưu ", abspath(OUT), ": ", msg)
end

main(ARGS)
