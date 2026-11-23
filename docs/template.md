# II. THỰC NGHIỆM VÀ ĐÁNH GIÁ

## A. Môi trường và phương pháp thực nghiệm

**Phần cứng và phần mềm.** Toàn bộ thực nghiệm chạy trên một máy Apple M2 Pro, RAM 16 GB, Julia 1.13.4. Kết quả tham chiếu và so sánh hiệu năng dùng SPMF (bản Apriori của Fournier-Viger và cộng sự) chạy trên JVM. Hai bản cài đặt của nhóm được đánh giá: `apriori` (**basic**, quét lại CSDL ở mỗi lượt, kiểm tra ứng viên ⊆ giao dịch) và `apriori_bitarray` (**bitarray**, tidset dạng `BitVector`, `tid(c) = tid(cha₁) AND tid(cha₂)`). Cả hai dùng chung `apriori-gen` (join + prune) theo Agrawal và Srikant [1]. Bản basic *không* dùng hash-tree của bài báo, nên cần xem nó là một baseline đơn giản, không phải đại diện cho Apriori dùng hash-tree.

**Dữ liệu.** Bốn tập benchmark chuẩn và một họ dữ liệu tổng hợp (Bảng I). Lưu ý: bản Mushroom dùng ở đây (lấy từ kho SPMF) có 8 416 giao dịch, khác với con số 8 124 thường gặp, nên số itemset có thể lệch nhẹ so với các bài báo khác. Tập Accidents không được đưa vào thực nghiệm chính thức do hạn chế thời gian; đề bài yêu cầu tối thiểu 4 tập.

<p align="center"><b>Bảng I.</b> Các tập dữ liệu thực nghiệm</p>

@@T_DATA@@

**Quy trình đo.** (i) Mỗi lần chạy bản của nhóm là một process Julia riêng, có chạy khởi động (warm-up) trước để loại thời gian biên dịch JIT. (ii) `mine_s` là trung vị thời gian khai thác (tối đa 3 lần lặp khi lần đầu < 5 s, chạy một lần khi lâu hơn). `e2e_s` gồm đọc file, khai thác và ghi kết quả; đây là đại lượng so sánh với SPMF, vì "Total time" mà SPMF báo gồm cả I/O. (iii) Peak RAM của bản nhóm là `peak_rss_mb` (đỉnh RSS cả process), kèm `rss_delta_mb` (phần tăng so với ngay trước khi khai thác) và `alloc_mb` (tổng bộ nhớ cấp phát). Peak RAM của SPMF lấy từ `/usr/bin/time -l`. (iv) Mỗi điểm chạy bị giới hạn thời gian: 900 s cho basic, 1800 s cho bitarray và SPMF; điểm quá hạn ghi `timeout` và các điểm khó hơn của cùng chuỗi được bỏ qua. (v) Seed cố định bằng 14.

## B. Kiểm tra tính đúng đắn (Correctness)

Ở **mọi** điểm chạy, toàn bộ tập kết quả (itemset và support) của bản nhóm được so với đầu ra của SPMF, không chỉ so số lượng. Bảng II tổng hợp theo tập dữ liệu; "synthetic" là các điểm của thực nghiệm độ dài giao dịch (mục G).

<p align="center"><b>Bảng II.</b> Tỉ lệ khớp với SPMF (tổng trên mọi điểm minsup)</p>

@@T_CORR@@

Trên @@CORR_POINTS_BIT@@ điểm chạy của bitarray (tổng @@CORR_ITEMS_BIT@@ itemset) và @@CORR_POINTS_BAS@@ điểm của basic (tổng @@CORR_ITEMS_BAS@@ itemset), tỉ lệ khớp đều đạt 100%, và tỉ lệ khớp nhỏ nhất trên từng điểm cũng là 100%: không có itemset thiếu, thừa hay sai support. Basic có ít điểm hơn trên Retail do bị `timeout` hoặc bỏ qua ở minsup thấp (mục C). Kết quả này củng cố các test đơn vị của Chương 1 (71/71 test pass, 24 case đối chiếu SPMF) trên dữ liệu lớn hơn nhiều.

## C. Thời gian chạy theo minsup

Hình 1–4 vẽ thời gian chạy của ba thuật toán theo minsup (trục log-log; đường liền là `e2e_s`, đường chấm là thời gian chỉ khai thác của bản nhóm; dấu × là điểm quá hạn).

