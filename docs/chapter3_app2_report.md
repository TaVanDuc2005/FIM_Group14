# Ứng dụng 2: Tìm motif bảo tồn trong họ protein kinase

## A. Bài toán

Protein kinase là một họ protein lớn ở người, khoảng 500 gen. Chúng gắn nhóm phosphate lên protein khác để bật hoặc tắt các đường truyền tín hiệu trong tế bào, và là đích của nhiều thuốc điều trị ung thư. Các kinase rất khác nhau về độ dài và chức năng, nhưng đều có chung một miền xúc tác. Trong miền này có vài đoạn amino acid gần như không đổi qua tiến hóa, gọi là motif bảo tồn. Các nhà sinh học thường tìm ra chúng bằng cách gióng hàng (alignment) nhiều chuỗi rồi xem cột nào ít thay đổi.

Nhóm đặt câu hỏi: **chỉ dùng khai thác tập phổ biến, không gióng hàng chuỗi, không đưa vào kiến thức sinh học nào, có tìm lại được các motif đó không?** Bài toán này hợp với FIM vì "bảo tồn trong họ" nghĩa là "xuất hiện trong phần lớn các thành viên của họ", tức là support cao. Kết quả lại kiểm chứng được, vì các motif của kinase đã được mô tả kỹ trong tài liệu [1]. Nếu thuật toán tìm ra đúng chúng, đó là bằng chứng cách làm có ý nghĩa thật.

Mọi tập phổ biến và luật trong phần này đều do cài đặt Apriori của nhóm (`AprioriFIM`, bản bitarray) tính, không dùng thư viện FIM nào khác. Toàn bộ phân tích nằm trong `notebooks/app2_protein_motifs.ipynb`, chạy được trên Colab (runtime Julia) trong khoảng 1–2 phút.

## B. Dữ liệu

Dữ liệu lấy từ UniProt Swiss-Prot [2], phần đã được chuyên gia kiểm duyệt, bản phát hành 2026_04, chỉ gồm protein người (Bảng 3.2.1).

- **Tập kinase**: mọi protein người có miền Pfam PF00069, miền kinase serine/threonine kinh điển.
- **Tập nền**: 1 000 protein người chọn ngẫu nhiên (seed 14) trong số các protein không phải kinase. Trước khi chọn, nhóm loại mọi protein có từ khóa Kinase (KW-0418) hoặc có miền kinase, kể cả miền tyrosine kinase PF07714 (659 protein). Lý do là các protein này cũng mang những motif đang tìm. Nếu để lẫn vào nền, chúng sẽ làm phép so sánh bị sai.

Tập nền là nhóm đối chứng. Một đoạn amino acid hay gặp ở kinase chỉ đáng chú ý khi nó *không* hay gặp ở một protein bất kỳ.

<p align="center"><b>Bảng 3.2.1.</b> Dữ liệu của Ứng dụng 2</p>

| Tập | Số protein | Độ dài trung vị (amino acid) | Truy vấn UniProt |
|---|---|---|---|
| kinase | 344 | 588 | `(xref:pfam-PF00069) AND (reviewed:true) AND (organism_id:9606)` |
| nền | 1 000 | 394 | mẫu ngẫu nhiên từ 19 770 protein người còn lại sau khi loại kinase |

Script `applications/prepare_protein_data.jl` tải dữ liệu qua REST API của UniProt và ghi câu truy vấn, ngày tải vào `data/bio/README.md`. UniProt cập nhật vài tháng một lần, nên hai file FASTA được lưu sẵn trong repo để kết quả không đổi giữa các lần chạy.

## C. Biến chuỗi protein thành giao dịch

Một protein là một chuỗi chữ cái trên bảng 20 amino acid, không có sẵn "item" như giỏ hàng. Bước thiết kế quan trọng nhất của ứng dụng là quyết định giao dịch và item là gì.

