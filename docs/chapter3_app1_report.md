# CHƯƠNG 3. THỰC NGHIỆM VÀ ĐÁNH GIÁ KẾT QUẢ

## 3.1. Giới thiệu bài toán
Trong bán lẻ, mỗi giao dịch thường chứa nhiều sản phẩm được khách hàng mua cùng lúc. Việc thống kê riêng số lần bán của từng sản phẩm chỉ cho biết sản phẩm nào phổ biến, nhưng chưa thể hiện mối liên hệ giữa chúng.

Bài toán **Market Basket Analysis** (phân tích giỏ hàng) nhằm tìm ra những nhóm sản phẩm thường xuất hiện cùng nhau, từ đó phát hiện các mối liên hệ có thể hỗ trợ doanh nghiệp trong việc bố trí sản phẩm, xây dựng combo và gợi ý mua kèm.

**Quy trình thực nghiệm:**
$$\text{Dữ liệu giao dịch} \rightarrow \text{Frequent Itemset Mining} \rightarrow \text{Sinh luật kết hợp} \rightarrow \text{Lọc và xếp hạng luật} \rightarrow \text{Phân tích ý nghĩa kinh doanh}$$

Nhóm sử dụng **Frequent Itemset Mining (FIM)** vì dữ liệu có dạng tập hợp sản phẩm trong từng giao dịch, không yêu cầu thứ tự mua hàng. Thuật toán **Apriori** được lựa chọn nhờ tính chất: *nếu một tập mặt hàng là phổ biến thì mọi tập con khác rỗng của nó cũng phải phổ biến*. Tính chất này giúp loại bỏ các ứng viên không cần thiết trong quá trình tìm kiếm.

## 3.2. Dữ liệu và biểu diễn giao dịch

### 3.2.1. Nguồn và thống kê dữ liệu
Thực nghiệm sử dụng bộ dữ liệu **Groceries**, gồm dữ liệu giao dịch tại một cửa hàng tạp hóa trong khoảng một tháng. Bộ dữ liệu được cung cấp trong hệ sinh thái R package `arules` và được mô tả bởi Hahsler, Hornik và Reutterer.

**Bảng 3.1. Thống kê dữ liệu**

| Thuộc tính | Giá trị |
| :--- | :--- |
| Số giao dịch | 9.835 |
| Số mặt hàng phân biệt | 169 |
| Thời gian dữ liệu | 30 ngày |
| Đơn vị phân tích | Giao dịch |
| Dạng biểu diễn | Tập hợp mặt hàng |

### 3.2.2. Biểu diễn giao dịch
Mỗi giao dịch được biểu diễn thành một tập hợp các sản phẩm. Thuật toán chỉ xét một sản phẩm có xuất hiện trong giao dịch hay không, không phân tích số lượng sản phẩm được mua.

Cách biểu diễn này phù hợp với Apriori vì mục tiêu là khai phá sự đồng xuất hiện giữa các mặt hàng. Dữ liệu không có thông tin thứ tự mua hàng nên kết quả không thể hiện quan hệ trước–sau giữa các sản phẩm.

## 3.3. Cơ sở lý thuyết: Support, Confidence và Lift
Một luật kết hợp có dạng:
$$X \Rightarrow Y, \quad X \cap Y = \varnothing$$
Trong đó $X$ là vế điều kiện và $Y$ là vế kết luận.

**Support** đo tỷ lệ giao dịch chứa đồng thời cả hai vế:
$$Support(X \Rightarrow Y) = P(X \cup Y)$$

**Confidence** đo xác suất xuất hiện của $Y$ khi giao dịch đã chứa $X$:
$$Confidence(X \Rightarrow Y) = \frac{Support(X \cup Y)}{Support(X)}$$

Tuy nhiên, Confidence có một hạn chế: nó không xét đến mức độ phổ biến vốn có của $Y$. **Lift** khắc phục hạn chế này bằng cách so sánh Confidence với Support nền của vế kết luận:
$$Lift(X \Rightarrow Y) = \frac{Confidence(X \Rightarrow Y)}{Support(Y)}$$

**Ý nghĩa:**
* $Lift > 1$: $X$ và $Y$ xuất hiện cùng nhau nhiều hơn mức kỳ vọng nếu chúng độc lập.
* $Lift = 1$: $X$ và $Y$ độc lập theo phân phối thực nghiệm.
* $Lift < 1$: $X$ và $Y$ xuất hiện cùng nhau ít hơn mức kỳ vọng nếu chúng độc lập.

