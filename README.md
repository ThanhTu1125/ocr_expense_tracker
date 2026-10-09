# MINI-PROJECT SHORT TECHNICAL REPORT

**Course:** Cross-Platform Mobile App Development (VKU)\
**Mini-Project Title:** Mini-Project 3 — OCR Expense Tracker & Receipt Parser (Flutter & Dart)\
**Student Name:** Nguyễn Thanh Tú - 23IT296\
**Submission Date:** \[DD/MM/YYYY\]

## 1. GENERAL INFORMATION & DELIVERABLE LINKS

- **Team Members:**
  1. Nguyễn Thanh Tú - 23IT296 — Vai trò: Kiến trúc — Đóng góp: 100%
- **Live Demo / Release APK:** <https://github.com/ThanhTu1125/ocr_expense_tracker/releases/tag/v1.0.0>
- **GitHub Repository:** <https://github.com/ThanhTu1125/ocr_expense_tracker.git>
- **Video Demo:** <https://drive.google.com/drive/folders/1Y8mr4evGq1TNf-9_wHbBm2Hv0WBvUsJh?usp=drive_link>

## 2. FEATURE IMPLEMENTATION CHECKLIST

| # | Required Feature | Status | Implementation Details & Acceptance Level |
| :-: | --- | :-: | --- |
| 1 | Live camera viewfinder + flash toggle | ✅ Complete | `camera` plugin; flash on/off via `setFlashMode`; framing overlay drawn with CustomPainter. |
| 2 | Tap-to-focus | ✅ Complete | Tap on preview calls `setFocusPoint` / `setExposurePoint`; animated focus ring. |
| 3 | Framing crop | ✅ Complete | Captured image is cropped to the viewfinder rectangle (EXIF-aware, coordinate mapping unit-tested) in an isolate before OCR. |
| 4 | On-device OCR (offline) | ✅ Complete | `google_mlkit_text_recognition` (Latin model); no network or cloud cost. Measured latency: 412 ms avg (see §4). |
| 5 | Regex heuristic parser | ✅ Complete | Total (`150,000 VND`, `150.000 đ`, `42, 000`), date (`dd/MM/yyyy`, `dd.MM.yy`, optional time), merchant name; junk lines (phone, tax code, table no.) filtered. |
| 6 | Interactive review screen | ✅ Complete | All fields editable before saving; orange warning when date/amount cannot be read (no silent default). |
| 7 | Local database + categories | ✅ Complete | Isar; 5 categories (Food, Study, Travel, Gear, Entertainment); repository + Provider layer. |
| 8 | Receipt thumbnail caching | ✅ Complete | Compressed image + thumbnail saved in app documents directory; thumbnail shown in the transaction list. |
| 9 | Transaction lifecycle | ✅ Complete | Create, edit, delete (image files removed too), filter by category. |
| 10 | Animated donut chart (CustomPainter) | ✅ Complete | Drawn on canvas, no chart library; eased sweep animation. |
| 11 | Weekly bar chart (CustomPainter) | ✅ Complete | Drawn on canvas; per-day totals; animated bars. |
| 12 | Chart interaction | ✅ Complete | Tap to select slice/bar, tooltip, percentage and total in donut centre, previous/next week. |
| 13 | Release APK | ✅ Complete | `flutter build apk --release`, size \~86.8 MB. |

## 3. TECHNICAL ARCHITECTURE & PROJECT STRUCTURE

**Directory structure (lib/):** `models/` (Isar `Transaction`), `repositories/` (`TransactionRepository` interface + Isar implementation), `controllers/` (Provider `ChangeNotifier`), `services/` (camera, OCR, image processing), `utils/` (`RegexHelper`, row reconstruction), `screens/` (Dashboard, Scanner, Review), `widgets/` (`PieChartPainter`, `BarChartPainter`). Unit/widget tests live in `test/` with real OCR outputs stored as fixtures in `test/fixtures/`.

**Data flow:** Camera capture → crop to viewfinder (isolate) → ML Kit text recognition → text lines with bounding boxes → **row reconstruction** (lines on the same horizontal band are merged) → `RegexHelper` (amount, date, merchant) → Review screen (manual edit) → Repository → Isar. Charts read aggregated queries (by category, by week) from the repository.

