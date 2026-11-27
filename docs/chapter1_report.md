# I. CÀI ĐẶT THUẬT TOÁN APRIORI

Chương này trình bày cách nhóm cài đặt Apriori bằng Julia, dựa trên bài báo gốc của Agrawal và Srikant [1]. Nhóm có hai bản cài đặt: bản **basic** bám sát mô tả trong bài báo, và bản **bitarray** dùng biểu diễn dọc để tăng tốc. Hai bản chung phần sinh ứng viên và cho cùng một kết quả. Ngoài ra, nhóm cài thêm phần sinh luật kết hợp để dùng ở Chương III. Toàn bộ mã nguồn chỉ dùng thư viện chuẩn của Julia, không dùng thư viện khai thác tập phổ biến nào.

## A. Bài toán và ý tưởng của Apriori

Cho một CSDL gồm $|D|$ giao dịch, mỗi giao dịch là một tập item. *Support* của một itemset $X$ là số giao dịch chứa $X$. Với ngưỡng *minsup*, $X$ là **tập phổ biến** khi support của nó không nhỏ hơn minsup. Bài toán đặt ra là tìm mọi tập phổ biến cùng support của chúng.

Apriori dựa trên một nhận xét đơn giản: mọi tập con của một tập phổ biến cũng phổ biến. Nói ngược lại, chỉ cần một tập con không phổ biến là tập lớn hơn chắc chắn không phổ biến, nên không cần đếm. Thuật toán vì thế đi theo từng mức. Từ các tập phổ biến kích thước $k-1$ (ký hiệu $L_{k-1}$), nó sinh ra các ứng viên kích thước $k$ (ký hiệu $C_k$), đếm support của các ứng viên rồi giữ lại những ứng viên đạt ngưỡng để được $L_k$. Quá trình dừng khi không sinh thêm được ứng viên nào.

```
L1 = {các item phổ biến}
k = 2
while L(k-1) khác rỗng:
    Ck = apriori-gen(L(k-1))          # join + prune (mục B)
    đếm support của mọi c trong Ck    # basic: mục C, bitarray: mục D
    Lk = {c trong Ck : support(c) >= minsup}
    k = k + 1
return hợp của mọi Lk
```

Trong cả hai bản, itemset là một `Vector{Int}` đã sắp tăng dần, còn kết quả là một `Dict{Vector{Int},Int}` ánh xạ itemset sang support tuyệt đối.

## B. Sinh ứng viên (apriori-gen)

Hàm `generate_candidates_with_parents` ([src/apriori.jl](../src/apriori.jl)) cài đặt hai bước join và prune ở mục 2.1.1 của bài báo.

**Join.** Hai itemset trong $L_{k-1}$ được ghép với nhau khi chúng giống nhau ở $k-2$ item đầu và khác nhau ở item cuối. Kết quả là một ứng viên $k$ item. Vì $L_{k-1}$ được giữ theo thứ tự từ điển, các itemset chung tiền tố luôn đứng liền nhau. Nhờ vậy, vòng lặp trong có thể dừng ngay khi gặp tiền tố khác, thay vì phải so mọi cặp. Ứng viên sinh ra cũng tự nhiên theo thứ tự từ điển, nên mức sau dùng được ngay mà không phải sắp xếp lại.

**Prune.** Một ứng viên chỉ được giữ khi mọi tập con $k-1$ item của nó đều nằm trong $L_{k-1}$. Trong $k$ tập con đó, hai tập con (bỏ item cuối, hoặc bỏ item kế cuối) chính là hai itemset cha vừa đem ghép, nên chắc chắn phổ biến. Vì vậy hàm chỉ kiểm tra $k-2$ tập con còn lại. Các tập con được dựng trong một buffer dùng chung, không cấp phát mảng mới cho mỗi lần kiểm tra.

