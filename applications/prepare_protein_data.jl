# Ứng dụng 2: tải và lấy mẫu dữ liệu protein từ UniProt (chạy một lần, kết quả đã lưu trong data/bio/).
#   julia --project applications/prepare_protein_data.jl
#
# Tạo:
#   data/bio/kinase.fasta      protein kinase người (Pfam PF00069, Swiss-Prot đã kiểm duyệt)
#   data/bio/background.fasta  1000 protein người KHÔNG phải kinase, lấy mẫu ngẫu nhiên (seed 14)
#   data/bio/README.md         nguồn, câu truy vấn, phiên bản UniProt
#
# Nền loại mọi protein có từ khóa "Kinase" (KW-0418) hoặc có miền kinase (PF00069, PF07714),
# vì tyrosine kinase (PF07714) cũng mang motif HRD/DFG và sẽ làm sai lift nếu lẫn vào nền.
using Dates, Downloads, Random

include(joinpath(@__DIR__, "bioinformatics.jl"))

const OUT = joinpath(@__DIR__, "..", "data", "bio")
const N_BACKGROUND = 1000
const SEED = 14
const API = "https://rest.uniprot.org/uniprotkb/stream"
const HUMAN = "(reviewed:true) AND (organism_id:9606)"
const QUERIES = (
    kinase   = "(xref:pfam-PF00069) AND $HUMAN",
    human    = HUMAN,
    kinase_k = "(keyword:KW-0418) AND $HUMAN",
    kinase_d = "((xref:pfam-PF00069) OR (xref:pfam-PF07714)) AND $HUMAN",
)

url(query, format) = string(API, "?format=", format, "&query=", replace(query, " " => "+", "(" => "%28",
                                                                       ")" => "%29", ":" => "%3A"))

"""Tải `query` về file tạm, trả về (đường dẫn, phiên bản UniProt trong header)."""
function fetch(query, format)
    path = tempname()
    resp = open(path, "w") do io
        Downloads.request(url(query, format); output = io)
    end
    resp.status == 200 || error("UniProt trả về HTTP $(resp.status) cho truy vấn: $query")
    release = "?"
    for (k, v) in resp.headers
        lowercase(k) == "x-uniprot-release" && (release = v)
    end
    return path, release
end

function main()
    mkpath(OUT)
    kin_path, release = fetch(QUERIES.kinase, "fasta")
    human_path, _ = fetch(QUERIES.human, "fasta")
    excluded = Set{String}()
    for q in (QUERIES.kinase_k, QUERIES.kinase_d)
        p, _ = fetch(q, "list")
        union!(excluded, filter(!isempty, strip.(readlines(p))))
    end

    kinases = read_fasta(kin_path)
    union!(excluded, (r.accession for r in kinases))
    pool = [r for r in read_fasta(human_path) if !(r.accession in excluded)]
    background = sort!(shuffle(MersenneTwister(SEED), pool)[1:N_BACKGROUND]; by = r -> r.accession)

    write_fasta(joinpath(OUT, "kinase.fasta"), kinases)
    write_fasta(joinpath(OUT, "background.fasta"), background)
    open(joinpath(OUT, "README.md"), "w") do io
        println(io, """
        # Dữ liệu protein cho Ứng dụng 2

        Sinh bởi `julia --project applications/prepare_protein_data.jl` ngày $(Dates.today()),
        UniProt release **$release** (REST API `$API`).

        | File | Số chuỗi | Truy vấn UniProt |
        |---|---|---|
        | `kinase.fasta` | $(length(kinases)) | `$(QUERIES.kinase)` |
        | `background.fasta` | $(length(background)) | mẫu ngẫu nhiên (seed $SEED) từ `$(QUERIES.human)`, đã loại $(length(excluded)) protein là kinase |

        Protein bị loại khỏi nền: có từ khóa Kinase (`$(QUERIES.kinase_k)`) hoặc có miền kinase
        (`$(QUERIES.kinase_d)`), cùng mọi protein trong `kinase.fasta`. Nền được lấy từ
        $(length(pool)) protein người còn lại.

        Dữ liệu UniProt dùng giấy phép CC BY 4.0 (https://www.uniprot.org/help/license).
        """)
    end
    println("UniProt $release: $(length(kinases)) kinase, $(length(background)) nền (từ $(length(pool)) protein, loại $(length(excluded)))")
end

main()
