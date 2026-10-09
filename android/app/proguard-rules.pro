# Proguard / R8 rules for ocr_expense_tracker

# Ứng dụng chỉ sử dụng bộ nhận diện Latin (đủ cho tiếng Việt), không bundle các bộ
# ngôn ngữ Trung/Nhật/Hàn/Devanagari nên bỏ qua cảnh báo thiếu class từ R8 để giảm kích thước APK.
-dontwarn com.google.mlkit.vision.text.chinese.ChineseTextRecognizerOptions
-dontwarn com.google.mlkit.vision.text.chinese.ChineseTextRecognizerOptions$Builder
-dontwarn com.google.mlkit.vision.text.devanagari.DevanagariTextRecognizerOptions
-dontwarn com.google.mlkit.vision.text.devanagari.DevanagariTextRecognizerOptions$Builder
-dontwarn com.google.mlkit.vision.text.japanese.JapaneseTextRecognizerOptions
-dontwarn com.google.mlkit.vision.text.japanese.JapaneseTextRecognizerOptions$Builder
-dontwarn com.google.mlkit.vision.text.korean.KoreanTextRecognizerOptions
-dontwarn com.google.mlkit.vision.text.korean.KoreanTextRecognizerOptions$Builder

# Giữ lại toàn bộ lớp và interface của Google ML Kit
-keep class com.google.mlkit.** { *; }
-keep interface com.google.mlkit.** { *; }

# Giữ lại các lớp nội bộ của Google Play Services / ML Kit
-keep class com.google.android.gms.internal.mlkit_** { *; }
-keep class com.google.android.gms.tasks.** { *; }
-keep class com.google.android.datatransport.** { *; }

# Giữ lại các plugin Flutter ML Kit
-keep class com.google_mlkit_commons.** { *; }
-keep class com.google_mlkit_text_recognition.** { *; }

# Giữ lại thuộc tính phục vụ reflection và annotation
-keepattributes *Annotation*,Signature,InnerClasses,EnclosingMethod