**Ý nghĩa kinh doanh:** 
* Một luật có Confidence cao chưa chắc mang lại thông tin mới. Ví dụ, nếu sản phẩm $Y$ vốn đã xuất hiện trong phần lớn giao dịch, việc nhiều khách hàng mua $Y$ sau khi mua $X$ có thể chỉ phản ánh mức phổ biến nền của $Y$.
* Lift giúp nhận diện những luật mà xác suất xuất hiện của $Y$ tăng đáng kể khi có $X$, thay vì chỉ phản ánh thói quen mua sản phẩm phổ biến.
* Tuy nhiên, Lift cao không đồng nghĩa với luật có độ tin cậy thực nghiệm cao. Nếu $Y$ hiếm hoặc luật chỉ xuất hiện trong một số ít giao dịch, Lift có thể lớn nhưng kết quả thiếu ổn định. Vì vậy, cần kết hợp Lift với Support để tránh ưu tiên những luật quá hiếm.
* Lift cũng không chứng minh quan hệ nhân quả. Nó phản ánh mối liên hệ thống kê trong dữ liệu quan sát, không chứng minh việc mua $X$ khiến khách hàng mua $Y$.

## 3.4. Thực nghiệm và lựa chọn ngưỡng
Nhóm khảo sát bảy mức `minsup` và năm mức `minconf` để đánh giá ảnh hưởng của ngưỡng đến số lượng luật.

**Bảng 3.2. Kết quả khảo sát ngưỡng `minsup` và `minconf`**
*(Trong mỗi ô, số liệu có dạng: Số luật sinh ra / Số luật Lift > 1 / Số luật sau tinh gọn)*

| Minsup | Số tập phổ biến | Conf 0,2 | Conf 0,3 | Conf 0,4 | Conf 0,5 | Conf 0,6 |
| :--- | :---: | :---: | :---: | :---: | :---: | :---: |
| **0,05** | 31 | 6/6/3 | 3/3/3 | 1/1/1 | 0/0/0 | 0/0/0 |
| **0,02** | 122 | 73/70/57 | 37/37/34 | 15/15/14 | 1/1/1 | 0/0/0 |
| **0,01** | 333 | 234/231/172 | 125/125/100 | 62/62/54 | 15/15/15 | 0/0/0 |
| **0,005** | 1.001 | 893/885/511 | 487/487/348 | 270/270/227 | 120/120/110 | 22/22/21 |
| **0,003** | 2.226 | 2.368/2.356/1.244 | 1.390/1.390/945 | 825/825/657 | 422/422/364 | 120/120/109 |
| **0,002** | 4.223 | 5.511/5.496/2.660 | 3.228/3.228/2.062 | 1.929/1.929/1.437 | 1.101/1.101/894 | 376/376/335 |
| **0,001** | 13.492 | 25.022/24.987/9.769 | 14.946/14.946/7.528 | 9.382/9.382/5.574 | 5.829/5.829/3.994 | 2.961/2.961/2.292 |

**Kết quả cho thấy:**
* Khi `minsup` giảm, số tập phổ biến và số luật tăng mạnh. Tại `minsup = 0,001`, thuật toán tìm được 13.492 tập phổ biến.
* Khi `minconf` tăng, số luật được giữ lại giảm do điều kiện Confidence nghiêm ngặt hơn.
* Không phải mọi luật sinh ra đều có $Lift > 1$. Ví dụ tại `minsup = 0,005` và `minconf = 0,2`, có 893 luật nhưng chỉ 885 luật có $Lift > 1$.
* Bước tinh gọn tiếp tục giảm số luật để hạn chế luật trùng đại diện và luật con dư thừa.

### Lựa chọn ngưỡng
Nhóm lựa chọn:
$$minsup = 0,005, \qquad minconf = 0,3$$

Tại ngưỡng này, kết quả gồm:

| Chỉ số | Giá trị |
| :--- | :--- |
| Số tập phổ biến | 1.001 |
| Số luật sinh ra | 487 |
| Số luật $Lift > 1$ | 487 |
| Số luật sau tinh gọn | 348 |
| Median Lift | 2,040 |
| Max Lift | 4,716 |
| Minsup count | 50 |