**Ví dụ.** Với CSDL ở Figure 3 của bài báo và minsup = 2 giao dịch, $L_2 = \{\{1,3\}, \{2,3\}, \{2,5\}, \{3,5\}\}$. Bước join chỉ ghép được $\{2,3\}$ với $\{2,5\}$, cho ứng viên $\{2,3,5\}$. Bước prune kiểm tra tập con còn lại $\{3,5\}$, thấy nó phổ biến nên giữ ứng viên. Kết quả cuối có 9 tập phổ biến, khớp với bài báo và với SPMF.

Ngoài danh sách ứng viên, hàm còn trả về chỉ số của hai itemset cha cho từng ứng viên. Đây chính là trường *generators* mà bài báo mô tả ở mục 2.2.2, và bản bitarray dùng nó để đếm support (mục D).

## C. Bản cơ bản (basic)

Bản basic ([src/apriori.jl](../src/apriori.jl)) đếm support theo đúng cách trực tiếp nhất. Ở mỗi mức $k$, hàm `count_support` duyệt mọi cặp (ứng viên, giao dịch) và kiểm tra ứng viên có là tập con của giao dịch hay không. Mỗi giao dịch được chuyển thành `Set` để phép kiểm tra tập con nhanh hơn.

Như vậy, mỗi mức tốn khoảng $|C_k| \cdot |D| \cdot k$ phép tra cứu và phải quét lại toàn bộ CSDL. Bài báo giảm chi phí này bằng hash-tree (mục 2.1.2): thay vì thử từng ứng viên, mỗi giao dịch chỉ đi theo các nhánh có thể chứa nó. Nhóm cố ý không cài hash-tree trong bản basic, để có một mốc so sánh rõ ràng cho các tối ưu của bản bitarray. Do đó cần hiểu bản basic là một baseline đơn giản, không phải một Apriori đầy đủ như trong bài báo.

## D. Bản tối ưu BitArray

Bản bitarray ([src/apriori_bitarray.jl](../src/apriori_bitarray.jl)) chuyển sang biểu diễn **dọc**. Thay vì lưu danh sách item của mỗi giao dịch, nó lưu với mỗi itemset một *tidset*: một dãy $|D|$ bit, trong đó bit thứ $t$ bằng 1 khi giao dịch $t$ chứa itemset. Support khi đó chỉ là số bit 1 trong tidset.

Ý tưởng chính lấy từ AprioriTid (bước 7, Figure 2 của bài báo): ứng viên $c$ nằm trong giao dịch $t$ khi và chỉ khi hai itemset cha của $c$ đều nằm trong $t$. Với tidset, điều này trở thành một phép AND:

$$\text{tid}(c) = \text{tid}(\text{cha}_1) \;\text{AND}\; \text{tid}(\text{cha}_2)$$

Do đó, sau lần quét đầu, thuật toán không cần đọc lại CSDL. Cụ thể, CSDL chỉ được duyệt hai lần: một lần để đếm support của từng item, một lần để dựng tidset cho các item phổ biến. Từ mức $k = 2$ trở đi, mọi phép đếm đều làm trên tidset.

Các tối ưu cụ thể trong bản này:

1. **AND và đếm bit trên từ 64 bit.** Hàm `and_count!` làm việc thẳng trên mảng từ máy bên trong `BitVector`, AND từng từ 64 bit rồi đếm bit bằng `count_ones` (một lệnh `popcnt` của CPU). Vòng lặp dùng `@inbounds @simd`, nên mỗi ứng viên chỉ tốn khoảng $\lceil |D|/64 \rceil$ phép toán, không phụ thuộc độ dài giao dịch hay kích thước itemset.
2. **Lấy tidset của cha theo chỉ số.** Nhờ trường *generators* ở mục B, tidset của hai cha được lấy trực tiếp theo vị trí trong mảng, không phải tra `Dict` bằng itemset ở mỗi ứng viên.
3. **Chỉ dựng tidset cho item phổ biến.** Item không đạt minsup bị loại ngay sau lần quét đầu, nên không tốn $|D|$ bit bộ nhớ nào. Điều này đặc biệt có ích với dữ liệu thưa như Retail, nơi phần lớn trong hơn 16 nghìn item không phổ biến.
4. **Dùng lại buffer.** Kết quả AND được ghi vào một buffer chung. Chỉ khi ứng viên đạt minsup, buffer mới được sao ra thành tidset của nó. Ứng viên bị loại không tốn thêm bộ nhớ.
5. **Chỉ giữ hai mức tidset.** Tại mỗi thời điểm, bộ nhớ chỉ chứa tidset của $L_{k-1}$ và $L_k$. Mức cũ được bỏ ngay khi sinh xong mức mới.

