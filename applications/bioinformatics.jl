# Ứng dụng 2: chuỗi protein -> giao dịch k-mer -> Apriori của nhóm -> motif phổ biến.
# Các hàm xử lý dữ liệu sinh học; notebook notebooks/app2_protein_motifs.ipynb `include` file này.
# Chỉ dùng thư viện chuẩn của Julia: không cần gói sinh học ngoài, và không dùng thư viện FIM nào.

"""
    read_fasta(path) -> Vector{NamedTuple}

Đọc file FASTA của UniProt. Mỗi bản ghi có `accession`, `entry` (ví dụ `KPCA_HUMAN`),
`description` (phần còn lại của dòng tiêu đề) và `sequence` (chuỗi amino acid, đã nối các dòng).
"""
function read_fasta(path::AbstractString)
    records = NamedTuple{(:accession, :entry, :description, :sequence),NTuple{4,String}}[]
    header, buf = nothing, IOBuffer()
    flush!() = header === nothing || push!(records, parse_header(header, String(take!(buf))))
    open(path) do io
        for line in eachline(io)
            s = strip(line)
            isempty(s) && continue
            if startswith(s, '>')
                flush!()
                header = s[2:end]
            else
                print(buf, s)
            end
        end
    end
    flush!()
    return records
end

"""Tách tiêu đề UniProt `sp|P17252|KPCA_HUMAN Protein kinase C alpha type OS=...`."""
function parse_header(header::AbstractString, sequence::String)
    id, description = occursin(' ', header) ? split(header, ' '; limit = 2) : (header, "")
    parts = split(id, '|')
    accession = length(parts) >= 2 ? parts[2] : id
    entry = length(parts) >= 3 ? parts[3] : id
    return (accession = String(accession), entry = String(entry),
            description = String(description), sequence = sequence)
end

"""Ghi bản ghi ra FASTA, mỗi dòng 60 ký tự như UniProt."""
function write_fasta(path::AbstractString, records)
    mkpath(dirname(abspath(path)))
    open(path, "w") do io
        for r in records
            println(io, ">sp|", r.accession, "|", r.entry, isempty(r.description) ? "" : " " * r.description)
            for i in 1:60:length(r.sequence)
                println(io, r.sequence[i:min(i + 59, end)])
            end
        end
    end
    return path
end

"""
    kmer_set(sequence, k) -> Vector{String}

Các đoạn con dài `k` khác nhau trong chuỗi, đã sắp xếp. Một k-mer xuất hiện nhiều lần
trong cùng chuỗi chỉ tính một lần, vì support của Apriori đếm số giao dịch chứa item.
"""
function kmer_set(sequence::AbstractString, k::Integer)
    k >= 1 || throw(ArgumentError("k phải ≥ 1"))
    n = length(sequence)
    return sort!(unique!([sequence[i:i+k-1] for i in 1:n-k+1]))
end

"""
    protein_transactions(records; k = 3, label = nothing) -> Vector{Vector{String}}

Mỗi protein thành một giao dịch gồm các k-mer của nó. Nếu có `label`, thêm item nhãn đó vào
mọi giao dịch (ví dụ `"KINASE"`), để sinh được luật dạng `{motif...} => {KINASE}`.
"""
function protein_transactions(records; k::Integer = 3, label = nothing)
    return [label === nothing ? kmer_set(r.sequence, k) : push!(kmer_set(r.sequence, k), label)
            for r in records]
end

"""
    chain_kmers(kmers) -> Union{String,Nothing}

Nếu các k-mer nối được thành một đoạn liền (mỗi k-mer chồng k-1 ký tự lên k-mer sau),
trả về đoạn đó, ví dụ `["DLK", "HRD", "RDL"]` -> `"HRDLK"`. Ngược lại trả về `nothing`.
Dùng để nhận ra itemset phổ biến là các mảnh của cùng một motif dài hơn.
"""
function chain_kmers(kmers::AbstractVector{<:AbstractString})
    isempty(kmers) && return nothing
    k = length(first(kmers))
    all(x -> length(x) == k, kmers) || return nothing
    length(kmers) == 1 && return String(first(kmers))
    overlaps(a, b) = a[2:end] == b[1:end-1]
    # Điểm bắt đầu: k-mer không nối tiếp sau k-mer nào khác.
    starts = [a for a in kmers if !any(b -> b != a && overlaps(b, a), kmers)]
    length(starts) == 1 || return nothing
    chain, used, current = String(starts[1]), Set([starts[1]]), starts[1]
    while length(used) < length(kmers)
        next = [b for b in kmers if !(b in used) && overlaps(current, b)]
        length(next) == 1 || return nothing
        current = next[1]
        push!(used, current)
        chain *= current[end]
    end
    return chain
end

"""Tỉ lệ bản ghi có chứa đoạn `motif` (tìm chuỗi con liền nhau)."""
motif_fraction(records, motif::AbstractString) =
    isempty(records) ? 0.0 : count(r -> occursin(motif, r.sequence), records) / length(records)

"""In bảng văn bản căn cột (dùng trong notebook, không cần gói ngoài)."""
function print_table(header, rows; io::IO = stdout)
    cells = [string.(collect(header)), (string.(collect(r)) for r in rows)...]
    widths = [maximum(length(c[j]) for c in cells) for j in eachindex(header)]
    line(c) = println(io, join((rpad(x, w) for (x, w) in zip(c, widths)), "  "))
    line(cells[1])
    println(io, join(("-"^w for w in widths), "  "))
    foreach(line, cells[2:end])
end
