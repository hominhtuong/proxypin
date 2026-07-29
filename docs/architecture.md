# Kiến trúc ProxyPin

Tài liệu này bổ sung cho [AGENTS.md](../AGENTS.md), tập trung vào bản đồ module và luồng dữ liệu để người mới (hoặc agent) định vị nhanh.

## Tổng quan

ProxyPin là app Flutter chạy proxy HTTP(S) **trong cùng process với UI**. Không có server riêng, không có IPC giữa proxy và UI (trừ chế độ multi-window trên desktop).

```
main.dart
  ├─ desktop shell (lib/ui/desktop/desktop.dart)
  └─ mobile shell  (lib/ui/mobile/mobile.dart)
        └─ đăng ký làm EventListener của ProxyServer
                 ▲
        ProxyServer (lib/network/bin/server.dart)
                 ├─ Server / Network  (lib/network/channel/network.dart)   socket + TLS MITM
                 ├─ HttpProxyChannelHandler (lib/network/handle/...)       routing HTTP
                 └─ chuỗi Interceptor (lib/network/components/...)          hosts, rewrite, map, script, block, breakpoint
```

## Các tầng

### 1. Tầng mạng - `lib/network/`

| Thư mục | Vai trò |
|---|---|
| `bin/` | Vòng đời proxy (`server.dart`), config proxy (`configuration.dart`), event listener |
| `channel/` | Socket, TLS handshake, MITM, `HostAndPort`, `ChannelContext` |
| `handle/` | Handler định tuyến request/response |
| `http/` | Parse HTTP/1.1, HTTP/2 (kèm HPACK), model `HttpRequest`/`HttpResponse` |
| `components/` | Interceptor: host filter, request map, rewrite, JS script, block, breakpoint |
| `components/manager/` | Đọc/ghi các file cấu hình JSON của từng component |
| `socks/` | SOCKS proxy |
| `util/cert/` | Sinh và quản lý CA certificate |

### 2. Tầng lưu trữ - `lib/storage/`

- `histories.dart` - lịch sử phiên bắt gói, ghi định kỳ bởi `HistoryTask`, format HAR-like.
- `favorites.dart` - request đã ghim. Cố ý cắt bớt số frame WebSocket/SSE và giới hạn kích thước payload trước khi ghi.

### 3. Tầng UI - `lib/ui/`

| Thư mục | Vai trò |
|---|---|
| `desktop/` | Shell desktop: toolbar, panel trái (danh sách), panel phải (chi tiết), multi-window |
| `mobile/` | Shell mobile: tab bar, bottom navigation, trang chi tiết dạng push |
| `component/` | Widget dùng chung cho cả hai nền tảng |
| `content/` | Render nội dung request/response (JSON, HTML, ảnh, ...) |
| `toolbox/` | Công cụ phụ: encode/decode, QR, timestamp, ... |
| `configuration.dart` | Preference của UI, ghi ra `ui_config.json` |

## Hai file cấu hình, đừng nhầm

| File | Lớp | Nội dung |
|---|---|---|
| `config.cnf` | `lib/network/bin/configuration.dart` | Cổng proxy, bật/tắt HTTPS, host filter, cấu hình liên quan tới hành vi bắt gói |
| `ui_config.json` | `lib/ui/configuration.dart` (`AppConfiguration`) | Theme, ngôn ngữ, kích thước cửa sổ, tỉ lệ panel, chế độ hiển thị danh sách |

Vị trí file: desktop nằm ở `~/.proxypin/`, mobile nằm trong application support directory.

Khi thêm preference mới cho UI thì phải sửa **ba** chỗ trong `AppConfiguration`: khai báo field, đọc trong `initConfig()`, ghi trong `toJson()`. Thiếu một chỗ là setting không lưu được.

## Tích hợp native

- **iOS**: method channel `com.proxypin/method` - xin quyền local network, kiểm tra trạng thái tin cậy CA (`lib/native/native_method.dart` <-> `ios/Runner/Handlers/MethodHandler.swift`).
- **Android**: plugin đăng ký trong `MainActivity.kt` - VPN service, picture-in-picture, lifecycle, danh sách app đã cài, thông tin process.
- **Desktop**: `desktop_multi_window`. Một số manager phải hỏi window 0 qua IPC để lấy application support path.

## Đa ngôn ngữ

`l10n.yaml` chỉ định `app_en.arb` làm template. File `lib/l10n/app_localizations*.dart` được sinh ra bởi `flutter gen-l10n` và **được commit vào repo**. Sửa `.arb` xong nhớ chạy lại lệnh sinh code.

Ngôn ngữ hỗ trợ: `en`, `zh`, `zh_Hant`, `vi`, `es`, `id`, `pt`, `pt_BR`, `th`.

## Điểm mở rộng

Muốn can thiệp traffic thì viết `Interceptor` mới thay vì nhét điều kiện vào handler:

```dart
abstract class Interceptor {
  int get priority;
  Future<HttpRequest?> preConnect(...);
  Future<HttpRequest?> onRequest(...);
  Future<HttpResponse?> execute(...);   // trả về response => cắt luôn, không gọi remote
  Future<HttpResponse?> onResponse(...);
  Future<void> onError(...);
}
```

Interceptor được sắp xếp theo `priority` trước khi đăng ký trong `ProxyServer`. Đổi thứ tự là đổi hành vi, cẩn thận.