Cái giá của cách làm này là bộ nhớ. Mỗi tập phổ biến đang giữ tốn $|D|/8$ byte, bất kể nó thưa hay dày. Với CSDL lớn và minsup thấp, phần này có thể vượt xa bộ nhớ của bản basic. Chương II đo cụ thể sự đánh đổi này.

<p align="center"><b>Bảng 1.1.</b> So sánh hai bản cài đặt</p>

| | basic | bitarray |
|---|---|---|
| Biểu diễn CSDL | ngang (danh sách item của mỗi giao dịch) | dọc (tidset dạng `BitVector`) |
| Đếm support ở mức $k$ | $O(\lvert C_k\rvert \cdot \lvert D\rvert \cdot k)$ | $O(\lvert C_k\rvert \cdot \lceil \lvert D\rvert/64\rceil)$ |
| Số lần đọc CSDL | bằng số mức, cộng 1 | 2 |
| Bộ nhớ thêm | `Set` cho mỗi giao dịch | $(\lvert L_{k-1}\rvert + \lvert L_k\rvert) \cdot \lvert D\rvert / 8$ byte |
| Phụ thuộc độ dài giao dịch | có | không |

## E. Sinh luật kết hợp

Chương III cần luật kết hợp dạng $X \Rightarrow Y$, nên nhóm cài thêm hàm `association_rules` ([src/rules.jl](../src/rules.jl)). Luật được tính từ chính các tập phổ biến của mục trên, không cần đọc lại CSDL. Với mỗi luật:

- *support* là số giao dịch chứa $X \cup Y$;
- *confidence* bằng $\text{sup}(X \cup Y) / \text{sup}(X)$;
- *lift* bằng $\text{confidence} / (\text{sup}(Y)/|D|)$. Lift lớn hơn 1 nghĩa là $X$ và $Y$ đi cùng nhau thường hơn so với khi chúng độc lập.

Hàm theo thủ tục ap-genrules ở mục 3 của bài báo. Với mỗi tập phổ biến $l$, hậu tố $Y$ được sinh dần từ 1 item trở lên, bằng chính hàm apriori-gen ở mục B. Thủ tục này dựa vào một tính chất: nếu luật $l \setminus Y \Rightarrow Y$ không đạt minconf thì mọi luật có hậu tố lớn hơn $Y$ cũng không đạt, vì vế trái càng nhỏ thì support của nó càng lớn. Nhờ vậy, chỉ những hậu tố đã đạt ngưỡng mới được mở rộng, và không phải thử hết $2^{|l|} - 2$ cách tách. Lift không có tính chất này, nên chỉ được dùng để lọc kết quả cuối.

Dữ liệu thật thường có item là chuỗi, như tên sản phẩm hay tên sự kiện. Hàm `encode_transactions` đổi chúng sang mã số nguyên để đưa vào thuật toán, đồng thời trả về bảng tra ngược. Hai hàm `decode` và `format_rule` dùng bảng này để in luật bằng tên gốc.

## F. Định dạng vào/ra và tham số dòng lệnh