- **Mỗi protein là một giao dịch.** Khi đó support của một mẫu là số protein chứa mẫu đó, đúng đại lượng cần đo khi nói một motif bảo tồn trong họ.
- **Item là các k-mer**, tức các đoạn liền dài k amino acid có trong chuỗi. Ví dụ chuỗi `MKTAY` với k = 3 cho ba item `MKT`, `KTA`, `TAY`.
- **Giao dịch là tập hợp.** Một k-mer lặp lại nhiều lần trong chuỗi vẫn chỉ tính một lần, và vị trí của nó bị bỏ qua. Đây là cái giá của cách biểu diễn này; mục E quay lại chuỗi gốc để kiểm tra vị trí.

Item dạng chuỗi được mã hóa thành số nguyên bằng `encode_transactions` (Chương I, mục F) trước khi đưa vào Apriori, và được giải mã lại khi in kết quả.

**Chọn k.** Nếu k quá nhỏ, đoạn nào cũng gặp ở hầu hết protein. Nếu k quá lớn, gần như không đoạn nào lặp lại giữa các protein. Nhóm thử k = 2, 3, 4 trên tập kinase ở minsup 50%, chỉ khai thác đến 2-itemset (`maxlen = 2`) để so sánh nhanh (Bảng 3.2.2).

<p align="center"><b>Bảng 3.2.2.</b> Ảnh hưởng của k (tập kinase, minsup 50%)</p>

| k | Số k-mer khác nhau | k-mer TB mỗi protein | 1-itemset phổ biến | 2-itemset phổ biến |
|---|---|---|---|---|
| 2 | 400 | 269 | 304 | 35 559 |
| 3 | 7 895 | 665 | 9 | 5 |
| 4 | 91 935 | 798 | 0 | 0 |

Với k = 2 chỉ có 400 cặp amino acid, và một protein dài vài trăm amino acid chứa gần hết các cặp đó. Hàng trăm item và hàng chục nghìn cặp "phổ biến" lúc này chỉ phản ánh thành phần amino acid chung, không phải motif. Dữ liệu dày đến mức khai thác đầy đủ không chạy xong; đây cũng là lý do nhóm bổ sung tham số `maxlen` vào thư viện. Với k = 4, một đột biến ở bất kỳ vị trí nào của motif đều làm nó thành một 4-mer khác, nên không 4-mer nào đạt 50%. k = 3 nằm giữa: đủ ít item phổ biến để đọc hết, và đủ dài để có tính đặc hiệu. Nhóm chọn **k = 3**.

## D. Khai thác tập phổ biến trong họ kinase

Dữ liệu sinh học dày hơn nhiều so với dữ liệu giỏ hàng: trung bình mỗi protein kinase có 665 item. Vì vậy số tập phổ biến tăng nhanh khi giảm minsup (Bảng 3.2.3). Thời gian khai thác vẫn chỉ vài chục mili giây, vì số giao dịch nhỏ và tidset của mỗi itemset chỉ gồm 6 từ 64 bit.

<p align="center"><b>Bảng 3.2.3.</b> Số tập phổ biến theo minsup (tập kinase, k = 3)</p>

| minsup | Số tập phổ biến | Tập dài nhất | Thời gian (ms) |
|---|---|---|---|
| 50% | 14 | 2 | 8,3 |
| 40% | 47 | 3 | 7,6 |
| 30% | 240 | 4 | 17,0 |
| 25% | 723 | 5 | 57,0 |

Phần phân tích dùng **minsup = 40%**: một mẫu phải có mặt ở ít nhất 138 trong 344 kinase. Mức này cho 47 tập, đủ ít để đọc hết từng tập. Với mỗi 3-mer phổ biến, nhóm đếm thêm tỉ lệ của nó trong tập nền. Bảng 3.2.4 trích các 3-mer tiêu biểu; cột cuối là số lần 3-mer đó hay gặp ở kinase hơn ở nền.