![Hình 1. Thời gian chạy theo minsup trên Chess](figures/runtime_chess.png)

![Hình 2. Thời gian chạy theo minsup trên Mushroom](figures/runtime_mushroom.png)

![Hình 3. Thời gian chạy theo minsup trên Retail](figures/runtime_retail.png)

![Hình 4. Thời gian chạy theo minsup trên T10I4D100K](figures/runtime_T10I4D100K.png)

<p align="center"><b>Bảng III.</b> Thời gian chạy (giây, <code>e2e_s</code>) tại minsup cao nhất, trung bình và thấp nhất của mỗi tập</p>

@@T_TIME@@

**Nhận xét.**

1. *Bitarray nhanh hơn basic từ vài lần đến hơn 1000 lần.* Mức tăng tốc tăng khi minsup giảm: trên T10I4D100K từ @@SP_T10_HI@@× (minsup 2%) lên @@SP_T10_LO@@× (0,15%); trên Retail từ @@SP_RET_HI@@× (2%) lên @@SP_RET_LO@@× (0,25%). Nguyên nhân là cấu trúc chi phí đếm support. Ở mỗi lượt k, basic phải tạo tập hợp cho từng giao dịch và kiểm tra từng ứng viên có là tập con hay không, tức khoảng |C_k|·|D|·k phép so sánh, và lặp lại ở mọi k. Bitarray chỉ thực hiện |C_k|·⌈|D|/64⌉ phép AND trên từ 64 bit, không quét lại CSDL. Tỉ lệ |D|/⌈|D|/64⌉ càng lớn (CSDL càng nhiều giao dịch) thì lợi thế càng lớn, nên T10I4D100K (100 000 giao dịch) đạt mức tăng tốc cao nhất, còn Chess (3 196 giao dịch) và Mushroom (8 416) thấp hơn (tối đa @@SP_CHESS_MAX@@× và @@SP_MUSH_MAX@@×). Đây cũng là điểm yếu cố hữu mà bài báo gốc chỉ ra: Apriori phải quét lại toàn bộ CSDL ở mọi vòng lặp.
2. *Trên dữ liệu thưa, basic không dùng được ở minsup thấp.* Basic mất @@BAS_RET_025@@ s trên Retail ở 0,25%, bị `timeout` (900 s) ở 0,15% và bị bỏ qua ở 0,1%; trên T10I4D100K nó mất @@BAS_T10_015@@ s ở 0,15% trong khi bitarray cần @@BIT_T10_015@@ s.
3. *Bitarray so với SPMF.* Với cùng giao thức đo, bitarray nhanh hơn SPMF ở @@N_FASTER@@/@@N_TOTAL@@ điểm (e2e), mức tăng tốc từ @@SPMF_MIN@@× đến @@SPMF_MAX@@×; ngoại lệ duy nhất là Retail ở 2% (SPMF nhanh hơn, @@RET2_SPMF@@ s so với @@RET2_BIT@@ s), nơi chi phí đọc/ghi và khởi tạo chiếm gần hết. Khoảng cách mở rộng khi minsup giảm: trên T10I4D100K từ @@SPMF_T10_HI@@× lên @@SPMF_T10_LO@@×, trên Retail đạt @@SPMF_RET_LO@@× ở 0,15%. Trên dữ liệu dày (Chess), hai bên gần nhau (@@SPMF_CHESS_MIN@@–@@SPMF_CHESS_MAX@@×).
4. *Lưu ý về tính công bằng.* Thời gian của bản nhóm được đo *sau* warm-up JIT; thời gian "Total time" của SPMF do chính SPMF báo trong một lần chạy JVM mới, nên rất có thể gồm cả thời gian JIT của JVM. Ở các điểm dưới 0,3 s (phần lớn Chess, Mushroom) chênh lệch giữa bitarray và SPMF vì vậy có thể bị phóng đại, và chúng tôi **không** kết luận bản bitarray vượt trội SPMF ở các điểm này. Kết luận chắc chắn hơn nằm ở các điểm chạy hàng giây (Mushroom 10%: @@MUSH10_SPMF@@ s so với @@MUSH10_BIT@@ s; Retail 0,1%: @@RET01_SPMF@@ s so với @@RET01_BIT@@ s), nơi sai lệch khởi động là nhỏ so với tổng thời gian.