Định dạng vào/ra giống SPMF để dễ đối chiếu. File vào có mỗi dòng là một giao dịch, item là số nguyên cách nhau bởi dấu cách; dòng trống và dòng chú thích (bắt đầu bằng `#`, `@`, `%`) được bỏ qua. File ra có mỗi dòng là một tập phổ biến kèm support, ví dụ `1 3 #SUP: 2`. Luật được ghi theo dạng `1 2 ==> 3 #SUP: 5 #CONF: 0.8 #LIFT: 1.2`, cũng giống SPMF.

Chương trình chạy từ dòng lệnh như sau:

```
julia --project scripts/main.jl <input> <minsup> <output> [basic|bitarray]
```

Tham số `minsup` nhận ba cách viết: `40%` hoặc `0.4` là tỉ lệ, còn `2` là số giao dịch tuyệt đối. Khi minsup là tỉ lệ, ngưỡng tuyệt đối được tính bằng `ceil(minsup * số_giao_dịch)`, đúng công thức của SPMF. Chi tiết này nghe nhỏ nhưng quan trọng. Chẳng hạn $0{,}07 \times 3000$ trong số thực dấu phẩy động bằng $210{,}00000000000003$, nên ngưỡng là 211 chứ không phải 210. Nếu làm tròn khác SPMF, kết quả sẽ lệch ở những itemset có support đúng bằng 210.

Chương trình in số tập phổ biến, thời gian khai thác và bộ nhớ:

```
$ julia --project scripts/main.jl data/toy/toy1.txt 50% out.txt bitarray
[bitarray] 4 transactions, minsup = 2 -> 9 frequent itemsets
  mining time: 0.03 ms (read: 0.33 ms, GC: 0.0 ms)
  allocated by mining: 0.0 MB, peak RAM of process: 277.3 MB
```

Julia biên dịch hàm ở lần gọi đầu tiên, nên nếu đo ngay lần đó thì thời gian sẽ gồm cả thời gian biên dịch. Để tránh điều này, chương trình chạy thuật toán một lần trên CSDL rất nhỏ trước khi đo. Thời gian in ra chỉ gồm phần khai thác, không gồm đọc và ghi file.

## G. Kiểm thử

Bộ test chạy bằng `julia --project test/runtests.jl` hoặc `Pkg.test()`, và hiện cho kết quả 187/187 test đạt. Bộ test gồm bốn nhóm.

**Unit test cho từng thành phần:** đọc/ghi file, cách tính ngưỡng minsup (gồm trường hợp $0{,}07 \times 3000$ ở trên), bước join và prune, chỉ số cha, đếm support, dựng tidset và phép AND, tham số `maxlen` (giới hạn kích thước tập). Có cả các trường hợp biên: CSDL rỗng, CSDL chỉ có một giao dịch, minsup lớn hơn số giao dịch.

**Đối chiếu tập phổ biến với SPMF** trên 12 case, gồm CSDL ở Figure 3 của bài báo, dữ liệu dày nhỏ, giao dịch dài, dữ liệu thưa và dữ liệu tổng hợp theo bộ sinh ở mục 4.3 của bài báo. Mỗi case so toàn bộ itemset lẫn support, không chỉ so số lượng. Kết quả SPMF được lưu sẵn trong repo, nên chạy test không cần cài Java.

**Đối chiếu luật kết hợp với SPMF** (thuật toán `FPGrowth_association_rules_with_lift`) trên 8 case, gồm minconf bằng 0% (mọi cách tách luật), minconf bằng 100% và itemset dài. Ngoài ra, kết quả của ap-genrules còn được so với cách vét cạn mọi cách tách $X \cup Y$ trên ba CSDL.

**Hai bản cho cùng kết quả:** ngoài các case SPMF ở trên (mỗi case chạy cả hai bản), basic và bitarray còn được so trực tiếp với nhau trên các CSDL nhỏ có trường hợp đặc biệt: CSDL rỗng, giao dịch rỗng, item lặp trong một giao dịch, minsup lớn hơn số giao dịch.

<p align="center"><b>Bảng 1.2.</b> Đối chiếu với SPMF (mỗi case chạy cả basic lẫn bitarray)</p>

