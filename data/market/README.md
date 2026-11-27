# Dữ liệu giỏ hàng cho Ứng dụng 1 (Groceries)

| File | Số giỏ (giao dịch) | Số item (nhóm sản phẩm) |
|---|---|---|
| `groceries.csv` | 9 835 | 169 |

## Nguồn
- **Dữ liệu gốc:** tập `Groceries` của gói R `arules`: dữ liệu bán hàng thực của một cửa hàng tạp hóa trong
  1 tháng (30 ngày), các mặt hàng đã được gộp thành 169 nhóm. Trích dẫn: Hahsler, Hornik và Reutterer (2006),
  *Implications of probabilistic data modeling for mining association rules*, trong
  Spiliopoulou, Kruse, Borgelt, Nürnberger, Gaul (chủ biên), *From Data and Information Analysis to Knowledge
  Engineering*, Springer.
- **Bản CSV nhóm dùng:** lấy từ kho mã nguồn đi kèm sách *Machine Learning with R* (B. Lantz), ấn bản 2, nhà xuất bản
  Packt, thư mục `Chapter 08`:
  `https://raw.githubusercontent.com/PacktPublishing/Machine-Learning-with-R-Second-Edition/master/Chapter%2008/groceries.csv`
- Ngày tải: 2026-11-27. File được lưu **nguyên văn**, không sửa nội dung.
- Nhóm chưa xác nhận điều khoản cấp phép riêng của file này; dữ liệu dùng cho mục đích học tập và luôn kèm trích dẫn nguồn gốc ở trên.

## Định dạng
Mỗi dòng là một hóa đơn; các item là tên nhóm sản phẩm (tiếng Anh) cách nhau dấu phẩy. Không có dòng tiêu đề, không có dấu nháy,
không có dòng trống. Đọc bằng `read_labeled_transactions(path; delim = ',')` rồi `encode_transactions` (xem `src/rules.jl`).

## Thống kê (đã kiểm tra bằng code, đối chiếu độc lập bằng Python)
- 9 835 giỏ, 169 item, tổng 43 367 lượt item; mỗi giỏ không có item trùng.
- Cỡ giỏ trung bình 4,409, lớn nhất 32. Có 2 159 giỏ chỉ chứa 1 item (22,0%).
- Item phổ biến nhất (số giỏ chứa): `whole milk` 2 513 (25,6%), `other vegetables` 1 903, `rolls/buns` 1 809,
  `soda` 1 715, `yogurt` 1 372.

## Chuẩn hóa
Không sửa file gốc. Mọi bước chuẩn hóa nằm trong code lúc nạp, để quy trình có thể kiểm tra lại:
1. Cắt khoảng trắng hai đầu mỗi item, bỏ item rỗng và dòng trống (`read_labeled_transactions`).
2. Bỏ item trùng trong cùng một giỏ và sắp xếp (`encode_transactions`).
3. Mã hóa tên item thành số nguyên theo thứ tự chữ cái (`encode_transactions`); `labels` dùng để giải mã.
4. **Không** lọc item hiếm, **không** gộp nhóm thêm, **giữ** giỏ 1 item (chúng vẫn nằm trong mẫu số của support).

## Kiểm tra toàn vẹn
`julia --project applications/prepare_groceries_data.jl` so file với: 9 835 giỏ, 169 item và
SHA-256 nội dung `f8a7074231acf5f3de6bdb7ec63fed03c28745d76bd49aa8ddc0c5d1cfa3da91`
(tính trên các dòng nối bằng LF, nên không đổi nếu Git trên Windows chuyển sang CRLF).
File hợp lệ thì script không làm gì; thiếu hoặc hỏng thì tải lại từ URL ở trên. Thêm `--force` để luôn tải lại.

**Lưu ý khi dùng bản khác:** một số bản sao của dữ liệu này có khoảng trắng dư ở cuối item hoặc ghi nhãn một nhóm hàng
khác đi (`pot plants` thay vì `potted plants`, 170 giỏ). Nội dung vẫn là 9 835 giỏ và 169 item nhưng checksum sẽ khác,
và nhãn nằm trong kết quả luật nên cần thống nhất một bản duy nhất.
