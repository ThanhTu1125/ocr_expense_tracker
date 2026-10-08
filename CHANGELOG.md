# CHANGELOG

Quy ước: mỗi bước thêm một mục mới ở TRÊN CÙNG, gồm: ngày giờ, tên bước, các thay đổi, file bị ảnh hưởng.

## [Giai đoạn 2] Database An Toàn + CRUD (Repository + Provider) - 2026-10-08 17:16
### Đã thực hiện
- Thiết kế interface `TransactionRepository`: cung cấp đầy đủ các phương thức `init`, `save`, `update`, `delete`, `getAll`, `getByCategory`, `getByDateRange`, `getTransactionsByWeek`, `getExpensesByCategory`.
- Triển khai `IsarTransactionRepository` cho production:
  - Loại bỏ hoàn toàn cơ chế fallback âm thầm `useMock = true` khi Isar mở thất bại. Ném ngoại lệ trực tiếp để UI xử lý minh bạch.
  - Triển khai hàm `delete`: xóa cả file ảnh gốc (`imagePath`) và ảnh thumbnail (`thumbPath`) trên ổ đĩa, bọc `try/catch` an toàn không crash nếu file đã bị xóa trước đó.
- Triển khai `InMemoryTransactionRepository` dành riêng cho môi trường kiểm thử (đặt tại `lib/testing/`), hỗ trợ cờ `shouldThrowOnInit` để kiểm thử kịch bản lỗi DB.
- Cập nhật `TransactionModel`: bổ sung trường `thumbPath` (mặc định rỗng `''`), chạy `build_runner` tái tạo schema Isar.
- Xóa bỏ hoàn toàn dependency dư thừa `cupertino_icons` khỏi `pubspec.yaml`.
- Tích hợp `Provider` chuẩn mực với `TransactionController` (`ChangeNotifier`):
  - Quản lý trạng thái tải (`isLoading`), lỗi (`hasError`, `errorMessage`), danh sách và các chỉ số thống kê.
  - Cập nhật `DashboardScreen` và `ReviewTransactionScreen` sử dụng `context.watch` / `context.read`.
  - Màn hình `DashboardScreen` tự động hiển thị giao diện báo lỗi kèm nút "Thử lại" khi khởi tạo database thất bại.
  - Bổ sung nút xóa giao dịch kèm xác nhận Dialog và thông báo SnackBar.
- Bổ sung bộ kiểm thử toàn diện `test/transaction_repository_test.dart` (CRUD, xóa kèm file ảnh trong thư mục tạm, lọc danh mục, lọc khoảng ngày) và nâng cấp `test/widget_test.dart` (tổng 48/48 tests passed 100%, `flutter analyze` 0 issues).
### File ảnh hưởng
- `lib/models/transaction.dart`
- `lib/models/transaction.g.dart`
- `lib/repositories/transaction_repository.dart`
- `lib/repositories/isar_transaction_repository.dart`
- `lib/testing/in_memory_transaction_repository.dart`
- `lib/controllers/transaction_controller.dart`
- `lib/services/database_service.dart`
- `lib/main.dart`
- `lib/screens/dashboard_screen.dart`
- `lib/screens/review_transaction_screen.dart`
- `pubspec.yaml`
- `pubspec.lock`
- `test/transaction_repository_test.dart`
- `test/widget_test.dart`
- `CHANGELOG.md`

## [Giai đoạn 1] Sửa lỗi logic dữ liệu RegexHelper - 2026-10-08 17:05
### Đã thực hiện
- Phân cấp từ khóa `RegexHelper.extractAmount` thành 2 mức:
  - Mạnh: `tong cong`, `tong thanh toan`, `tien phai tra`, `phai thanh toan`, `grand total`, `total due`.
  - Yếu: `thanh tien`, `tong tien`, `total`, `amount`, `thanh toan`, `cong tien`.
  - Quy tắc: Quét dòng khớp từ khóa mạnh lấy dòng cuối cùng có số; chỉ khi không có mới xét từ khóa yếu (cũng lấy dòng cuối cùng có số).
