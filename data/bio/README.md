# Dữ liệu protein cho Ứng dụng 2

Sinh bởi `julia --project applications/prepare_protein_data.jl` ngày 2026-11-25,
UniProt release **2026_04** (REST API `https://rest.uniprot.org/uniprotkb/stream`).

| File | Số chuỗi | Truy vấn UniProt |
|---|---|---|
| `kinase.fasta` | 344 | `(xref:pfam-PF00069) AND (reviewed:true) AND (organism_id:9606)` |
| `background.fasta` | 1000 | mẫu ngẫu nhiên (seed 14) từ `(reviewed:true) AND (organism_id:9606)`, đã loại 659 protein là kinase |

Protein bị loại khỏi nền: có từ khóa Kinase (`(keyword:KW-0418) AND (reviewed:true) AND (organism_id:9606)`) hoặc có miền kinase
(`((xref:pfam-PF00069) OR (xref:pfam-PF07714)) AND (reviewed:true) AND (organism_id:9606)`), cùng mọi protein trong `kinase.fasta`. Nền được lấy từ
19770 protein người còn lại.

Dữ liệu UniProt dùng giấy phép CC BY 4.0 (https://www.uniprot.org/help/license).