Lựa chọn này là sự đánh đổi giữa số lượng luật và khả năng khai thác:
* Với `minsup = 0,01` và `minconf = 0,3`, chỉ còn 100 luật sau tinh gọn, có thể bỏ qua một số tổ hợp ít phổ biến hơn.
* Với `minsup = 0,003` và `minconf = 0,3`, số luật sau tinh gọn tăng lên 945.
* Với `minsup = 0,001` và `minconf = 0,3`, số luật tăng lên 7.528, gây khó khăn cho việc phân tích thủ công.
* Tại ngưỡng được chọn, 348 luật sau tinh gọn là quy mô phù hợp hơn với phạm vi thực nghiệm của đồ án.

Ngoài ra, tại cặp ngưỡng được chọn, Support count nhỏ nhất của vế kết luận trong các luật được xét là 736 giao dịch. Điều này giúp hạn chế các luật có vế kết luận quá hiếm so với những cấu hình `minsup` thấp hơn. Đây là lựa chọn thực nghiệm phù hợp với bộ dữ liệu và mục tiêu đồ án, không phải ngưỡng tối ưu cho mọi bài toán.

## 3.5. Đánh giá Top 10 luật theo Lift
Sau khi sinh luật, nhóm giữ lại các luật có $Lift > 1$, loại luật đối xứng hoặc trùng đại diện cho cùng tập hợp sản phẩm và áp dụng heuristic tỉa một số luật con dư thừa. Các luật được xếp hạng giảm dần theo Lift. Support được sử dụng làm tiêu chí phụ khi cần.

**Bảng 3.3. Top 10 luật theo Lift**

| STT | Luật kết hợp | Support (số giỏ) | Support (%) | Confidence | Lift |
| :---: | :--- | :---: | :---: | :---: | :---: |
| 1 | `{pip fruit, root vegetables}` $\rightarrow$ `{other vegetables, whole milk}` | 54 | 0,55% | 0,353 | 4,716 |
| 2 | `{root vegetables, tropical fruit}` $\rightarrow$ `{other vegetables, whole milk}` | 69 | 0,70% | 0,333 | 4,454 |
| 3 | `{citrus fruit, root vegetables}` $\rightarrow$ `{other vegetables, whole milk}` | 57 | 0,58% | 0,328 | 4,377 |
| 4 | `{root vegetables, whipped/sour cream}` $\rightarrow$ `{other vegetables, whole milk}` | 51 | 0,52% | 0,304 | 4,057 |
| 5 | `{root vegetables, yogurt}` $\rightarrow$ `{other vegetables, whole milk}` | 77 | 0,78% | 0,303 | 4,051 |
| 6 | `{herbs}` $\rightarrow$ `{root vegetables}` | 69 | 0,70% | 0,431 | 3,956 |
| 7 | `{citrus fruit, pip fruit}` $\rightarrow$ `{tropical fruit}` | 55 | 0,56% | 0,404 | 3,854 |
| 8 | `{root vegetables, whole milk, yogurt}` $\rightarrow$ `{tropical fruit}` | 56 | 0,57% | 0,392 | 3,732 |
| 9 | `{curd, tropical fruit}` $\rightarrow$ `{yogurt}` | 52 | 0,53% | 0,515 | 3,691 |
| 10 | `{beef, other vegetables}` $\rightarrow$ `{root vegetables}` | 78 | 0,79% | 0,402 | 3,689 |

*(Support phần trăm được tính bằng Support count chia cho 9.835 giao dịch)*