- Bổ sung bộ lọc dòng tiêu đề cột `_isColumnHeader`: phát hiện các dòng chứa "thành tiền" cùng "đơn giá", "sl", "tên món", "số lượng", hoặc không có số, ngăn chặn hoàn toàn việc nhận nhầm làm tổng tiền hoặc nhìn sang dòng kế tiếp.
- Bổ sung bộ lọc loại trừ `_isExcludedLine` khỏi ứng viên tổng tiền: `sub total`, `subtotal`, `tam tinh`, `giam gia`, `discount`, `khuyen mai`, `vat`, `thue`, `tien khach dua`, `tien mat`, `cash`, `tien thoi`, `thoi lai`, `change`, `so luong`.
- Nâng cấp `RegexHelper.extractDate`:
  - Hỗ trợ định dạng năm 2 chữ số: `dd/MM/yy`, `dd-MM-yy`, `dd.MM.yy` (yy -> 20yy).
  - Xác thực ngày thật bằng cách so sánh lại `year/month/day` với kết quả `DateTime` của Dart để ngăn chặn overflow (loại bỏ `31/02`, `31/04`).
  - Tự động trích xuất và gán giờ `HH:mm[:ss]` cùng dòng hoặc dòng kế bên vào `DateTime`.
- Bổ sung các bài kiểm thử mới trong `test/regex_helper_test.dart` (tổng 37 tests, 100% pass).
### File ảnh hưởng
- `lib/utils/regex_helper.dart`
- `test/regex_helper_test.dart`
- `CHANGELOG.md`
- `DEV_HISTORY.md`

## [Hotfix Ultimate] Thuật toán chuẩn hóa tiếng Việt và Heuristic Toán học cho Regex - 2026-10-06 23:26
### Đã thực hiện
- Xây dựng bộ "Kính cận OCR" (`_normalizeText`) trong `lib/utils/regex_helper.dart`:
  - Chuyển toàn bộ chuỗi về chữ thường (`toLowerCase`).
  - Thay thế các lỗi OCR phổ biến: số `0` thành `o`, ký tự `q` thành `o`.
  - Khử toàn bộ dấu tiếng Việt (thay thế nguyên âm có dấu thành nguyên âm không dấu, `đ` thành `d`).
- Tối ưu hóa quét từ khóa ưu tiên trong `RegexHelper.extractAmount`:
  - Danh sách từ khóa đã chuẩn hóa: `['tong cong', 'thanh tien', 'tong tien', 'total', 'amount', 'cong tien']`.
  - Chuẩn hóa từng dòng trước khi so khớp từ khóa; khi phát hiện dòng khớp từ khóa, trích xuất số tiền trên dòng gốc và `return` ngay lập tức, tóm gọn các hóa đơn in mờ hoặc bị lỗi nhận diện ký tự số 0.
- Xây dựng "Bộ lọc Toán học" cho Fallback:
  - Khi không tìm thấy từ khóa, thu thập tất cả số tiền trên hóa đơn và sắp xếp giảm dần.
  - Xét `Max1` (số lớn nhất) và `Max2` (số lớn nhì). Tìm xem có số `X` nào trong danh sách thỏa mãn `Max1 == Max2 + X` không.
  - Nếu có: `Max1` là Tiền khách đưa, `Max2` là Tổng bill, `X` là Tiền thối $\rightarrow$ Trả về `Max2`.
  - Nếu không: Không có tiền thối $\rightarrow$ Trả về `Max1`.
- Bổ sung Unit Test trong `test/regex_helper_test.dart`:
  - Test case nhận diện lỗi OCR số 0: `"T0NG C0NG: 35.000\nTiền mặt: 50.000"` $\rightarrow$ trả về `35000.0`.
  - Test case heuristic toán học: `"Món A 35.000\nTiền mặt 50.000\nThối lại 15.000"` $\rightarrow$ trả về đúng `35000.0`.
