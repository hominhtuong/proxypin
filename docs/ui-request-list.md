# UI danh sách request và chế độ hiển thị cây

Tài liệu cho khu vực màn hình bắt gói: tab domain, tab theo thời gian, và chế độ hiển thị List/Tree kiểu Charles Proxy.

## Luồng dữ liệu

Proxy runtime bắn event tới shell của từng nền tảng, shell giữ **một** `ListenableList<HttpRequest>` duy nhất rồi fan-out sang hai tab con qua `GlobalKey`:

```
ProxyServer -> EventListener.onRequest / onResponse
   ├─ desktop: DesktopHomePage -> DesktopRequestListState (lib/ui/desktop/request/list.dart)
   └─ mobile:  MobileHomeState  -> RequestListState       (lib/ui/mobile/request/list.dart)
                                        ├─ DomainList      gom theo domain
                                        └─ RequestSequence theo thứ tự thời gian
```

| | Desktop | Mobile |
|---|---|---|
| Tab domain | [lib/ui/desktop/request/domains.dart](../lib/ui/desktop/request/domains.dart) | [lib/ui/mobile/request/domians.dart](../lib/ui/mobile/request/domians.dart) (tên file gõ sai từ upstream, **không đổi**) |
| Dòng request | `RequestWidget` - [lib/ui/desktop/request/request.dart](../lib/ui/desktop/request/request.dart) | `RequestRow` - [lib/ui/mobile/request/request.dart](../lib/ui/mobile/request/request.dart) |
| Gom nhóm theo | `request.remoteDomain()` (String) | `request.hostAndPort` (object) |
| Mở chi tiết | panel bên phải (`NetworkTabController`) | `Navigator.push` sang trang mới |

Vì hai tab dùng chung một `container`, xoá request ở tab này phải gọi callback (`domainListRemove` / `sequenceRemove`) để tab kia đồng bộ. Bỏ sót bước này là nguồn bug kinh điển ở đây.

## Chế độ List / Tree

Lưu ở `AppConfiguration.requestViewMode` ([lib/ui/configuration.dart](../lib/ui/configuration.dart)), ghi xuống `ui_config.json` với key `requestViewMode`, giá trị `list` hoặc `tree`. **Mặc định là `tree`.**

Chuyển chế độ:
- Nút icon ngay trên thanh tab (list ⇄ tree) - đường chính, có ở cả desktop lẫn mobile.
- Desktop còn có mục `View Mode: List/Tree` trong menu 3 chấm, kèm `Expand All` / `Collapse All` khi đang ở tree.
- Mobile: menu `+` (`MoreMenu`) - cùng bộ mục.

Thư mục **mặc định thu gọn**, giống Charles. Bấm dòng thư mục để mở, bấm lần nữa để thu lại.

Ở chế độ tree, mỗi request chiếm **đúng một dòng** (bỏ dòng phụ chứa thời gian/status/size) để cây không bị rối; chi tiết xem ở panel bên phải khi bấm vào.

## Điều hướng bàn phím (desktop)

Bấm vào một dòng bất kỳ để danh sách nhận focus, sau đó:

| Phím | Hành vi |
|---|---|
| ↓ / ↑ | Di chuyển con trỏ theo đúng thứ tự đang hiển thị, xuyên qua ranh giới domain |
| → | Thư mục đang đóng thì mở ra; đang mở rồi thì nhảy vào con đầu tiên |
| ← | Thư mục đang mở thì thu lại; đang đóng hoặc là dòng request thì quay về node cha |

Con trỏ dừng ở dòng request sẽ tự mở request đó ở panel bên phải, giống Charles.

Cơ chế: `DomainWidgetState` giữ `cursor` (`ValueNotifier<String?>` chứa `RequestTreeRow.key`) và một `FocusNode` bọc quanh danh sách. `_visibleRows()` dựng danh sách dòng phẳng gồm dòng domain + cây của các domain đang mở, **dùng đúng hàm `RequestTree.visibleRows()` mà widget dùng để render**, nên thứ tự phím đi luôn khớp thứ tự trên màn hình - đây là lý do tách `visibleRows()` ra thay vì để mỗi bên tự duyệt cây.

