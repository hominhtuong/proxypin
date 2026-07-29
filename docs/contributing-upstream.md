# Checklist gửi Pull Request lên upstream

Repo này là fork của [wanghongenpin/ProxyPin](https://github.com/wanghongenpin/proxypin). Mục tiêu của mọi thay đổi là được upstream merge, để cộng đồng dùng miễn phí. PR càng gọn và càng "giống phong cách nhà chủ" thì càng dễ merge.

## Remote

```bash
git remote -v
# origin    https://github.com/hominhtuong/proxypin.git
# upstream  https://github.com/wanghongenpin/proxypin.git
```

Chưa có upstream thì thêm:

```bash
git remote add upstream https://github.com/wanghongenpin/proxypin.git
git fetch upstream
```

## Nguyên tắc

1. **Một PR, một việc.** Đừng gộp refactor với tính năng mới.
2. **Không đổi hành vi mặc định.** Tính năng mới phải opt-in; người dùng cũ cập nhật lên không được thấy khác đi.
3. **Giữ parity desktop/mobile.** Thêm ở một bên thì phải giải thích vì sao bên kia không có.
4. **Không thêm dependency** nếu chưa thật cần. Upstream ngại tăng size binary.
5. **Không đổi style code.** Không format lại file bạn không sửa. Không dịch comment tiếng Trung có sẵn.
6. **Không đổi version** trong `pubspec.yaml` - đó là việc của maintainer.

## Trước khi push

```bash
flutter pub get
dart format --line-length 120 --set-exit-if-changed lib test
flutter analyze     # 0 error, 0 warning
flutter test
```

Nếu có sửa `.arb`:

```bash
flutter gen-l10n
```

Rồi commit cả file `.arb` lẫn `lib/l10n/app_localizations_*.dart`.

## Những thứ TUYỆT ĐỐI không được lọt vào PR

| Thứ | Lý do |
|---|---|
| `.vscode/` | Chứa đường dẫn SDK riêng của máy |
| `.claude/`, `CLAUDE.md`, `docs/` nội bộ | Là công cụ làm việc cá nhân, không phải sản phẩm |
| `pubspec.lock` | Đã nằm trong `.gitignore` của repo |
| `version:` trong `pubspec.yaml` | Maintainer tự bump |
| `build/`, `.dart_tool/`, `l10n_errors.txt` | Artifact |
| Đường dẫn tuyệt đối `/Volumes/...`, `/Users/...` | Lộ môi trường cá nhân |

Kiểm tra nhanh:

```bash
git diff upstream/main...HEAD --stat
```

## Commit message

Theo Conventional Commits, khớp lịch sử repo:

```
feat(request-tree): add tree view for captured domain list
fix(vpn): keep Android capture alive across network switch (issue #864)
```

## Mô tả PR

Viết bằng tiếng Anh, có `## What`, `## Why`, `## How`, `## Compatibility`, `## Testing`. Thay đổi UI thì bắt buộc có ảnh chụp trước/sau. Xem mẫu trong `.claude/commands/upstream-pr.md`.

## Rebase

Trước khi mở PR:

```bash
git fetch upstream
git rebase upstream/main
```

Conflict thì đọc kỹ, ưu tiên giữ code upstream và ghép thay đổi của mình lên trên - đừng ghi đè.