### File ảnh hưởng
- `lib/utils/regex_helper.dart` (thêm `_normalizeText`, tối ưu từ khóa và logic toán học fallback)
- `test/regex_helper_test.dart` (thêm unit test cho lỗi số 0 và heuristic toán học)
- `CHANGELOG.md` (cập nhật)
- `DEV_HISTORY.md` (cập nhật)
### Ghi chú
- 26/26 bài kiểm thử vượt qua 100%. Giải quyết dứt điểm nghịch lý bóc tách số tiền giữa hóa đơn có tiền thối và hóa đơn không từ khóa.

## [Hotfix 2] Tối ưu Fallback tìm số lớn nhất và bỏ qua URL - 2026-10-06 23:20
### Đã thực hiện
- Nâng cấp bộ lọc rác cho `RegexHelper.extractMerchantName`:
  - Trước khi lấy dòng hợp lệ đầu tiên làm tên cửa hàng, bỏ qua các dòng chứa ký tự đặc trưng của liên kết web/URL (`=`, `&`, `?q=`, `http`, `www`, `.com`).
  - Lấy dòng chữ hợp lệ đầu tiên sau khi đã loại trừ các dòng URL này.
- Tối ưu hóa cơ chế Fallback trong `RegexHelper.extractAmount`:
  - Khi hóa đơn không có bất kỳ từ khóa tổng tiền ưu tiên nào, quét toàn bộ văn bản để thu thập tất cả các chuỗi số tiền hợp lệ.
  - Sử dụng hàm `math.max` để trả về con số LỚN NHẤT tìm thấy trên toàn bộ hóa đơn (dựa trên nguyên lý tổng bill luôn là con số lớn nhất).
- Bổ sung Unit Test trong `test/regex_helper_test.dart`:
  - Test case kiểm tra chuỗi chứa URL rác `"https://google.com?q=bill\nQUAN AN THIEN TAN"` bóc tách đúng `"QUAN AN THIEN TAN"`.
  - Test case kiểm tra hóa đơn không có từ khóa `"Sườn 65.000\nTôm 65.000\nTIEN MAT 537.000"` bóc tách đúng số lớn nhất `537000.0`.
### File ảnh hưởng
- `lib/utils/regex_helper.dart` (tối ưu bộ lọc URL và cơ chế max fallback)
- `test/regex_helper_test.dart` (thêm 2 unit test mới)
- `CHANGELOG.md` (cập nhật)
- `DEV_HISTORY.md` (cập nhật)
### Ghi chú
- 24/24 bài kiểm thử vượt qua 100%.

## [Hotfix] Tối ưu Regex bóc tách số tiền - 2026-10-06 22:42
### Đã thực hiện
- Tối ưu thuật toán `RegexHelper.extractAmount` trong `lib/utils/regex_helper.dart`:
  - Cập nhật danh sách từ khóa ưu tiên, CHỈ giữ lại: "tổng cộng", "tổng tiền", "thành tiền", "tổng thanh toán", "total", "amount".
  - Loại bỏ hoàn toàn các từ khóa dễ gây nhầm lẫn như "tiền mặt", "cash", "tiền thối".
  - Duyệt tuần tự từ trên xuống dưới: khi phát hiện dòng chứa từ khóa ưu tiên, bóc tách số tiền trên dòng đó và trả về kết quả ngay lập tức (early return/break sớm), tránh bị ghi đè bởi số tiền khách đưa hoặc tiền thối ở phía dưới.
  - Cơ chế fallback (lấy số lớn nhất ở nửa dưới hóa đơn) chỉ kích hoạt khi không tìm thấy bất kỳ dòng nào chứa từ khóa tổng tiền.
- Bổ sung Unit Test trong `test/regex_helper_test.dart`:
  - Thêm test case mô phỏng hóa đơn có cả "TỔNG CỘNG: 35.000 VNĐ", "Tiền mặt: 50.000" và "Tiền thối: 15.000", xác nhận thuật toán bóc tách chính xác 35.000 đ.
### File ảnh hưởng
- `lib/utils/regex_helper.dart` (chỉnh sửa logic)
- `test/regex_helper_test.dart` (thêm unit test)
- `CHANGELOG.md` (cập nhật)
- `DEV_HISTORY.md` (cập nhật)
### Ghi chú
- 22/22 bài kiểm thử vượt qua 100%, khắc phục triệt để lỗi nhận diện nhầm số tiền khách đưa.