Cuộn theo con trỏ nhờ một `SizedBox` cao 0 mang `GlobalKey`, chèn ngay phía trên dòng đang chọn rồi gọi `Scrollable.ensureVisible`. Cách này tránh phải bọc thêm widget quanh chính dòng đó, vốn sẽ làm `State` của dòng bị dựng lại mỗi lần con trỏ đi qua.

## Model cây

[lib/ui/component/request_tree.dart](../lib/ui/component/request_tree.dart) là Dart thuần (chỉ phụ thuộc `foundation` cho `ChangeNotifier`), dùng chung cho cả hai nền tảng và test được bằng unit test.

| Thành phần | Vai trò |
|---|---|
| `RequestViewMode` | enum `list` / `tree`, `of(String?)` parse an toàn từ config |
| `RequestTreeNode` | một node: `name`, `key` (định danh ổn định), `depth`, `children`, `requests` |
| `RequestTree.build()` | dựng cây cho một domain từ danh sách request |
| `RequestTree.leafLabel()` | nhãn của dòng request: segment cuối + query |
| `RequestTreeExpansion` | trạng thái đóng/mở, tách khỏi widget |
| `RequestTreeRow` | một dòng trên màn hình: key, parentKey, depth, label, node, request |
| `RequestTree.visibleRows()` | duỗi phần cây đang mở thành danh sách dòng theo đúng thứ tự hiển thị |
| `RequestTreeStyle` | nhãn + độ sâu + rowKey áp lên dòng request khi ở tree |

### Quy tắc dựng cây (bám đúng Charles)

- Path tách theo `/`, bỏ segment rỗng. Mỗi segment là một node.
- **Query string không tạo node**, nó thuộc về leaf. Hai request cùng path khác query là hai leaf nằm cạnh nhau.
- Request tới root (`/`) là leaf ngay dưới node domain, nhãn hiển thị `/`.
- Một node có thể **vừa là thư mục vừa là request**. Ví dụ có cả `/user/repo` và `/user/repo/commit`: node `repo` là thư mục, và request tới chính `/user/repo` là một leaf nằm bên trong nó. Đây đúng là cách Charles hiển thị.
- Thứ tự node giữ theo thứ tự chèn, nên `sortDesc` của toolbar được tôn trọng mà model không cần biết gì về sort.

### Quy tắc thụt lề

`RequestTreeView._childrenOf(node)` phát ra **mọi** dòng con ở độ sâu `node.depth + 1`:

- thư mục con => `node.depth + 1` = `child.depth`
- leaf của một node con không có thư mục => cũng `child.depth`
- leaf của chính `node` => `node.depth + 1`, tức sâu hơn dòng thư mục của nó một bậc

Một bậc là `RequestTreeStyle.indentStep` = 14px. Dòng thư mục có `contentPadding.left = 3 + depth * 14` cộng icon mũi tên 25px; dòng request có `28 + depth * 14`. Nhờ vậy chữ của thư mục và của request cùng bậc thẳng hàng.

### Trạng thái đóng/mở

`RequestTreeExpansion` không giữ danh sách node đang mở, mà giữ:
- `_defaultExpanded`: trạng thái của thư mục người dùng chưa từng bấm vào
- `_toggled`: những thư mục đã bị lật khỏi mặc định đó

Nhờ vậy `expandAll()` / `collapseAll()` chỉ cần đổi mặc định và xoá danh sách lật, không phải duyệt cây. Trạng thái sống ngoài widget nên không mất khi traffic dồn về làm rebuild liên tục.

## Tái sử dụng dòng request

Mục tiêu: dòng request trong cây giữ **nguyên** mọi hành vi cũ - context menu, chọn nhiều, tô màu keyword, click mở chi tiết. Nên hai nền tảng đều truyền chính widget dòng request của mình vào `leafBuilder`, chứ không vẽ lại dòng mới.