## D. Số lượng frequent itemset theo minsup

![Hình 5. Số frequent itemset theo minsup (log-log) trên bốn tập benchmark](figures/itemsets_vs_minsup.png)

<p align="center"><b>Bảng IV.</b> Số frequent itemset ở minsup cao nhất và thấp nhất của lưới thực nghiệm</p>

@@T_ITEMS@@

Số lượng itemset tăng *phi tuyến* khi minsup giảm trên cả bốn tập, phù hợp với nhận xét của bài báo gốc (mục 4.4) rằng thời gian và bộ nhớ tăng mạnh khi giảm ngưỡng do |L_k| và |C_k| tăng theo cấp số nhân. Điểm khác biệt nằm ở *mật độ* dữ liệu: ở dữ liệu dày (Chess, Mushroom), vùng minsup khảo sát chỉ trải từ 95% xuống 65% (Chess) hoặc 50% xuống 10% (Mushroom) nhưng số itemset tăng @@GROW_CHESS@@ và @@GROW_MUSH@@ lần; ở dữ liệu thưa, minsup phải giảm xuống mức rất thấp (0,1–0,15%) mới có hàng chục nghìn itemset, và hệ số tăng nhỏ hơn (@@GROW_RET@@ lần trên Retail, @@GROW_T10@@ lần trên T10I4D100K) dù dải minsup trải rộng hơn một bậc độ lớn. Lý do là giao dịch dài và chia sẻ nhiều item chung ở dữ liệu dày nên các tổ hợp item đồng xuất hiện với tần suất rất cao (xem thêm mục H), đúng như phân tích của bài báo về dữ liệu dày so với dữ liệu thưa.

## E. Sử dụng bộ nhớ

![Hình 6. Peak RSS toàn process (trái) và phần tăng RSS khi khai thác (phải) tại minsup trung bình](figures/memory.png)

<p align="center"><b>Bảng V.</b> Bộ nhớ tại minsup trung bình của từng tập (MB). Δ: tăng RSS khi khai thác; alloc: tổng bộ nhớ cấp phát</p>

@@T_MEM@@

<p align="center"><b>Bảng VI.</b> Bộ nhớ tại minsup thấp, nơi số itemset lớn (MB)</p>

@@T_MEM_LOW@@

**Nhận xét.**

1. *Peak RSS toàn process không phân biệt được basic và bitarray ở minsup trung bình.* Cả hai đều ở mức 290–370 MB vì bị chi phối bởi runtime Julia (xấp xỉ 290 MB; ở Chess và Mushroom Δ RSS gần bằng 0 nên toàn bộ peak là runtime cộng dữ liệu). SPMF chỉ cần 75–126 MB, thấp hơn rõ rệt; so sánh này không hoàn toàn cùng loại vì runtime JVM và Julia khác nhau, nhưng về mặt thực tế, bản Julia của nhóm *không* tiết kiệm bộ nhớ hơn SPMF.
2. *Phần bộ nhớ do thuật toán gây ra thì bitarray tốt hơn ở minsup trung bình.* Tổng bộ nhớ cấp phát giảm @@ALLOC_RATIO_MIN@@–@@ALLOC_RATIO_MAX@@ lần (ví dụ Mushroom: @@ALLOC_MUSH_BAS@@ MB còn @@ALLOC_MUSH_BIT@@ MB; Retail: @@ALLOC_RET_BAS@@ MB còn @@ALLOC_RET_BIT@@ MB), và Δ RSS trên Retail giảm từ @@D_RET_BAS@@ MB xuống @@D_RET_BIT@@ MB. Lý do: basic dựng lại tập hợp cho từng giao dịch ở mỗi lượt, tạo nhiều đối tượng trung gian; bitarray chỉ giữ một buffer và các tidset.
3. *Ở minsup thấp, quan hệ đảo ngược.* Ở Mushroom 10%, bitarray có Δ RSS @@D_M10_BIT@@ MB và cấp phát @@A_M10_BIT@@ MB, lớn hơn basic (@@D_M10_BAS@@ MB, @@A_M10_BAS@@ MB); trên Retail 0,1%, bitarray tăng @@D_R01_BIT@@ MB và cấp phát @@A_R01_BIT@@ MB trong khi SPMF chỉ có peak @@P_R01_SPMF@@ MB. Nguyên nhân: bitarray phải giữ tidset của *mọi* itemset phổ biến ở mức k−1 cùng lúc, mỗi tidset tốn |D|/8 byte bất kể độ thưa, nên bộ nhớ tỉ lệ với |L_k|·|D|/8. Đây là sự đánh đổi thời gian–bộ nhớ: bitarray bỏ việc quét lại CSDL bằng cách lưu thêm biểu diễn dọc, đúng như AprioriTid trong bài báo gốc đánh đổi kích thước C̄_k lấy tốc độ.
4. *Giới hạn.* Mỗi giá trị bộ nhớ chỉ từ một lần chạy; RSS có thể dao động nhẹ giữa các lần chạy. Basic không có số liệu ở Retail 0,15% (timeout), nên hạng mục bộ nhớ chỉ so sánh ba thuật toán tại các điểm Bảng V và vài điểm ở Bảng VI.