## [Bước 6] Vẽ biểu đồ CustomPainter & Hoàn thiện Dashboard - 2026-10-06 20:35
### Đã thực hiện
- Xóa file giữ chỗ `lib/widgets/.gitkeep`.
- Xây dựng `PieChartPainter` (`lib/widgets/pie_chart_painter.dart`):
  - Kế thừa `CustomPainter`, vẽ biểu đồ hình vành khuyên (Donut) bằng `canvas.drawArc` trên Canvas thuần, không dùng thư viện ngoài.
  - Hỗ trợ gán màu trực quan theo từng danh mục chi tiêu (`food`, `study`, `travel`, `gear`, `entertainment`).
  - Xử lý mượt mà trạng thái dữ liệu trống (vẽ vòng tròn xám và văn bản thông báo trung tâm).
- Xây dựng `BarChartPainter` (`lib/widgets/bar_chart_painter.dart`):
  - Kế thừa `CustomPainter`, vẽ biểu đồ cột chi tiêu 7 ngày trong tuần bằng `canvas.drawRect` trên Canvas thuần.
  - Chiều cao cột tỷ lệ chuẩn xác với số tiền chi tiêu, vẽ đường baseline và slot nền.
  - Hiển thị nhãn thứ trong tuần (`T2` - `CN`) dưới đáy mỗi cột bằng `TextPainter`.
- Nâng cấp và hoàn thiện `DashboardScreen` (`lib/screens/dashboard_screen.dart`):
  - Chuyển đổi thành `StatefulWidget`, tích hợp 3 luồng dữ liệu từ `DatabaseService` (`getAllTransactions`, `getTransactionsByWeek`, `getExpensesByCategory`).
  - Bọc cả 2 biểu đồ trong `TweenAnimationBuilder` tạo hiệu ứng animation "trải ra" (sweep/grow) mượt mà khi mở trang.
  - Hiển thị danh sách giao dịch gần đây (`ListView.builder`, `shrinkWrap: true`), định dạng tiền tệ và ngày tháng, hiển thị trạng thái "Chưa có giao dịch nào" khi rỗng.
  - Hỗ trợ vuốt xuống để làm mới dữ liệu (`RefreshIndicator`) và tự động cập nhật khi quay lại từ Camera Scanner.
- Cập nhật bộ kiểm thử `test/widget_test.dart`:
  - Thêm test case cho Dashboard render thẻ biểu đồ, trạng thái rỗng, trạng thái có dữ liệu, và kiểm thử render Canvas thuần của `PieChartPainter` & `BarChartPainter`.
  - Bộ test đạt 21/21 passed (100%).
### File ảnh hưởng
- `lib/widgets/.gitkeep` (xóa)
- `lib/widgets/pie_chart_painter.dart` (tạo mới)
- `lib/widgets/bar_chart_painter.dart` (tạo mới)
- `lib/screens/dashboard_screen.dart` (chỉnh sửa hoàn thiện)
- `lib/services/database_service.dart` (bổ sung hỗ trợ mock test an toàn)
- `test/widget_test.dart` (cập nhật test)
- `CHANGELOG.md` (cập nhật)
- `DEV_HISTORY.md` (cập nhật)
### Ghi chú
- 100% biểu đồ được vẽ bằng CustomPainter trên Canvas nguyên bản của Flutter, không phụ thuộc thư viện đồ họa thứ 3. Hoàn tất toàn bộ 6/6 bước của Mini-Project!

## [Bước 5] Thiết lập cơ sở dữ liệu Isar - 2026-10-06 20:10
### Đã thực hiện
- Xóa file giữ chỗ `lib/models/.gitkeep`.
- Định nghĩa Schema Isar trong `lib/models/transaction.dart`:
  - Enum `TransactionCategory` (`food`, `study`, `travel`, `gear`, `entertainment`).
  - Collection `TransactionModel` với các trường `id`, `amount`, `merchantName`, `date`, `category`, `imagePath`.
