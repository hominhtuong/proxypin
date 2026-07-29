---
description: Chuẩn bị và mở Pull Request lên repo gốc (upstream) ProxyPin
argument-hint: [mô tả ngắn tính năng]
allowed-tools: Bash, Read, Grep, Glob, Edit, Write
---

Chuẩn bị PR gửi lên upstream `wanghongenpin/proxypin`. Tính năng: $ARGUMENTS

## Bước 1 - Kiểm tra remote

```bash
git remote -v
```

Phải có `origin` (fork `hominhtuong/proxypin`) và `upstream` (`wanghongenpin/proxypin`). Thiếu `upstream` thì thêm:

```bash
git remote add upstream https://github.com/wanghongenpin/proxypin.git
git fetch upstream
```

## Bước 2 - Soát diff xem có gì không nên gửi

```bash
git diff upstream/main...HEAD --stat
```

**Chặn lại và hỏi người dùng** nếu diff chứa bất kỳ thứ nào sau đây:
- `.vscode/`, `.claude/`, `CLAUDE.md`, `docs/` nội bộ
- `pubspec.lock`, thay đổi `version:` trong `pubspec.yaml`
- Đường dẫn tuyệt đối của máy (`/Volumes/`, `/Users/`)
- File build: `build/`, `.dart_tool/`, `l10n_errors.txt`
- Thay đổi ngoài phạm vi tính năng đang làm

## Bước 3 - Gate chất lượng

Chạy `/check`. Không PASS thì dừng, không mở PR.

## Bước 4 - Rebase lên upstream mới nhất

```bash
git fetch upstream
git rebase upstream/main
```

Có conflict thì báo người dùng, đừng tự ý resolve theo hướng vứt code của upstream.

## Bước 5 - Push và mở PR

```bash
git push -u origin <branch>
gh pr create --repo wanghongenpin/proxypin --base main --head hominhtuong:<branch> --title "<title>" --body "<body>"
```

## Quy cách nội dung PR

Viết bằng **tiếng Anh**. Cấu trúc:

```markdown
## What
Một đoạn ngắn nói tính năng làm gì, dưới góc nhìn người dùng.

## Why
Vấn đề đang gặp. Nếu có issue liên quan thì `Closes #<số>`.

## How
Tóm tắt kỹ thuật: file nào mới, file nào sửa, quyết định thiết kế đáng chú ý.

## Compatibility
- Desktop / mobile parity: có hay không, vì sao.
- Hành vi mặc định có đổi với người dùng cũ không (nên là KHÔNG - tính năng mới phải opt-in).
- l10n: liệt kê key mới và các ngôn ngữ đã dịch.

## Testing
Lệnh đã chạy + kết quả. Ảnh chụp trước/sau nếu là thay đổi UI.
```

## Lưu ý

- Mặc định của tính năng mới phải giữ nguyên hành vi cũ, để không làm phiền người dùng hiện tại.
- Không ép buộc; nếu người dùng chưa xác nhận nội dung PR thì in ra bản nháp để họ duyệt trước khi `gh pr create`.