## F. Khả năng mở rộng (Scalability)

CSDL con có 10%, 25%, 50%, 75% và 100% số giao dịch, lấy mẫu ngẫu nhiên có seed, các tập con lồng nhau, **giữ nguyên minsup tương đối** (Retail 1% và 0,3%) như thiết lập của bài báo (mục 4.5). Số itemset gần như không đổi theo kích thước (@@SCAL_ITEMS_1@@ ở minsup 1%; @@SCAL_ITEMS_03@@ ở 0,3%), nên thời gian phản ánh đúng ảnh hưởng của |D|.

![Hình 7. Thời gian chạy (trái) và thời gian chuẩn hoá so với 100% (phải) khi tăng số giao dịch trên Retail](figures/scalability.png)

<p align="center"><b>Bảng VII.</b> Thời gian <code>e2e_s</code> (giây) tại 10% và 100% giao dịch và hệ số góc log-log (1,0 = tuyến tính)</p>

@@T_SCAL@@

Hệ số góc là độ dốc của đường hồi quy log t theo log p. Bài báo gốc báo cáo thời gian tăng tuyến tính theo số giao dịch. Số liệu của nhóm:

- *Basic* có hệ số góc 1,13, tức tuyến tính (hơi vượt tuyến tính), khớp với bài báo: chi phí quét và đếm tỉ lệ với |D|.
- *Bitarray* có hệ số góc 0,79 ở minsup 1% và chỉ 0,24 ở 0,3%, tức **dưới tuyến tính**. Lý do là một phần đáng kể chi phí không phụ thuộc |D|: số item phổ biến (|L₁| = 515 trên toàn bộ dữ liệu ở 0,3%) xấp xỉ không đổi theo kích thước, nên việc sinh và prune 132 355 ứng viên C₂ tốn thời gian xấp xỉ như nhau ở mọi kích thước (mục H cho thấy sinh ứng viên chiếm 76% tổng thời gian các mức ở minsup này). Chỉ phần AND và đọc/ghi mới tăng theo |D|. Nghĩa là bitarray *chưa* ở chế độ bị giới hạn bởi |D| trong dải khảo sát; trên CSDL lớn hơn nhiều, hệ số góc sẽ tiến về 1.
- *SPMF* có hệ số góc 0,50–0,69. Đây cũng là dưới tuyến tính; chúng tôi giả thuyết là do một phần thời gian cố định (khởi động, JIT của JVM, như đã nêu ở mục C) nhưng chưa có thí nghiệm kiểm chứng giả thuyết này.

Hệ số góc ước lượng từ chỉ 5 điểm, nên chỉ dùng để so sánh tương đối, không dùng làm số đo chính xác.

## G. Ảnh hưởng của độ dài giao dịch trung bình

Dữ liệu tổng hợp theo bộ sinh IBM Quest như mô tả ở mục 4.3 của bài báo [1] (N = 1000 item, L = 2000 mẫu tiềm năng, I = 4, độ dài giao dịch tuân theo Poisson(T); seed 14 + T). Hai thiết lập:

- **fixedDT** (theo mục 4.8 của bài báo): tích D×T = 500 000 không đổi, ngưỡng tuyệt đối 500 giao dịch; T từ 5 đến 40, D giảm từ 100 000 xuống 12 500.
- **fixedD**: D = 20 000 không đổi, minsup tương đối 1%; T từ 5 đến 30.

![Hình 8. Thời gian chạy và số frequent itemset theo độ dài giao dịch trung bình T (hàng trên: fixedDT; hàng dưới: fixedD)](figures/txlen.png)