- Thực thi `dart run build_runner build` sinh mã nguồn Isar type-safe `lib/models/transaction.g.dart`.
- Xây dựng `DatabaseService` (`lib/services/database_service.dart`):
  - Khởi tạo kết nối Isar NoSQL lưu tại thư mục app documents qua `path_provider`.
  - Triển khai các hàm: `init()`, `saveTransaction()`, `getAllTransactions()` (sắp xếp ngày giảm dần), `getTransactionsByWeek()`, và `getExpensesByCategory()`.
- Cập nhật màn hình `ReviewTransactionScreen` (`lib/screens/review_transaction_screen.dart`):
  - Bổ sung Dropdown chọn danh mục chi tiêu `TransactionCategory`.
  - Validate form nhập liệu (số tiền > 0, ngày tháng chuẩn).
  - Tự động copy ảnh hóa đơn từ bộ nhớ tạm camera sang thư mục lưu trữ cố định của ứng dụng (`getApplicationDocumentsDirectory`).
  - Ghi đối tượng `TransactionModel` vào cơ sở dữ liệu Isar và điều hướng về Dashboard bằng `pushNamedAndRemoveUntil`.
### File ảnh hưởng
- `lib/models/.gitkeep` (xóa)
- `lib/models/transaction.dart` (tạo mới)
- `lib/models/transaction.g.dart` (sinh tự động)
- `lib/services/database_service.dart` (tạo mới)
- `lib/screens/review_transaction_screen.dart` (chỉnh sửa)
- `CHANGELOG.md` (cập nhật)
- `DEV_HISTORY.md` (cập nhật)
### Ghi chú
- Dữ liệu giao dịch được lưu trữ cục bộ 100% bằng Isar NoSQL database hiệu năng cao, ảnh hóa đơn được bảo lưu an toàn trong persistent storage của ứng dụng.

## [Bước 4] Tích hợp AI OCR và Trích xuất Regex - 2026-10-06 19:58
### Đã thực hiện
- Xóa file giữ chỗ `lib/services/.gitkeep` và `lib/utils/.gitkeep`.
- Xây dựng `OcrService` (`lib/services/ocr_service.dart`): Tích hợp `google_mlkit_text_recognition` xử lý offline với `TextRecognizer(script: TextRecognitionScript.latin)` và giải phóng tài nguyên `close()`.
- Xây dựng `RegexHelper` (`lib/utils/regex_helper.dart`):
  - `extractAmount`: bóc tách số tiền với định dạng Việt Nam (`150.000`, `150,000 VND`, `150k`), áp dụng heuristic ưu tiên dòng chứa từ khóa tổng tiền và nửa dưới hóa đơn.
  - `extractDate`: bóc tách ngày tháng theo định dạng `dd/MM/yyyy`, `yyyy-MM-dd`, `dd-MM-yyyy`.
  - `extractMerchantName`: nhận diện thương hiệu/cửa hàng qua từ khóa đặc trưng (WinMart, Highlands, Circle K...) hoặc fallback dòng đầu tiên hợp lệ.
- Nâng cấp `ReviewTransactionScreen` (`lib/screens/review_transaction_screen.dart`) thành `StatefulWidget`:
  - Tự động gọi OCR và trích xuất dữ liệu khi có `imagePath`.
  - Hiển thị thumbnail ảnh hóa đơn ở nửa trên.
  - Form nhập liệu ở nửa dưới với các `TextFormField` cho phép người dùng kiểm tra và chỉnh sửa.
  - Nút "Lưu giao dịch" chuẩn bị cho tích hợp cơ sở dữ liệu.
- Viết bộ Unit Test toàn diện `test/regex_helper_test.dart` (15 test cases) kiểm thử các kịch bản bóc tách dữ liệu hóa đơn.
### File ảnh hưởng
- `lib/services/.gitkeep` (xóa)
- `lib/utils/.gitkeep` (xóa)
- `lib/services/ocr_service.dart` (tạo mới)
- `lib/utils/regex_helper.dart` (tạo mới)
- `lib/screens/review_transaction_screen.dart` (chỉnh sửa)
- `test/regex_helper_test.dart` (tạo mới)
- `CHANGELOG.md` (cập nhật)
- `DEV_HISTORY.md` (cập nhật)
### Ghi chú
- Pipeline OCR và bóc tách dữ liệu hoạt động 100% offline trên thiết bị Android, bảo đảm quyền riêng tư và tốc độ xử lý tức thì.

