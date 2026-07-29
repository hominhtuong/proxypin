---
description: Thêm một hoặc nhiều key l10n vào TẤT CẢ file .arb rồi sinh lại app_localizations
argument-hint: <key>=<chuỗi tiếng Anh> [<key2>=<chuỗi2> ...]
allowed-tools: Bash, Read, Edit, Grep, Glob
---

Thêm key localization mới vào ProxyPin. Key và chuỗi tiếng Anh: $ARGUMENTS

## Nguyên tắc

- `lib/l10n/app_en.arb` là template (khai báo ở `l10n.yaml`). Thêm vào đây trước.
- Sau đó thêm **cùng key** vào toàn bộ file còn lại, không được bỏ sót file nào:
  `app_zh.arb`, `app_zh_Hant.arb`, `app_vi.arb`, `app_es.arb`, `app_id.arb`, `app_pt.arb`, `app_pt_BR.arb`, `app_th.arb`
- Dịch cho đúng ngữ cảnh sản phẩm (app bắt gói mạng / proxy). Không để nguyên tiếng Anh ở file ngôn ngữ khác trừ khi đó là thuật ngữ kỹ thuật quốc tế (HAR, HTTP, proxy, WebSocket).
- Tiếng Việt phải có dấu đầy đủ.
- Tiếng Trung giản thể (`app_zh.arb`) và phồn thể (`app_zh_Hant.arb`) là hai bản khác nhau, dịch riêng.
- Chèn key vào **đúng vị trí ngữ nghĩa** trong file (gần các key cùng nhóm), đừng nhét bừa xuống cuối.
- Nếu chuỗi có placeholder kiểu `{count}` thì phải khai báo block `"@<key>": { "placeholders": {...} }` trong `app_en.arb`, tham khảo key `domainListSubtitle` làm mẫu.

## Sau khi sửa

```bash
flutter gen-l10n
flutter analyze
```

Commit cả file `.arb` lẫn file `lib/l10n/app_localizations_*.dart` được sinh ra.

## Báo cáo

Liệt kê từng key đã thêm kèm bản dịch của 9 ngôn ngữ dưới dạng bảng, để người dùng soát lại.
