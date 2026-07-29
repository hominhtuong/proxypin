---
description: Chạy thử ProxyPin trên thiết bị/nền tảng chỉ định để kiểm chứng thay đổi UI
argument-hint: [macos|android|ios|windows|linux]
allowed-tools: Bash, Read, Glob, Grep
---

Chạy app ProxyPin để kiểm chứng thay đổi. Nền tảng: $ARGUMENTS (mặc định `macos`).

## Trước khi chạy

```bash
flutter devices
```

Chọn device khớp với nền tảng được yêu cầu. Nếu không có device nào phù hợp thì báo người dùng, đừng đoán bừa.

## Chạy

```bash
flutter run -d <device-id>
```

Chú ý:
- Proxy core khởi động từ UI init, không phải daemon riêng - cứ mở app là proxy chạy.
- Trên macOS, lần đầu bật proxy sẽ hỏi quyền hệ thống và có thể cần cài CA cert.
- Trên Android, tính năng VPN cần thiết bị thật hoặc emulator có Google Play.
- Muốn tự sinh traffic để kiểm thử danh sách request thì bật proxy rồi mở trình duyệt trỏ vào `127.0.0.1:<port>` đang hiển thị trên toolbar.

## Sau khi chạy

Nếu là thay đổi UI, nhắc người dùng chụp ảnh màn hình trước/sau để đính vào PR.
Đừng để tiến trình `flutter run` chạy nền vô thời hạn - hỏi người dùng khi nào dừng.
