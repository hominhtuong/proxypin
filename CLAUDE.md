# CLAUDE.md

Hướng dẫn cho Claude Code khi làm việc trên repo này. Đọc kèm [AGENTS.md](AGENTS.md) - file đó mô tả kiến trúc, file này mô tả quy trình và quy ước làm việc.

## Bối cảnh repo

- Đây là **fork** của dự án mã nguồn mở [wanghongenpin/ProxyPin](https://github.com/wanghongenpin/proxypin).
- Remote `origin` = fork cá nhân (`hominhtuong/proxypin`), remote `upstream` = repo gốc.
- Mục tiêu: customize theo nhu cầu rồi gửi Pull Request ngược lên upstream để mọi người dùng miễn phí.
- Vì vậy **mọi thay đổi phải giữ được tinh thần upstream**: không đổi phong cách code, không đổi kiến trúc, không thêm dependency nếu chưa thật cần.

## Môi trường

- Flutter SDK: `/Volumes/M2/MTDocuments/Flutters/flutter` (đã có trong `PATH` qua `~/.zshrc`).
- Phiên bản đang dùng: Flutter 3.44.4 stable / Dart 3.12.2.
- `.vscode/` là config riêng của máy, đã đưa vào `.git/info/exclude` - **không commit**.

Lệnh hay dùng:

```bash
flutter pub get                  # cài dependency
flutter analyze                  # lint, phải sạch trước khi commit
flutter test                     # chạy toàn bộ test
flutter test test/<file>.dart    # chạy 1 file test
flutter run -d macos             # chạy thử trên desktop
flutter gen-l10n                 # sinh lại app_localizations_*.dart sau khi sửa .arb
```

## Quy ước code bắt buộc

### Style
- `analysis_options.yaml` đặt `line-length: 120`. Format bằng `dart format --line-length 120 <file>`.
- Comment trong code gốc viết bằng tiếng Trung (`///域名列表`). Khi sửa file cũ thì **giữ nguyên** comment cũ; code mới viết comment tiếng Anh cho dễ review ở upstream.
- Không xoá header license Apache 2.0 ở đầu file. File mới phải copy header đó.

### Kiến trúc cần tôn trọng
- Logic proxy dùng chung ở `lib/network/**`. UI riêng từng nền tảng ở `lib/ui/desktop/**` và `lib/ui/mobile/**`.
- **Giữ parity desktop/mobile**: thêm tính năng UI ở một bên thì phải cân nhắc bên còn lại, nếu không làm được thì ghi rõ lý do trong PR.
- Muốn can thiệp traffic thì viết `Interceptor` mới (`lib/network/components/interceptor.dart`), đừng nhét `if` vào sâu trong handler.
- Preference của UI lưu ở `lib/ui/configuration.dart` (`ui_config.json`), tách khỏi config proxy ở `lib/network/bin/configuration.dart` (`config.cnf`).

### Đa ngôn ngữ (l10n)
- Nguồn: `lib/l10n/app_*.arb`. `app_en.arb` là template (khai báo trong `l10n.yaml`).
- Thêm key mới thì phải thêm cho **tất cả** file `.arb`: `en, zh, zh_Hant, vi, es, id, pt, pt_BR, th`.
- Chạy `flutter gen-l10n` rồi commit cả file `app_localizations_*.dart` được sinh ra (repo này commit file generated).
- Không hardcode chuỗi hiển thị trong widget - luôn đi qua `localizations.<key>`.

## Quy trình làm việc

1. Nhánh feature tách từ tip của upstream, đặt tên `feat/<mô-tả>` hoặc `fix/issue-<số>-<mô-tả>`.
2. Sửa code => `flutter analyze` sạch => `flutter test` xanh.
3. Commit theo Conventional Commits, khớp lịch sử repo:
   - `feat(request-tree): add tree view for captured domain list`
   - `fix(vpn): keep Android capture alive across network switch (issue #864)`
4. Đẩy lên `origin`, mở PR vào `upstream/main`.
5. Mô tả PR viết bằng **tiếng Anh** (upstream dùng tiếng Anh/Trung), kèm ảnh chụp trước/sau nếu là thay đổi UI.

## Ranh giới - việc KHÔNG tự làm

- Không commit hoặc push khi chưa được yêu cầu.
- Không đưa `.vscode/`, `.claude/`, đường dẫn tuyệt đối của máy vào nhánh feature.
- Không sửa `pubspec.yaml` version / `pubspec.lock` trong PR tính năng.
- Không chỉnh file trong `android/`, `ios/`, `macos/`, `windows/`, `linux/` trừ khi task yêu cầu rõ.
- Không đụng `build/`, `.dart_tool/`, `l10n_errors.txt`.

## Tài liệu tham khảo

- [docs/architecture.md](docs/architecture.md) - bản đồ module và luồng dữ liệu.
- [docs/ui-request-list.md](docs/ui-request-list.md) - chi tiết UI danh sách request/domain, nơi tính năng tree view sống.
- [docs/contributing-upstream.md](docs/contributing-upstream.md) - checklist trước khi mở PR lên upstream.
- [docs/build-and-release.md](docs/build-and-release.md) - build từng nền tảng, ký + notarize macOS, và các bẫy đã gặp thật.
