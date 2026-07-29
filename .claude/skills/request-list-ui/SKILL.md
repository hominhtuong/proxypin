---
name: request-list-ui
description: Kiến thức chi tiết về hệ thống UI danh sách request/domain của ProxyPin (desktop + mobile) - cách request chảy từ proxy vào widget, cách gom nhóm theo domain, chế độ hiển thị List/Tree, search, multi-select, sort. Dùng skill này khi sửa hoặc thêm tính năng liên quan tới màn hình danh sách bắt gói, tree view, tab "Domain List" / "Sequence", hoặc khi debug việc request không xuất hiện / xuất hiện sai chỗ trong danh sách.
---

# UI danh sách request của ProxyPin

## Luồng dữ liệu

Proxy runtime bắn event qua `EventListener` (`lib/network/bin/listener.dart`) tới shell của từng nền tảng:

```
ProxyServer -> EventListener.onRequest/onResponse
  -> DesktopHomePage (lib/ui/desktop/desktop.dart)   -> DesktopRequestListState.add()/addResponse()
  -> MobileHomeState (lib/ui/mobile/mobile.dart)     -> RequestListState.add()/addResponse()
```

Mỗi shell giữ **một** `ListenableList<HttpRequest> container` là nguồn dữ liệu duy nhất, rồi fan-out sang hai tab con qua `GlobalKey`:

| Tab | Desktop | Mobile |
|---|---|---|
| Gom theo domain | `DomainList` / `DomainWidgetState` - `lib/ui/desktop/request/domains.dart` | `DomainList` / `DomainListState` - `lib/ui/mobile/request/domians.dart` (lưu ý tên file gõ sai chính tả từ upstream, **đừng đổi tên**) |
| Theo thứ tự thời gian | `RequestSequence` - `lib/ui/desktop/request/request_sequence.dart` | `lib/ui/mobile/request/request_sequence.dart` |

Widget cha điều phối:
- Desktop: `DesktopRequestListWidget` - `lib/ui/desktop/request/list.dart`
- Mobile: `RequestListWidget` - `lib/ui/mobile/request/list.dart`

Vì cả hai tab cùng đọc một `container`, khi xoá request ở tab này phải gọi callback (`domainListRemove` / `sequenceRemove`) để tab kia đồng bộ. Bỏ sót bước này là nguồn bug kinh điển của khu vực này.

## Khác biệt desktop vs mobile - đừng nhầm

**Desktop** gom theo `request.remoteDomain()` (trả về chuỗi dạng `https://github.com`), key của `containerMap` là `String`. Mỗi domain là một `DomainRequests` - widget tự quản state, tự expand/collapse, có `GlobalKey` riêng để `changeState()` mà không rebuild cả cây. Click vào request thì mở nội dung ở panel bên phải (`NetworkTabController`).

**Mobile** gom theo `request.hostAndPort` (`HostAndPort`), key của `containerMap` là object. Danh sách domain là `ListView` phẳng; bấm vào một domain thì `Navigator.push` sang trang `RequestSequence` mới. Không có panel bên phải.

## Chế độ hiển thị List / Tree

Từ bản custom này, tab domain có hai chế độ, lưu ở `AppConfiguration.requestViewMode` (`lib/ui/configuration.dart`, ghi vào `ui_config.json`, key `requestViewMode`, giá trị `list` | `tree`).

- **List** - hành vi gốc của upstream: domain -> danh sách request phẳng.
- **Tree** - kiểu Charles Proxy: domain -> từng path segment thành một node folder -> leaf là request.

Model cây nằm ở `lib/ui/component/request_tree.dart`, **dùng chung cho cả desktop lẫn mobile**. Đây là code thuần Dart, không phụ thuộc Flutter widget, nên test được bằng unit test (`test/request_tree_test.dart`).

Quy tắc dựng cây (khớp Charles):
- Path được tách theo `/`, bỏ segment rỗng.
- Query string **không** tạo node, nó thuộc về leaf. Hai request cùng path khác query là hai leaf khác nhau nằm cùng chỗ.
- Request tới root (`/`) trở thành một leaf ngay dưới node domain.
- Node folder giữ thứ tự chèn (lần đầu nhìn thấy segment), leaf tuân theo `sortDesc` của toolbar.
- Đếm số request của một folder = tổng leaf trong toàn bộ cây con.

Khi thêm tính năng vào khu vực này: sửa model ở `request_tree.dart` một lần, đừng copy logic sang hai file UI.

## Search

`SearchModel` (`lib/ui/component/model/search_model.dart`) lọc theo keyword + điều kiện. Ở desktop, search tạo ra `searchView` là bản copy của `containerMap` chỉ chứa request khớp - **không** sửa `containerMap` gốc. Ở mobile, search dựng `_domainMatcher` rồi lọc `view`.

Ở chế độ tree, cây phải được dựng lại từ tập request đã lọc, và các node cha của leaf khớp phải tự động expand - nếu không người dùng thấy cây trống.

## Multi-select

`MultiSelectController` (`lib/ui/component/multi_select_controller.dart`) dùng GetX `Rx`, giữ set `requestId`. Sau khi xoá request phải gọi `selectionController.prune(...)` để bỏ id mồ côi. Range-select (`selectRange`) cần một danh sách phẳng theo đúng thứ tự đang hiển thị - ở chế độ tree, đó là thứ tự duyệt DFS của các leaf đang mở.

## Sort

`sortDesc` do widget cha giữ, truyền xuống qua method `sort(bool desc)`. Desktop đảo `Queue body` của từng `DomainRequests`; mobile chỉ set cờ rồi trang chi tiết đọc lại. Ở tree, sort chỉ ảnh hưởng thứ tự leaf trong cùng một folder.

## Bẫy hay gặp

- `changeState()` ở đây là debounce thủ công (350ms mobile / 500ms desktop) để tránh setState liên tục khi traffic dồn dập. Đừng thay bằng `setState` trực tiếp trong đường hot path.
- `DomainRequests` được tạo với `super(key: GlobalKey<_DomainRequestsState>())` rồi cast key ra để gọi state - pattern lạ nhưng là của upstream, giữ nguyên.
- Trên desktop, `AutomaticKeepAliveClientMixin` bắt buộc phải gọi `super.build(context)` đầu hàm `build`.
- `request.remoteDomain()` có thể trả `null` (request chưa parse được host) - luôn kiểm tra trước khi dùng làm key.
