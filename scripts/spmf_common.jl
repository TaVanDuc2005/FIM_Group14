# Hàm dùng chung để gọi SPMF (Java) làm kết quả tham chiếu.
# SPMF KHÔNG phải là một phần của cài đặt: chỉ dùng để kiểm tra tính đúng.
# Tải spmf.jar tại https://www.philippe-fournier-viger.com/spmf/ và đặt vào tools/spmf/spmf.jar
# (hoặc đặt biến môi trường SPMF_JAR).

const SPMF_JAR = get(ENV, "SPMF_JAR", joinpath(@__DIR__, "..", "tools", "spmf", "spmf.jar"))
# spmf.jar bản mới cần Java 25+. Nếu `java` trong PATH là bản cũ, chỉ đường dẫn tới java mới:
#   $env:SPMF_JAVA = "C:\Program Files\Eclipse Adoptium\jdk-25...\bin\java.exe"   (PowerShell)
const SPMF_JAVA = get(ENV, "SPMF_JAVA", "java")

"""
    run_spmf(input, output, params...; algorithm = "Apriori") -> Float64

Chạy `java -jar spmf.jar run <algorithm> <input> <output> <params...>`, trả về thời gian (giây).
`params` theo cú pháp SPMF, ví dụ `"40%"` (Apriori) hoặc `"40%", "60%", "0"`
(minsup, minconf, minlift của FPGrowth_association_rules_with_lift).
"""
function run_spmf(input::AbstractString, output::AbstractString, params::AbstractString...;
                  algorithm::AbstractString = "Apriori")
    isfile(SPMF_JAR) || error("Không tìm thấy $SPMF_JAR. Tải spmf.jar và đặt vào tools/spmf/ hoặc đặt SPMF_JAR.")
    mkpath(dirname(abspath(output)))
    cmd = `$SPMF_JAVA -jar $SPMF_JAR run $algorithm $input $output $params`
    stderr_buf = IOBuffer()
    t = @elapsed ok = success(pipeline(cmd; stdout = devnull, stderr = stderr_buf))
    if !ok
        msg = String(take!(stderr_buf))
        hint = occursin("UnsupportedClassVersionError", msg) ?
            "\nspmf.jar cần Java mới hơn `$SPMF_JAVA`. Cài JDK 25+ rồi đặt biến môi trường SPMF_JAVA trỏ tới java.exe của JDK đó." : ""
        error("SPMF chạy lỗi: $cmd\n$(first(msg, 600))$hint")
    end
    isfile(output) || touch(output)  # không có itemset nào -> file rỗng
    return t
end

"""In báo cáo so sánh do `compare_itemsets` trả về."""
function print_comparison(io::IO, label::AbstractString, cmp)
    status = cmp.exact ? "KHỚP 100%" : "LỆCH"
    println(io, rpad(label, 12), " ours = ", lpad(cmp.n_ours, 8), "  spmf = ", lpad(cmp.n_reference, 8),
            "  matched = ", lpad(cmp.matched, 8),
            "  rate = ", rpad(string(round(100 * cmp.match_rate; digits = 2)) * "%", 8), "  ", status)
    if !cmp.exact
        for (what, list) in (("thiếu", cmp.missing), ("thừa", cmp.extra), ("sai support", cmp.wrong_support))
            isempty(list) || println(io, "    $what ($(length(list))): ", first(list, 5), length(list) > 5 ? " ..." : "")
        end
    end
end