### Phân tích kết quả
* **Nhóm 1 – Các tổ hợp dẫn đến `{other vegetables, whole milk}`:** Năm luật đầu tiên có cùng vế kết luận là `{other vegetables, whole milk}`. Luật đứng đầu có $Lift = 4,716$, nghĩa là hai vế xuất hiện cùng nhau nhiều hơn khoảng 4,716 lần so với mức kỳ vọng nếu chúng độc lập. Đây là một nhóm liên hệ đáng chú ý giữa trái cây, rau củ và nhóm sản phẩm sữa. Doanh nghiệp có thể thử nghiệm bố trí các nhóm hàng gần nhau, tạo combo hoặc gợi ý mua kèm. Tuy nhiên, Support của từng luật chỉ từ 0,52% đến 0,78%. Đây không phải hành vi phổ biến trên toàn bộ khách hàng, vì vậy nên thử nghiệm ở quy mô nhỏ trước.
* **Nhóm 2 – `{herbs}` $\rightarrow$ `{root vegetables}`:** Luật có $Confidence = 0,431$ và $Lift = 3,956$. Những giao dịch có `herbs` có xu hướng chứa `root vegetables` cao hơn đáng kể so với xác suất nền. Có thể thử nghiệm bố trí hai nhóm hàng gần nhau hoặc gợi ý mua kèm. Support của luật là 69 giao dịch, nên cần đánh giá thêm quy mô khách hàng trước khi triển khai diện rộng.
* **Nhóm 3 – `{citrus fruit, pip fruit}` $\rightarrow$ `{tropical fruit}`:** Luật có $Confidence = 0,404$ và $Lift = 3,854$. Đây là dấu hiệu cho thấy các nhóm trái cây có mối liên hệ trong giỏ hàng. Có thể thử nghiệm combo trái cây nhiều loại hoặc gợi ý `tropical fruit` khi khách hàng chọn `citrus fruit` và `pip fruit`.
* **Nhóm 4 – `{root vegetables, whole milk, yogurt}` $\rightarrow$ `{tropical fruit}`:** Luật có $Confidence = 0,392$ và $Lift = 3,732$. Nhóm giao dịch chứa rau củ, sữa nguyên kem và yogurt có xu hướng xuất hiện thêm `tropical fruit`. Có thể sử dụng luật để gợi ý sản phẩm bổ sung trên ứng dụng mua sắm hoặc thử nghiệm combo thực phẩm.
* **Nhóm 5 – `{curd, tropical fruit}` $\rightarrow$ `{yogurt}`:** Đây là luật có Confidence cao nhất trong Top 10, đạt $0,515$; $Lift = 3,691$. Trong các giao dịch có `curd` và `tropical fruit`, 51,5% đồng thời có `yogurt`. Có thể thử nghiệm coupon hoặc gợi ý `yogurt` khi khách hàng chọn hai nhóm sản phẩm điều kiện.
* **Nhóm 6 – `{beef, other vegetables}` $\rightarrow$ `{root vegetables}`:** Luật có Support cao nhất trong Top 10 theo Lift, đạt 78 giao dịch; $Confidence = 0,402$ và $Lift = 3,689$. Có thể gợi ý `root vegetables` khi khách hàng mua `beef` và `other vegetables`, hoặc thử nghiệm combo nguyên liệu nấu ăn.

Các đề xuất trên là giả thuyết ứng dụng được suy ra từ mối liên hệ thống kê. Hiệu quả thực tế cần được kiểm chứng bằng thử nghiệm kinh doanh.

## 3.6. Đối chiếu Top 10 theo Support
Để đánh giá sự khác biệt giữa mức độ phổ biến và mức độ liên kết, nhóm tiếp tục xếp hạng luật theo Support tại cùng cặp ngưỡng.

**Bảng 3.4. Top 10 luật theo Support**

| STT | Luật kết hợp | Support (số giỏ) | Support (%) | Confidence | Lift |
| :---: | :--- | :---: | :---: | :---: | :---: |
| 1 | `{other vegetables}` $\rightarrow$ `{whole milk}` | 736 | 7,48% | 0,387 | 1,514 |
| 2 | `{rolls/buns}` $\rightarrow$ `{whole milk}` | 557 | 5,66% | 0,308 | 1,205 |
| 3 | `{yogurt}` $\rightarrow$ `{whole milk}` | 551 | 5,60% | 0,402 | 1,572 |
| 4 | `{root vegetables}` $\rightarrow$ `{whole milk}` | 481 | 4,89% | 0,449 | 1,756 |
| 5 | `{root vegetables}` $\rightarrow$ `{other vegetables}` | 466 | 4,74% | 0,435 | 2,247 |
| 6 | `{yogurt}` $\rightarrow$ `{other vegetables}` | 427 | 4,34% | 0,311 | 1,608 |
| 7 | `{tropical fruit}` $\rightarrow$ `{whole milk}` | 416 | 4,23% | 0,403 | 1,578 |
| 8 | `{tropical fruit}` $\rightarrow$ `{other vegetables}` | 353 | 3,59% | 0,342 | 1,768 |
| 9 | `{bottled water}` $\rightarrow$ `{whole milk}` | 338 | 3,44% | 0,311 | 1,217 |
| 10 | `{pastry}` $\rightarrow$ `{whole milk}` | 327 | 3,32% | 0,374 | 1,463 |

### So sánh và đánh giá
Luật `{other vegetables}` $\rightarrow$ `{whole milk}` đứng đầu theo Support với 736 giao dịch, tương đương 7,48%, nhưng Lift chỉ đạt $1,514$. Trong khi đó, luật `{pip fruit, root vegetables}` $\rightarrow$ `{other vegetables, whole milk}` chỉ xuất hiện trong 54 giao dịch, tương đương 0,55%, nhưng Lift đạt $4,716$.