**Amount detection strategy (priority order):** (1) strong keywords (`tổng cộng`, `tổng thanh toán`); (2) cash/payment row when no total row exists; (3) cross-check: a candidate equal to the sum of all other line items; (4) `Max1 = Max2 + X` heuristic; (5) largest amount. Lines for sub-total, discount, VAT, cash given and change are excluded; items such as table numbers or machine codes (`F1304`, `000887`) are never treated as money.

**Exception handling:** database initialisation failure shows an error screen with retry (no silent in-memory fallback, which would lose data); OCR failure falls back to manual entry; unreadable date or amount is flagged on the form; file operations are wrapped in try/catch; deleting a transaction removes its image and thumbnail.

**Quality assurance:** `flutter analyze` — 0 issues; `flutter test` — 84/84 tests passing (parser, date validation, coordinate mapping, repository CRUD, chart interaction, widget tests).

## 4. EMPIRICAL EVIDENCE & SCREENSHOTS

*Screenshots from a physical device (RMX3760), release build v1.0.0.*

<table>
<tr>
<td align="center"><img src="https://res.cloudinary.com/nyjpv8vu/image/upload/f_auto,q_auto/1791561455195_59583595443759783_1376730126841540975_860a7b1b0b8ca689aa396a85ca0a429d" alt="Dashboard overview before scan" width="200"></td>
<td align="center"><img src="https://res.cloudinary.com/nyjpv8vu/image/upload/v1791562596/1791561455348_59583595443759783_1376730126841540975_a08bbc058b2dea160a2ee4794bac3faf.jpg" alt="Review transaction with OCR results" width="200"></td>
<td align="center"><img src="https://res.cloudinary.com/nyjpv8vu/image/upload/f_auto,q_auto/1791561455502_59583595443759783_1376730126841540975_839e01751a4a81919b459126caa6ad7f" alt="Dashboard updated after transaction save" width="200"></td>
</tr>
<tr>
<td align="center"><b>Figure 1.</b> Dashboard overview: weekly expense bar chart, category donut chart, and transaction list before scanning</td>
<td align="center"><b>Figure 2.</b> Review Transaction: scanned receipt preview with auto-extracted merchant, total amount (250,000 VND), date, and category</td>
<td align="center"><b>Figure 3.</b> Real-time update: success banner, total expense updated to 1,359,000 VND, and updated charts</td>
</tr>
</table>

**OCR performance (physical device, release build, 9 scans after warm-up):**

| Metric | Result |
|---|---|
| Average / min / max OCR time | 412 / 295 / 580 ms |
| Release APK size | ~87.0 MB |

**Parsing check:** totals were extracted correctly on supermarket receipts (e.g. Siêu Thị MiniMart An Bình 250,000 VND in Figure 2, and 35,000 VND) and a restaurant bill with an item-price column (180,000 VND); an old, faded 2011 thermal receipt could not be read reliably (see Known limitations).
## 5. TECHNICAL CHALLENGES & RESOLUTIONS

**Challenge 1 — Release build crashes and OCR fails (R8).** `flutter run --release` failed with R8 "missing classes" because the ML Kit plugin references Chinese, Japanese, Korean and Devanagari recognizers that are not bundled (the app only needs the Latin model). **Resolution:** added `-dontwarn` rules for those classes and keep rules for ML Kit in `proguard-rules.pro`, wired through `proguardFiles` in `build.gradle.kts`; verified OCR and persistence on the release build.

**Challenge 2 — Wrong totals caused by column-wise OCR and misleading keywords.** ML Kit often returns item names and prices as separate blocks, so a label such as `TIỀN MẶT` ended up far from its amount, and the column header `Thành tiền` made the parser return the first item's price. **Resolution:** reconstruct rows from bounding boxes, normalise numbers such as `42, 000`, prioritise strong keywords, exclude sub-total/discount/VAT/change lines, and cross-check candidates against the sum of line items. Regression tests use real OCR text as fixtures.

**Known limitations:** very old or faded thermal receipts (e.g. the 2011 Thiên Tân bill) can yield misread characters (`16, b00`) and fail to give a reliable total; the user corrects it on the review screen. The app targets Android only.