<p align="center"><b>Bảng 3.2.4.</b> Một số 3-mer phổ biến (minsup 40%) và tỉ lệ ở tập nền</p>

| 3-mer | Trong kinase | Trong nền | Kinase / nền |
|---|---|---|---|
| DFG | 80,5% | 5,5% | 14,6 |
| APE | 71,8% | 10,8% | 6,6 |
| HRD | 69,2% | 3,3% | 21,0 |
| DLK | 63,4% | 12,4% | 5,1 |
| RDL | 58,1% | 13,4% | 4,3 |
| GTP | 54,9% | 10,4% | 5,3 |
| PEV | 51,7% | 11,7% | 4,4 |
| LKP | 50,6% | 13,2% | 3,8 |
| LLL | 46,2% | 38,7% | 1,2 |
| SSS | 45,6% | 31,2% | 1,5 |

Có thể chia các 3-mer thành hai nhóm rõ rệt. Nhóm thứ nhất gồm `DFG`, `HRD`, `APE`, `DLK`, `RDL`, `GTP`, `PEV`, `LKP`: chúng có ở một nửa đến bốn phần năm số kinase, nhưng ở nền thì hiếm, chênh từ 4 đến 21 lần. Nhóm thứ hai gồm `LLL`, `SSS` và các đoạn giàu L, S khác: support trong kinase cũng cao, nhưng ở nền gần như bằng. Đây là các vùng lặp đơn giản (low-complexity) gặp ở mọi loại protein, không nói gì riêng về kinase. Nếu chỉ nhìn support, hai nhóm này lẫn vào nhau. Mục F dùng lift để tách chúng một cách có hệ thống.

**Các tập nhiều 3-mer.** Ở minsup 40% có 23 tập gồm từ 2 item trở lên. Tập có support cao nhất là {DFG, HRD} (61,3%), tiếp theo là {APE, DFG} (60,2%) và {DFG, DLK} (53,5%). Một số tập gồm các 3-mer chồng lên nhau, ví dụ `DLK` và `RDL` chồng hai chữ `DL`. Hàm `chain_kmers` nối các tập như vậy thành một đoạn liền, và nhóm đếm lại đoạn liền đó trên chuỗi gốc (Bảng 3.2.5).

<p align="center"><b>Bảng 3.2.5.</b> Các itemset nối được thành đoạn liền</p>

| Itemset | Support (kinase) | Đoạn liền | Đoạn liền: kinase / nền |
|---|---|---|---|
| {DLK, RDL} | 50,0% | RDLK | 44,8% / 0,4% |
| {DLK, LKP} | 43,9% | DLKP | 39,0% / 0,6% |
| {HRD, RDL} | 43,3% | HRDL | 36,3% / 0,3% |
| {APE, PEV} | 43,3% | APEV | 36,3% / 0,6% |

Các đoạn 4 amino acid này có ở hơn một phần ba số kinase nhưng gần như không có ở nền (dưới 1%). Như vậy, từ các item chỉ dài 3, thuật toán đã ghép lại được những mảnh dài hơn của cùng một motif: `HRDL`, `RDLK`, `DLKP` đều là các mảnh của đoạn `HRDLKP`. Ở mục C, khai thác trực tiếp 4-mer không cho kết quả nào ở minsup 50%. Itemset 3-mer vì thế chịu được biến thể tốt hơn: một kinase đổi một amino acid ở `K` vẫn giữ được `HRD` và `RDL`.

## E. Kiểm tra vị trí của HRD và DFG

Vì giao dịch đã bỏ qua vị trí, itemset {DFG, HRD} chỉ cho biết hai đoạn cùng có mặt trong một protein, chưa cho biết chúng có nằm gần nhau không. Để kiểm tra, nhóm quay lại chuỗi gốc: với mỗi kinase chứa `HRD`, tìm `DFG` gần nhất phía sau và đo khoảng cách từ chữ H tới chữ D.