<p align="center"><b>Bảng VIII.</b> Thời gian <code>e2e_s</code> (giây) và số itemset theo T</p>

@@T_TXLEN@@

**fixedD.** Khi T tăng 6 lần (5→30), số itemset tăng từ @@TX_ITEMS_LO@@ lên @@TX_ITEMS_HI@@ (@@TX_GROW@@ lần) và thời gian tăng ở cả ba thuật toán: SPMF @@TX_SPMF_X@@×, basic @@TX_BAS_X@@×, bitarray @@TX_BIT_X@@×. Giao dịch dài hơn làm xác suất đồng xuất hiện của các tổ hợp item tăng và làm |L_k| tăng; ngoài ra mỗi giao dịch chứa C(T, k) tập con k-item nên chi phí hàm `subset(C_k, t)` tăng tổ hợp, đúng với giải thích của bài báo. Bitarray tăng chậm nhất vì chi phí của nó phụ thuộc số ứng viên chứ không phụ thuộc trực tiếp độ dài giao dịch.

**fixedDT.** Bài báo báo cáo thời gian tăng *dần* theo T. Số liệu của nhóm chỉ khớp một phần: SPMF tăng dần từ @@FDT_SPMF_LO@@ s (T=5) lên @@FDT_SPMF_HI@@ s (T=40), phù hợp với bài báo; bitarray gần như phẳng (@@FDT_BIT_RANGE@@ s với T ≥ 10) và basic *giảm* từ @@FDT_BAS_LO@@ s xuống @@FDT_BAS_HI@@ s. Nguyên nhân có thể suy ra từ thiết lập: giữ D×T không đổi và minsup tuyệt đối không đổi thì D giảm theo T, minsup tương đối tăng từ 0,5% lên 4%, nên số itemset gần như không đổi (từ @@FDT_ITEMS_MIN@@ đến @@FDT_ITEMS_MAX@@) dù giao dịch dài hơn. Chi phí của basic tỉ lệ với |D| nên giảm theo D; chi phí của bitarray tỉ lệ với |C_k|·|D|/64 nên cũng bị D kéo xuống, bù trừ với phần không đổi. Chỉ SPMF, vốn dùng hàm `subset` trên từng giao dịch, mới còn nhạy với T. Đây là kết luận *về thiết lập thí nghiệm cụ thể này* (số itemset hầu như không đổi), không phải phản bác bài báo.

## H. Giải thích hành vi thuật toán theo bài báo gốc

**Nút thắt tại k = 2.** Bài báo chỉ ra C₂ là tổ hợp chập 2 của L₁, |C₂| = C(|L₁|, 2), không có bước prune. Số liệu `levels.csv` xác nhận chính xác công thức này ở cả bốn tập: Chess |L₁| = 19 → |C₂| = 171; Mushroom 27 → 351; Retail 515 → 132 355; T10I4D100K 661 → 218 130. Tuy nhiên hệ quả khác nhau hoàn toàn giữa dữ liệu thưa và dày (Bảng IX, Hình 9).

![Hình 9. |C_k| và |L_k| theo từng mức k](figures/levels.png)

<p align="center"><b>Bảng IX.</b> Hồ sơ theo mức k tại minsup đại diện (thời gian của riêng bitarray)</p>

@@T_LEVELS@@

- *Dữ liệu thưa:* chỉ @@PCT_RET@@% ứng viên C₂ trên Retail và @@PCT_T10@@% trên T10I4D100K thực sự phổ biến (|C₂|/|L₂| ≈ @@R_RET@@ và @@R_T10@@). Mức k = 2 chiếm @@K2_RET@@% và @@K2_T10@@% tổng thời gian các mức, vì phần lớn ứng viên bị loại sau khi đã tốn công sinh và AND. Từ k ≥ 3, |C_k| thu về gần |L_k| (|L_k|/|C_k| = @@LC_RET@@ và @@LC_T10@@ tính gộp) và các mức này gần như không tốn thời gian.
- *Dữ liệu dày:* |L₁| nhỏ nên C₂ nhỏ và k = 2 chỉ chiếm @@K2_CHESS@@% (Chess) và @@K2_MUSH@@% (Mushroom). Số itemset đạt đỉnh ở k = 5–6 (Chess) và k = 4 (Mushroom) rồi giảm dần, và tỉ lệ |L_k|/|C_k| từ k ≥ 3 là @@LC_CHESS@@ và @@LC_MUSH@@: bước prune của `apriori-gen` hiệu quả, ứng viên gần như đều phổ biến. Chi phí nằm ở tổng số itemset phổ biến (@@SUML_CHESS@@ ở Chess 80%), không nằm ở C₂.