| Nội dung | Số case | Tổng số mục SPMF | Tỉ lệ khớp |
|---|---|---|---|
| Tập phổ biến | 12 | 3 426 itemset | 100% |
| Luật kết hợp | 8 | 2 879 luật | 100% |

Trên dữ liệu benchmark lớn, Chương II tiếp tục đối chiếu ở mọi điểm đo và cũng khớp 100%.

## H. Mức cải thiện của bản tối ưu

Để đo riêng tác dụng của các tối ưu, nhóm chạy hai bản trên cùng CSDL và cùng minsup, lấy trung vị của 5 lần chạy (`julia --project benchmarks/optimization.jl`, Julia 1.12.6).

<p align="center"><b>Bảng 1.3.</b> Thời gian và bộ nhớ cấp phát của hai bản</p>

| CSDL | #giao dịch | minsup | #tập phổ biến | basic | bitarray | Tăng tốc | Cấp phát basic | Cấp phát bitarray |
|---|---|---|---|---|---|---|---|---|
| quest_medium | 3 000 | 2% | 920 | 338 ms | 6,1 ms | 55× | 7,6 MB | 2,8 MB |
| sparse | 1 000 | 0,3% | 338 | 632 ms | 38,8 ms | 16× | 21,0 MB | 18,4 MB |
| long_tx | 60 | 60% | 1 725 | 16,9 ms | 6,1 ms | 2,8× | 2,8 MB | 2,7 MB |

Mức tăng tốc phụ thuộc nhiều vào số giao dịch. Trên long_tx chỉ có 60 giao dịch, nên tidset của mỗi itemset gói gọn trong một từ 64 bit và bản basic cũng không phải quét nhiều. Hai bản vì thế chênh nhau không đáng kể (2,8×). Khi số giao dịch tăng lên vài nghìn, một phép AND thay cho 64 lần kiểm tra tập con, và việc không phải quét lại CSDL ở mỗi mức bắt đầu có tác dụng rõ, nên mức tăng tốc lên 16–55×. Ở chiều ngược lại, bộ nhớ cấp phát của bản bitarray không lớn hơn bản basic trên cả ba CSDL, vì bản basic phải dựng lại `Set` cho mọi giao dịch ở mỗi mức.

Trên các CSDL benchmark lớn hơn nhiều, Chương II cho thấy khoảng cách còn lớn hơn: bản bitarray nhanh hơn bản basic tới hơn 1 000 lần trên T10I4D100K, và nhanh hơn SPMF ở hầu hết các điểm đo.

## I. Hạn chế

- Bản basic không có hash-tree nên rất chậm trên CSDL lớn ở minsup thấp. Nó chỉ nên được xem là mốc so sánh.
- Bản bitarray tốn $|D|/8$ byte cho mỗi tập phổ biến đang giữ, kể cả khi tập đó rất thưa. Với CSDL nhiều giao dịch và minsup thấp, bộ nhớ trở thành giới hạn chính. Các hướng khắc phục (biểu diễn lai, diffset) được bàn ở Chương II.
- Cả hai bản đều chạy đơn luồng, dù phép đếm support của các ứng viên trong cùng một mức hoàn toàn độc lập với nhau.
- Riêng Julia runtime đã chiếm khoảng 250–300 MB RAM, nên với CSDL nhỏ, peak RAM của chương trình chủ yếu phản ánh runtime chứ không phải thuật toán.

---
**Tài liệu tham khảo (cho mục I)**

[1] R. Agrawal and R. Srikant, "Fast algorithms for mining association rules," in *Proc. 20th Int. Conf. Very Large Data Bases (VLDB)*, Santiago, Chile, 1994, pp. 487–499.

[2] P. Fournier-Viger *et al.*, "The SPMF open-source data mining library," *J. Mach. Learn. Res.*, vol. 15, pp. 3389–3393, 2014.