Có 206 kinase chứa `HRD` và có `DFG` phía sau. Khoảng cách trung vị là **20 amino acid**, khoảng tứ phân vị 20–21, và 87,9% số kinase có khoảng cách trong khoảng 18–23. Nói cách khác, hai đoạn không chỉ cùng có mặt mà còn nằm ở vị trí gần như cố định so với nhau. Con số này khớp với kinase PKA, protein mẫu dùng để nghiên cứu cấu trúc kinase: vòng xúc tác của PKA là biến thể `YRD` ở vị trí 164–166, còn Asp của `DFG` ở vị trí 184 [3], cũng cách nhau 20. Theo Hanks và Hunter [1], hai motif thuộc hai tiểu vùng liền nhau của miền xúc tác (VIb và VII), cùng bao quanh vị trí gắn ATP. Vì vậy khoảng cách giữa chúng bị ràng buộc chặt qua tiến hóa. Kết quả này cho thấy itemset {DFG, HRD} phản ánh một đơn vị cấu trúc thật, không phải hai đoạn tình cờ cùng xuất hiện.

## F. Luật kết hợp: motif nào đặc trưng cho kinase?

Mục D so sánh với tập nền bằng cách đếm thủ công từng 3-mer. Luật kết hợp làm việc này một cách hệ thống. Nhóm gộp kinase và nền thành một CSDL 1 344 giao dịch, và thêm vào mỗi giao dịch một item nhãn, `KINASE` hoặc `OTHER`. Sau đó khai thác ở minsup 10% (134 protein), giới hạn tập tối đa 4 item (`maxlen = 4`) để chạy nhanh trên Colab, rồi sinh luật bằng `association_rules` (Chương I, mục E), cài theo thuật toán ap-genrules của Agrawal và Srikant [4]. Các luật cần quan tâm có dạng `{3-mer...} ⇒ {KINASE}`, trả lời câu hỏi: *thấy các đoạn này thì protein có phải kinase không?*

- **Confidence** là tỉ lệ kinase trong số các protein chứa vế trái.
- **Lift** là confidence chia cho tỉ lệ kinase trong CSDL (344/1 344 ≈ 25,6%). Lift tối đa là 1 344/344 ≈ 3,91, đạt khi mọi protein chứa vế trái đều là kinase. Lift gần 1 nghĩa là vế trái không cho biết gì về nhãn.

Bước khai thác cho 4 517 tập phổ biến trong khoảng 1,3–1,8 giây (xem chi phí bộ nhớ ở mục H). Có 60 luật có confidence từ 80% trở lên, trong đó 29 luật có vế phải là `KINASE`. Bảng 3.2.6 so sánh luật của từng motif riêng lẻ, của tổ hợp motif, và của hai 3-mer low-complexity.

<p align="center"><b>Bảng 3.2.6.</b> Luật ⇒ KINASE trên dữ liệu trộn (minsup 10%)</p>

| Vế trái (⇒ KINASE) | Support | Confidence | Lift |
|---|---|---|---|
| {DFG} | 277 | 83,4% | 3,26 |
| {HRD} | 238 | 87,8% | 3,43 |
| {APE} | 247 | 69,6% | 2,72 |
| {DFG, HRD} | 211 | 99,1% | 3,87 |
| {APE, DFG, HRD} | 152 | 99,3% | 3,88 |
| {LLL} | 159 | 29,1% | 1,14 |
| {SSS} | 157 | 33,5% | 1,31 |

Có hai nhận xét chính.

**Tổ hợp motif mạnh hơn từng motif riêng lẻ.** Nếu chỉ biết protein chứa `DFG`, khả năng nó là kinase khoảng 83%. Nếu biết nó chứa cả `DFG` và `HRD`, khả năng này lên 99,1%, lift 3,87, rất gần mức tối đa 3,91: trong 213 protein chứa cả hai đoạn, chỉ có 2 protein nền. Một 3-mer riêng lẻ vẫn có thể xuất hiện tình cờ trong một protein bất kỳ, nhưng hai motif của cùng một miền xúc tác cùng có mặt thì gần như chắc chắn là kinase. Đây là thông tin mà itemset và luật kết hợp mang lại, còn đếm từng k-mer riêng thì không có được.