**Quét CSDL lặp lại.** Chi phí của basic ở Mục C chính là biểu hiện của điểm yếu mà bài báo nêu: mỗi lượt k tốn một lần quét |D| giao dịch. Số lượt bằng độ dài itemset phổ biến dài nhất cộng một (10 lượt trên Chess 80%), nên dữ liệu dày càng chịu nhiều lượt quét hơn. Thuật toán AprioriTid của bài báo giải quyết bằng cách chỉ quét CSDL gốc ở k = 1; bitarray làm điều tương tự bằng tidset dạng bit.

**Hiệu quả của biểu diễn bit.** Với Mushroom (|D| = 8 416), một tidset là 132 từ 64 bit; với T10I4D100K (|D| = 100 000), 1 563 từ. Phép AND và đếm bit (`count_ones`) chạy trên từ 64 bit, nên mỗi ứng viên tốn |D|/64 thao tác thay vì |D| phép kiểm tra tập con. Điều này giải thích vì sao mức tăng tốc so với basic lớn nhất ở T10I4D100K (đến @@SP_T10_MAX@@×).

**Điểm nghẽn còn lại của bitarray.** Phân tích `levels.csv` cho thấy ngay cả ở bản đã tối ưu, *sinh và prune ứng viên*, chứ không phải đếm support, chiếm phần lớn thời gian: @@GEN_CHESS@@% (Chess), @@GEN_MUSH@@% (Mushroom), @@GEN_RET@@% (Retail), @@GEN_T10@@% (T10I4D100K). Ở T10I4D100K, mức k = 2 một mình tốn @@T10_K2_MS@@ ms, trong đó @@T10_K2_GEN@@ ms là sinh ứng viên. Kết hợp với bộ nhớ cấp phát lên tới @@A_R01_BIT@@ MB ở Retail 0,1% (mục E), đây là cơ sở cho các đề xuất dưới đây.

## I. Hướng tối ưu hoá tiếp theo

Ba đề xuất dưới đây bám trực tiếp vào số liệu ở trên. Chúng tôi chưa cài đặt, nên các mức cải thiện dưới đây chỉ là kỳ vọng định tính cần kiểm chứng.

**1) Không vật chất hoá C₂; sinh ứng viên bằng cấu trúc phẳng và đếm trực tiếp.** *Bằng chứng:* ở Retail và T10I4D100K, k = 2 chiếm 79% và 98% thời gian các mức, hơn 99% ứng viên C₂ bị loại, và sinh ứng viên chiếm 61–94% thời gian. *Đề xuất:* ở k = 2 duyệt trực tiếp các cặp chỉ số (i < j) trên L₁, AND vào một buffer dùng lại và chỉ lưu cặp đạt ngưỡng, thay vì tạo cả |C₂| = C(|L₁|, 2) vector `Vector{Int}`; từ k ≥ 3 dùng mảng phẳng (một `Matrix{Int32}` hoặc vector nối đuôi cùng mảng chỉ số nhóm theo tiền tố) thay cho `Vector{Vector{Int}}`. Thêm *early abandon*: khi AND từng đoạn, dừng nếu số bit đã đếm cộng với số bit tối đa còn lại không thể đạt minsup (tận dụng sắp xếp item theo support tăng dần). *Kỳ vọng:* giảm mạnh cấp phát (1,9 GB ở Retail 0,1%) và thời gian ở mức k = 2.

