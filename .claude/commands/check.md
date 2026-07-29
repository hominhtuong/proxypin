---
description: Chạy full gate chất lượng cho ProxyPin (format check, analyze, test) và tóm tắt kết quả
allowed-tools: Bash, Read, Grep, Glob, Edit
---

Chạy gate chất lượng cho repo ProxyPin theo đúng thứ tự dưới đây. Dừng lại và báo cáo ngay khi có bước fail, đừng cố "lách" cho qua.

## Bước 1 - Dependency

```bash
flutter pub get
```

## Bước 2 - Format

```bash
dart format --line-length 120 --set-exit-if-changed lib test
```

Nếu fail: chạy lại không có `--set-exit-if-changed` để format, rồi báo những file đã bị đổi.

## Bước 3 - Static analysis

```bash
flutter analyze
```

Yêu cầu: **0 error, 0 warning**. Info-level thì báo cáo nhưng không bắt buộc sửa nếu nó đã có sẵn từ trước khi mình đụng vào (so với `git stash` baseline nếu cần).

## Bước 4 - Test

```bash
flutter test
```

## Bước 5 - Kiểm tra l10n (chỉ khi có sửa file .arb)

```bash
flutter gen-l10n
git status --short lib/l10n
```

Nếu `flutter gen-l10n` sinh ra diff mà chưa được commit thì phải commit kèm.
Kiểm tra thêm: mọi key mới trong `app_en.arb` phải có mặt ở tất cả file `app_*.arb` còn lại.

## Bước 6 - Kiểm tra rác không được lọt vào commit

Xác nhận `git status` không hiện: `.vscode/`, `.claude/`, `build/`, `.dart_tool/`, `l10n_errors.txt`, `pubspec.lock`.

## Báo cáo

Trả về bảng gọn: bước / kết quả (PASS/FAIL) / ghi chú. Nếu tất cả PASS thì kết luận rõ ràng "sẵn sàng commit". Không tự động commit.