**Support cao không đồng nghĩa với có ý nghĩa.** `LLL` và `SSS` có support trên dữ liệu trộn khá lớn (157–159 protein, ngang tổ hợp {APE, DFG, HRD}), nhưng lift chỉ 1,14 và 1,31. Nếu xếp kết quả theo support, chúng nằm lẫn với các motif thật. Xếp theo lift thì chúng rơi xuống cuối, đúng như phân tích sinh học ở mục D. Mười luật có lift cao nhất đều chỉ gồm các 3-mer của ba vùng HRD, DFG và APE.

Về mặt ứng dụng, các luật này là một bộ nhận diện kinase đơn giản và dễ giải thích. Với một protein mới chưa rõ chức năng, nếu nó chứa {DFG, HRD} thì rất có thể nó là kinase, và luật còn chỉ ra được vị trí của vòng xúc tác. Cách làm không cần gióng hàng chuỗi, nên có thể áp dụng cho họ protein khác chỉ bằng cách đổi dữ liệu đầu vào.

## G. Đối chiếu với tài liệu sinh học

Cần tách rõ hai loại thông tin. Mọi con số ở các mục B–F (tỉ lệ, support, khoảng cách, confidence, lift) là kết quả nhóm đo trên dữ liệu của mình. Tài liệu bên ngoài chỉ dùng để giải thích ý nghĩa của các mẫu tìm được. Hanks và Hunter [1] so sánh hàng trăm kinase và chia miền xúc tác thành 12 tiểu vùng (subdomain); các motif bảo tồn nhất nằm ở những tiểu vùng trong Bảng 3.2.7. Cả ba vùng đều có mặt trong kết quả của nhóm.

<p align="center"><b>Bảng 3.2.7.</b> Các 3-mer tìm được và motif đã biết của kinase</p>

| 3-mer tìm được | Motif đã biết | Vai trò |
|---|---|---|
| `HRD`, `RDL`, `DLK`, `LKP` | **HRDLKPEN**, vòng xúc tác (subdomain VIb) | Asp của HRD nằm sát nhóm OH của amino acid được gắn phosphate, tham gia trực tiếp vào phản ứng |
| `DFG` | **DFG** (subdomain VII) | giúp giữ ATP và ion Mg²⁺ ở trung tâm hoạt động; mở đầu đoạn kích hoạt (activation segment) |
| `APE`, `GTP`, `PEV` | **…GTPxYxAPE…** (subdomain VIII) | APE đánh dấu cuối đoạn kích hoạt |

Kết quả của thuật toán và mô tả trong tài liệu được tạo ra độc lập với nhau, nhưng khớp nhau. Đây là bằng chứng chính cho thấy cách biểu diễn protein thành giao dịch k-mer, cùng với Apriori, tìm ra được tri thức có ý nghĩa sinh học thật.

## H. Hạn chế