**2) Biểu diễn tidset lai (hybrid) theo mật độ: tid-list thưa cho itemset thưa, bitset cho itemset dày.** *Bằng chứng:* bitarray tốn |D|/8 byte cho mỗi tidset bất kể độ thưa, và bộ nhớ tăng đột biến ở minsup thấp (Δ RSS 437 MB ở Mushroom 10%, 549 MB ở Retail 0,1%, trong khi basic ở Mushroom 10% chỉ tăng 136 MB). Ở dữ liệu thưa, tidset của itemset 2–3 phần tử rất thưa (support nhỏ hơn 1% của |D|). *Đề xuất:* lưu danh sách tid đã sắp xếp (4 byte mỗi tid) khi support < |D|/32 (điểm hoà vốn với bitset là mật độ 1/32), dùng giao hai danh sách đã sắp xếp; dùng bitset khi dày hơn; với dữ liệu rất dày có thể dùng *diffset* (Zaki và Gouda) để thu nhỏ biểu diễn. Có thể đi theo hướng AprioriHybrid của bài báo: chọn biểu diễn theo kích thước ước lượng ở mỗi mức. *Kỳ vọng:* giảm bộ nhớ ở minsup thấp trên dữ liệu thưa.

**3) Song song hoá đếm support và xử lý theo lớp tương đương tiền tố.** *Bằng chứng:* máy thực nghiệm có nhiều lõi nhưng bản hiện tại chạy tuần tự; các ứng viên cùng tiền tố (k−2) độc lập nhau. *Đề xuất:* chia ứng viên theo lớp tiền tố (cùng nhóm với bước join), chạy mỗi lớp trên một luồng (`Threads.@threads`) với buffer riêng; xử lý và giải phóng tidset theo từng lớp thay vì giữ cả mức L_{k−1}, qua đó cũng chặn trên bộ nhớ của hướng 2. Sinh ứng viên (chiếm phần lớn thời gian, mục H) cũng phân theo lớp nên song song hoá được. *Lưu ý:* cần chú ý tranh chấp cấp phát/GC của Julia; mức tăng tốc thực tế phải đo.

## J. Hạn chế và các mối đe doạ tính hợp lệ

- Chỉ chạy trên một máy; thời gian dài chỉ có một lần đo (basic > 5 s) nên không có khoảng tin cậy. Peak RAM mỗi điểm chỉ một lần.
- Thời gian SPMF và bản nhóm không đo hoàn toàn cùng điều kiện (JIT, mục C nhận xét 4); các kết luận về SPMF ở điểm chạy dưới ~0,3 s không đáng tin cậy.
- Bản basic không dùng hash-tree nên chậm hơn Apriori chuẩn của bài báo; mức tăng tốc "so với basic" không nên diễn giải là so với Apriori tối ưu hash-tree.
- Chưa có Accidents; hệ số góc scalability từ 5 điểm trên một tập (Retail).
- Dữ liệu tổng hợp fixedDT với ngưỡng tuyệt đối 500 làm số itemset gần như không đổi theo T, nên chưa tách riêng được ảnh hưởng thuần tuý của T; fixedD bổ sung cho hạn chế này.

## K. Kết luận chương

(1) Cả hai bản cho kết quả khớp 100% với SPMF trên mọi điểm chạy. (2) Bitarray nhanh hơn basic 1,7–1073× và nhanh hơn SPMF ở hầu hết điểm đo, với khoảng cách lớn nhất ở dữ liệu thưa, minsup thấp. (3) Số itemset tăng phi tuyến khi giảm minsup, mạnh nhất ở dữ liệu dày. (4) Bitarray giảm bộ nhớ cấp phát ở minsup trung bình nhưng tốn nhiều hơn basic và SPMF ở minsup thấp. (5) Basic mở rộng tuyến tính theo |D|; bitarray dưới tuyến tính trong dải khảo sát do phần chi phí không phụ thuộc |D|. (6) Độ dài giao dịch làm tăng mạnh số itemset và thời gian khi D cố định, còn khi D×T cố định thì kết quả phụ thuộc cách chọn ngưỡng. Điểm nghẽn thực tế còn lại là sinh ứng viên ở k = 2 và bộ nhớ tidset ở minsup thấp, là cơ sở của ba hướng tối ưu ở mục I.

---
**Tài liệu tham khảo (cho mục II)**

[1] R. Agrawal and R. Srikant, "Fast algorithms for mining association rules," in *Proc. 20th Int. Conf. Very Large Data Bases (VLDB)*, Santiago, Chile, 1994, pp. 487–499.

[2] P. Fournier-Viger *et al.*, "The SPMF open-source data mining library," *J. Mach. Learn. Res.*, vol. 15, pp. 3389–3393, 2014.

[3] M. J. Zaki and K. Gouda, "Fast vertical mining using diffsets," in *Proc. ACM SIGKDD*, 2003, pp. 326–335.