Trên desktop, `RequestWidget` là instance tồn tại lâu (giữ trong `DomainRequests.body`), nên `treeStyle` là field có thể thay đổi và được set qua `applyTreeStyle()`. Hàm này lên lịch refresh ở frame kế tiếp thay vì gọi `setState` ngay, vì nó được gọi từ trong `build` của widget cha. Nó cũng tự bỏ qua khi vị trí không đổi, nên chỉ tốn thêm một frame đúng lúc người dùng đổi chế độ.

Trên mobile, `RequestRow` được dựng mới mỗi lần build nên `treeStyle` là field `final` bình thường.

Ở cả hai nơi, **màu keyword vẫn khớp theo path đầy đủ**, không theo nhãn ngắn của cây:

```dart
String path = widget.displayDomain ? request.domainPath : request.path;
String title = '${request.method.name} ${treeStyle?.label ?? path}';
var requestColor = color(path);   // vẫn là path đầy đủ
```

## Search

`SearchModel` lọc theo keyword và điều kiện. Trên desktop, search dựng `searchView` là bản copy của `containerMap` chỉ chứa request khớp, `containerMap` gốc không bị đụng.

Bản copy dùng **một `RequestTreeExpansion` riêng** (`searchExpansion`) khởi tạo với `expandedByDefault: true`. Nhờ vậy kết quả tìm kiếm mở sẵn, nhưng người dùng **vẫn thu gọn được** từng thư mục.

Bản đầu tiên dùng cờ `forceExpanded` ép mở bất chấp trạng thái - kết quả là khi đang search thì bấm vào thư mục không có tác dụng gì. Đừng quay lại cách đó.

Trên mobile, search chỉ lọc theo tên domain (hành vi có sẵn của upstream), không lọc từng request, nên cây không cần ép mở.

## Multi-select và sort

`MultiSelectController` giữ set `requestId`. Sau khi xoá phải gọi `prune(...)` để bỏ id mồ côi.

Range-select cần một danh sách phẳng **theo đúng thứ tự đang hiển thị**. Ở tree, thứ tự đó là thứ tự duyệt của `RequestTreeNode.orderedRequests()` (con trước, request của chính node sau), nên `DomainWidgetState.currentView()` rẽ nhánh theo `isTreeMode`.

`sortDesc` chỉ ảnh hưởng thứ tự các dòng trong cùng một thư mục, vì cây được dựng lại từ `body` vốn đã sắp xếp sẵn.

## Bẫy hay gặp

- `changeState()` ở đây là debounce thủ công (350ms mobile / 500ms desktop) để chống setState liên tục khi traffic dồn dập. Đừng thay bằng `setState` thẳng trong hot path.
- Ở tree, thân cây chỉ được build khi domain đang mở (`if (selected)`), khác với list mode dùng `Offstage`. Cố ý như vậy: `Offstage` vẫn build con, không nên trả giá dựng cây cho domain đang đóng. List mode giữ nguyên `Offstage` của upstream để không đổi hành vi giữ state của các dòng.
- `DomainRequests` được tạo với `super(key: GlobalKey<_DomainRequestsState>())` rồi cast key ra để gọi state - pattern lạ nhưng là của upstream, giữ nguyên.
- `request.remoteDomain()` có thể trả `null`, luôn kiểm tra trước khi dùng làm key.
- Widget test cho cây phải `pumpAndSettle()` sau `pumpWidget()`, vì delegate localization nạp bất đồng bộ nên frame đầu chưa render gì.

## Test

| File | Nội dung |
|---|---|
| [test/request_tree_test.dart](../test/request_tree_test.dart) | model: tách segment, gộp thư mục, node vừa là thư mục vừa là request, query không tạo node, giữ thứ tự chèn, `orderedRequests`, `leafLabel`, `RequestTreeExpansion` |
| [test/request_tree_view_test.dart](../test/request_tree_view_test.dart) | widget: mặc định đóng, bấm để mở, bấm lần nữa để thu, `expandedByDefault`, độ sâu thụt lề, số request trên thư mục, `expandAll`/`collapseAll` |

```bash
flutter test test/request_tree_test.dart test/request_tree_view_test.dart
```