- **Không bắt được motif có khoảng trống.** Motif gắn ATP `GxGxxG` ở subdomain I rất bảo tồn, nhưng các vị trí `x` ở giữa có thể là amino acid bất kỳ. Motif này không ứng với một k-mer cố định nào, nên không xuất hiện trong kết quả. Muốn bắt được nó cần item có ký tự đại diện, hoặc khai thác mẫu tuần tự có khoảng trống.
- **Bỏ qua vị trí và số lần lặp.** Hai 3-mer cùng có mặt chưa chắc nằm gần nhau. Mục E phải kiểm tra lại bằng chuỗi gốc, và việc kiểm tra này nằm ngoài Apriori.
- **k cố định làm support bị đánh giá thấp.** Một đột biến giữa motif làm mất cả ba 3-mer phủ qua vị trí đó. Vì vậy `DFG` chỉ đạt 80,5%, dù gần như mọi kinase hoạt động đều có motif này hoặc một biến thể của nó.
- **Phạm vi dữ liệu.** Dữ liệu chỉ gồm protein người, và tập nền là một mẫu 1 000 protein, nên tỉ lệ ở nền có sai số lấy mẫu. Tập kinase lấy theo miền PF00069, nên chủ yếu là serine/threonine kinase; các tyrosine kinase chỉ có miền PF07714 không được đưa vào.
- **Chi phí bộ nhớ nằm ở bước sinh ứng viên mức 2.** Trên dữ liệu trộn (1 344 giao dịch, trung bình 510 item mỗi giao dịch), `@time` báo khoảng 611 MiB bộ nhớ cấp phát cho một lần khai thác, với 16–32% thời gian dành cho thu gom rác (GC) tùy lần chạy. Đo tách từng bước cho thấy gần như toàn bộ con số này đến từ một chỗ: ở minsup 10% có 1 524 3-mer phổ biến, nên mức 2 có $\binom{1524}{2} = 1\,160\,526$ ứng viên, và việc sinh chúng cấp phát khoảng 580 MiB (95%). Các bước còn lại nhỏ hơn nhiều: đếm item và dựng tidset dưới 1,2 MiB, mức 3 (17 981 ứng viên) khoảng 28 MiB, còn phép AND dùng lại một bộ đệm nên gần như không cấp phát. Trong khi đó chỉ 2 862 trên hơn một triệu cặp ứng viên là phổ biến. Đây là điểm nghẽn quen thuộc của Apriori: số ứng viên $|C_2|$ tăng theo bình phương số item phổ biến, và dữ liệu càng dày thì càng nhiều item vượt minsup. Lưu ý 611 MiB là tổng bộ nhớ được cấp phát trong suốt quá trình chạy, không phải đỉnh RAM; đỉnh RSS của cả process đo được khoảng 640 MiB, trong đó riêng Julia runtime đã chiếm 250–300 MB (Chương I, mục I). Có thể giảm chi phí này mà vẫn giữ cách đếm bằng tidset: ở mức 2, duyệt thẳng từng cặp item, AND hai tidset ngay, và chỉ tạo vector cho cặp đạt minsup, thay vì dựng sẵn cả danh sách hơn một triệu ứng viên. Đếm cặp bằng ma trận tam giác không hợp với dữ liệu này: mỗi protein có khoảng 510 item, tức khoảng 130 nghìn cặp mỗi giao dịch, tổng cộng khoảng 175 triệu lần cộng trên 1 344 giao dịch.
- **Dữ liệu trộn phải giới hạn `maxlen = 4`** để chạy nhanh trên Colab. Các luật dài hơn 3 item ở vế trái vì thế không được xét; với minsup 10%, nhóm không kỳ vọng các luật đó thay đổi kết luận, vì luật hai item đã đạt lift gần tối đa.

---
**Tài liệu tham khảo (cho Ứng dụng 2)**

[1] S. K. Hanks and T. Hunter, "The eukaryotic protein kinase superfamily: kinase (catalytic) domain structure and classification," *FASEB J.*, vol. 9, no. 8, pp. 576–596, 1995, doi: 10.1096/fasebj.9.8.7768349.

[2] The UniProt Consortium, "UniProt: the Universal Protein Knowledgebase in 2025," *Nucleic Acids Res.*, vol. 53, no. D1, pp. D609–D617, 2025.

[3] D. R. Knighton *et al.*, "Crystal structure of the catalytic subunit of cyclic adenosine monophosphate-dependent protein kinase," *Science*, vol. 253, no. 5018, pp. 407–414, 1991.

[4] R. Agrawal and R. Srikant, "Fast algorithms for mining association rules," in *Proc. 20th Int. Conf. Very Large Data Bases (VLDB)*, Santiago, Chile, 1994, pp. 487–499.