Hai kết quả phản ánh hai mục tiêu khác nhau:
* **Support:** Phù hợp để nhận diện hành vi mua phổ biến, hỗ trợ dự trữ hàng và bố trí sản phẩm bán chạy.
* **Lift:** Phù hợp để tìm các tổ hợp có mức liên kết nổi bật so với xác suất nền, hỗ trợ gợi ý mua kèm và thử nghiệm marketing.

Vì mục tiêu của đồ án là phát hiện những mối liên hệ có thể khai thác trong kinh doanh, nhóm sử dụng Lift làm tiêu chí xếp hạng chính. Tuy nhiên, Support vẫn cần được giữ lại để đánh giá quy mô và độ phổ biến của từng luật. Do đó, không thể kết luận Lift luôn tốt hơn Support. Hai chỉ số bổ trợ nhau và cần được lựa chọn theo mục tiêu ứng dụng.

## 3.7. Hạn chế
1. **Không chứng minh quan hệ nhân quả:** Luật kết hợp chỉ phản ánh sự đồng xuất hiện. Các mối liên hệ có thể chịu ảnh hưởng bởi mùa vụ, khuyến mãi hoặc nhu cầu chung.
2. **Lift nhạy với các mặt hàng hiếm:** Một luật có thể đạt Lift rất cao nhưng chỉ dựa trên ít giao dịch. Việc kết hợp Lift với Support giúp giảm rủi ro này, nhưng chưa đảm bảo luật ổn định trên dữ liệu mới.
3. **Kết quả phụ thuộc ngưỡng:** Thay đổi `minsup` và `minconf` có thể làm thay đổi đáng kể số lượng tập phổ biến và luật kết hợp. Ngưỡng được chọn chỉ phù hợp với thực nghiệm hiện tại.
4. **Heuristic tinh gọn có thể loại bỏ luật hữu ích:** Việc loại luật đối xứng và tỉa luật con giúp giảm dư thừa, nhưng không đảm bảo mọi luật bị loại đều không có giá trị kinh doanh. Đây là chính sách xử lý do nhóm lựa chọn.
5. **Thiếu dữ liệu kinh doanh:** Dữ liệu chưa cung cấp đầy đủ giá bán, lợi nhuận, thông tin khách hàng, thời gian mua và kết quả sau khuyến mãi. Vì vậy, nhóm chưa thể đánh giá trực tiếp tác động của các luật đến doanh thu hoặc lợi nhuận.
6. **Chưa kiểm chứng trên dữ liệu mới:** Các luật cần được đánh giá trên những giai đoạn dữ liệu khác và thử nghiệm có đối chứng trước khi triển khai thực tế.

## 3.8. Kết luận
Thực nghiệm trên 9.835 giao dịch và 169 mặt hàng cho thấy Apriori có thể khai phá các tập phổ biến và luật kết hợp từ dữ liệu giỏ hàng.

Nhóm lựa chọn $minsup = 0,005$ và $minconf = 0,3$, thu được 1.001 tập phổ biến, 487 luật có $Lift > 1$ và 348 luật sau tinh gọn.

Kết quả Top 10 cho thấy Lift giúp nhận diện các tổ hợp có mức liên kết nổi bật, trong khi Support phản ánh những hành vi mua sắm phổ biến. Các luật có thể hỗ trợ đề xuất bố trí sản phẩm, combo và gợi ý mua kèm, nhưng cần được kiểm chứng bằng dữ liệu và thử nghiệm kinh doanh thực tế.

---

## TÀI LIỆU THAM KHẢO
1. R. Agrawal and R. Srikant, “Fast Algorithms for Mining Association Rules,” *Proceedings of the 20th International Conference on Very Large Data Bases (VLDB)*, 1994, pp. 487–499.
2. M. Hahsler, K. Hornik, and T. Reutterer, “Implications of Probabilistic Data Modeling for Mining Association Rules,” in *From Data and Information Analysis to Knowledge Engineering*, Springer, 2006, pp. 598–605.
3. M. Hahsler, K. Hornik, and T. Reutterer, “Groceries: The Groceries Transactions Data Set,” R package `arules`, documentation. [https://michael.hahsler.net/arules/reference/Groceries.html](https://michael.hahsler.net/arules/reference/Groceries.html)