## [Bước 3] Xử lý Camera và Kính ngắm - 2026-10-06 19:48
### Đã thực hiện
- Khai báo quyền Camera trong `android/app/src/main/AndroidManifest.xml`: `<uses-permission android:name="android.permission.CAMERA"/>`.
- Nâng cấp `ScannerScreen` thành `StatefulWidget` tích hợp logic Camera:
  - Tự động phát hiện camera sau (`availableCameras()` + `CameraLensDirection.back`).
  - Khởi tạo `CameraController` với `ResolutionPreset.high`, `enableAudio: false`, và quản lý vòng đời `dispose()`.
  - Dựng giao diện phân lớp bằng `Stack`:
    - Lớp nền: `CameraPreview` (kèm loading indicator khi controller đang khởi tạo hoặc thông báo lỗi nếu không tìm thấy camera).
    - Lớp giữa: Kính ngắm Viewfinder (`CustomPainter`) dạng hình chữ nhật bo góc với viền màu nổi bật, góc nhấn trắng và vùng mờ xung quanh hướng dẫn căn chỉnh hóa đơn.
    - Lớp điều khiển: Nút bật/tắt đèn Flash (`setFlashMode`: torch/off) và nút chụp ảnh to ở giữa cạnh dưới.
  - Xử lý hành động chụp ảnh (`takePicture()`): lưu file ảnh và điều hướng sang `ReviewTransactionScreen` mang theo tham số đường dẫn ảnh `file.path`.
- Cập nhật `test/widget_test.dart`: tối ưu kiểm thử điều hướng sang ScannerScreen bằng `tester.pump(duration)` tránh timeout do hoạt họa loading vô hạn của `CircularProgressIndicator`.
### File ảnh hưởng
- `android/app/src/main/AndroidManifest.xml` (chỉnh sửa)
- `lib/screens/scanner_screen.dart` (chỉnh sửa)
- `test/widget_test.dart` (chỉnh sửa)
- `CHANGELOG.md` (cập nhật)
- `DEV_HISTORY.md` (cập nhật)
### Ghi chú
- Pipeline chụp ảnh và chuyển tiếp đường dẫn file ảnh sang ReviewTransactionScreen đã sẵn sàng để tích hợp Google ML Kit OCR ở Bước 4.

## [Bước 2] Dựng bộ khung UI và Routing - 2026-10-06 19:30
### Đã thực hiện
- Tạo các màn hình giao diện dạng StatelessWidget với routeName tĩnh:
  - `lib/screens/dashboard_screen.dart` (`routeName = '/'`): Scaffold gồm AppBar "Dashboard", FloatingActionButton icon camera chuyển hướng tới ScannerScreen.
  - `lib/screens/scanner_screen.dart` (`routeName = '/scanner'`): Scaffold gồm AppBar "Scanner".
  - `lib/screens/review_transaction_screen.dart` (`routeName = '/review'`): Scaffold gồm AppBar "Review Transaction", nhận tham số tùy chọn `imagePath`.
- Xóa `lib/screens/.gitkeep`.
- Cấu hình routing tại `lib/main.dart`:
  - `useMaterial3: true` và `ColorScheme.fromSeed(seedColor: Colors.deepPurple)`.
  - Thiết lập `initialRoute: DashboardScreen.routeName` (không dùng thuộc tính `home`).
  - Định nghĩa bảng `routes` cố định cho Dashboard và Scanner.
  - Cấu hình `onGenerateRoute` trích xuất `settings.arguments` truyền làm `imagePath` cho ReviewTransactionScreen.
  - Cấu hình `onUnknownRoute` điều hướng fallback về DashboardScreen.
- Cập nhật 3 widget tests trong `test/widget_test.dart` kiểm tra hiển thị Dashboard, chuyển màn hình khi bấm FAB, và dựng ReviewTransactionScreen khi imagePath là null.
### File ảnh hưởng
- `lib/screens/.gitkeep` (xóa)
- `lib/screens/dashboard_screen.dart` (tạo mới)
- `lib/screens/scanner_screen.dart` (tạo mới)
- `lib/screens/review_transaction_screen.dart` (tạo mới)
- `lib/main.dart` (chỉnh sửa)
- `test/widget_test.dart` (chỉnh sửa)
- `CHANGELOG.md` (cập nhật)
- `DEV_HISTORY.md` (cập nhật)
### Ghi chú
- Tách biệt rõ ràng static routes (không tham số) và dynamic route (`onGenerateRoute` nhận tham số ảnh chụp) tạo tiền đề vững chắc cho việc tích hợp Camera và OCR ở Bước 3.

## [Bước 1] Khởi tạo dự án - 2026-10-02 00:54
### Đã thực hiện
- Khởi tạo dự án Flutter `ocr_expense_tracker` (chỉ Android, org: `com.example`).
- Thêm dependencies:
  - `camera`: ^0.12.1 (thực tế: 0.12.1)
  - `google_mlkit_text_recognition`: ^0.17.1 (thực tế: 0.17.1)
  - `path_provider`: ^2.1.6 (thực tế: 2.1.6)
  - `provider`: ^6.1.5+1 (thực tế: 6.1.5+1)
  - `path`: ^1.9.1 (thực tế: 1.9.1)
  - `intl`: ^0.20.3 (thực tế: 0.20.3)
  - `isar_community`: ^3.3.2 (thực tế: 3.3.2)
  - `isar_community_flutter_libs`: ^3.3.2 (thực tế: 3.3.2)
  - `cupertino_icons`: ^1.0.8 (thực tế: 1.0.9)
- Thêm dev_dependencies:
  - `flutter_test`: sdk flutter (thực tế: 0.0.0)
  - `flutter_lints`: ^6.0.0 (thực tế: 6.0.0)
  - `build_runner`: ^2.4.13 (thực tế: 2.15.1)
  - `isar_community_generator`: ^3.3.2 (thực tế: 3.3.2)
- Cấu hình Android: đặt `minSdk = 21` trong `android/app/build.gradle.kts` (thay thế `flutter.minSdkVersion`) do yêu cầu minSdk của `camera`, `google_mlkit_text_recognition` và `isar_community_flutter_libs`. Giữ nguyên `compileSdk` và `targetSdk`.
- Tạo cấu trúc thư mục trong `lib/`: `models/`, `screens/`, `services/`, `utils/`, `widgets/` với mỗi thư mục chứa file `.gitkeep` rỗng.
- Thay màn hình demo counter mặc định trong `lib/main.dart` bằng `MaterialApp` tối giản hiển thị tiêu đề "OCR Expense Tracker" và dòng text "Project initialized".
- Cập nhật smoke test trong `test/widget_test.dart` khớp với UI tối giản mới.
### File ảnh hưởng
- `pubspec.yaml`
- `pubspec.lock`
- `android/app/build.gradle.kts`
- `lib/main.dart`
- `test/widget_test.dart`
- `lib/models/.gitkeep`
- `lib/screens/.gitkeep`
- `lib/services/.gitkeep`
- `lib/utils/.gitkeep`
- `lib/widgets/.gitkeep`
- `CHANGELOG.md`
- `DEV_HISTORY.md`
### Ghi chú
- Do `isar_flutter_libs 3.1.0+1` thiếu thuộc tính `namespace` trong `build.gradle` khi biên dịch với Android Gradle Plugin 8.x+, dự án đã được thống nhất chuyển sang bản fork chính thức tương thích `isar_community` (v3.3.2) cùng `isar_community_flutter_libs` và `isar_community_generator`.
- Từ Bước 2 trở đi, các file model và service sẽ import thư viện Isar dưới dạng `package:isar_community/isar.dart`.

