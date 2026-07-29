import 'package:flutter_test/flutter_test.dart';
import 'package:proxypin/network/http/http.dart';
import 'package:proxypin/ui/component/request_tree.dart';
import 'package:proxypin/ui/configuration.dart';

HttpRequest _request(String url) => HttpRequest(HttpMethod.get, url);

RequestTreeNode _child(RequestTreeNode node, String name) {
  return node.children.firstWhere((child) => child.name == name);
}

void main() {
  group('RequestTree.build', () {
    test('splits the path into one node per segment', () {
      final root = RequestTree.build('https://github.com', [
        _request('https://github.com/hominhtuong/proxypin/latest-commit'),
      ]);

      expect(root.name, 'https://github.com');
      expect(root.depth, 0);

      final user = _child(root, 'hominhtuong');
      expect(user.depth, 1);

      final repo = _child(user, 'proxypin');
      expect(repo.depth, 2);

      final leaf = _child(repo, 'latest-commit');
      expect(leaf.depth, 3);
      expect(leaf.hasChildren, isFalse);
      expect(leaf.requests, hasLength(1));
    });

    test('shares the folders of requests living under the same path', () {
      final root = RequestTree.build('https://github.com', [
        _request('https://github.com/hominhtuong/proxypin/latest-commit'),
        _request('https://github.com/hominhtuong/proxypin/tree-commit-info'),
        _request('https://github.com/hominhtuong/other/readme'),
      ]);

      final user = _child(root, 'hominhtuong');
      expect(user.children.map((node) => node.name), ['proxypin', 'other']);
      expect(_child(user, 'proxypin').children, hasLength(2));
      expect(user.requestCount, 3);
      expect(root.requestCount, 3);
    });

    test('keeps a node that is both a folder and a request', () {
      final root = RequestTree.build('https://github.com', [
        _request('https://github.com/hominhtuong/proxypin'),
        _request('https://github.com/hominhtuong/proxypin/latest-commit'),
      ]);

      final repo = _child(_child(root, 'hominhtuong'), 'proxypin');
      expect(repo.hasChildren, isTrue);
      expect(repo.requests, hasLength(1), reason: 'request tới chính thư mục vẫn là leaf của nó');
      expect(repo.requestCount, 2);
    });

    test('the query string does not create a node', () {
      final root = RequestTree.build('https://api.github.com', [
        _request('https://api.github.com/search?q=proxypin'),
        _request('https://api.github.com/search?q=flutter'),
      ]);

      final search = _child(root, 'search');
      expect(search.hasChildren, isFalse);
      expect(search.requests, hasLength(2), reason: 'cùng path khác query thì nằm cạnh nhau');
    });

    test('a request on the domain root stays on the root node', () {
      final root = RequestTree.build('https://example.com', [
        _request('https://example.com/'),
      ]);

      expect(root.hasChildren, isFalse);
      expect(root.requests, hasLength(1));
      expect(root.requestCount, 1);
    });

    test('preserves the insertion order given by the caller', () {
      final first = _request('https://example.com/a');
      final second = _request('https://example.com/b');

      final desc = RequestTree.build('https://example.com', [second, first]);
      expect(desc.children.map((node) => node.name), ['b', 'a']);

      final asc = RequestTree.build('https://example.com', [first, second]);
      expect(asc.children.map((node) => node.name), ['a', 'b']);
    });

    test('orderedRequests follows the display order: children then own requests', () {
      final folderRequest = _request('https://github.com/hominhtuong/proxypin');
      final childRequest = _request('https://github.com/hominhtuong/proxypin/latest-commit');
      final otherRequest = _request('https://github.com/hominhtuong/other');

      final root = RequestTree.build('https://github.com', [folderRequest, childRequest, otherRequest]);

      expect(root.orderedRequests(), [childRequest, folderRequest, otherRequest]);
    });
  });

  group('RequestTree.leafLabel', () {
    test('uses the last path segment', () {
      expect(RequestTree.leafLabel(_request('https://github.com/hominhtuong/proxypin/latest-commit')), 'latest-commit');
    });

    test('appends the query string', () {
      expect(RequestTree.leafLabel(_request('https://api.github.com/search?q=proxypin')), 'search?q=proxypin');
    });

    test('falls back to / on the domain root', () {
      expect(RequestTree.leafLabel(_request('https://example.com/')), '/');
      expect(RequestTree.leafLabel(_request('https://example.com')), '/');
    });
  });

  group('RequestViewMode', () {
    test('falls back to tree on an unknown or missing value', () {
      expect(RequestViewMode.of(null), RequestViewMode.tree);
      expect(RequestViewMode.of('nope'), RequestViewMode.tree);
      expect(RequestViewMode.of('list'), RequestViewMode.list);
      expect(RequestViewMode.of('tree'), RequestViewMode.tree);
    });
  });

  group('AppConfiguration.requestViewModeOf', () {
    test('an upgrade from a version without the key keeps the old flat list', () {
      // ui_config.json cũ: có nội dung nhưng chưa từng biết tới tree view
      final oldConfig = {'mode': 'system', 'themeColor': 'Pink', 'headerViewMode': 'table'};
      expect(AppConfiguration.requestViewModeOf(oldConfig), RequestViewMode.list,
          reason: 'người dùng cũ nâng cấp lên không được thấy giao diện khác đi');
    });

    test('what the user picked always wins', () {
      expect(AppConfiguration.requestViewModeOf({'requestViewMode': 'tree'}), RequestViewMode.tree);
      expect(AppConfiguration.requestViewModeOf({'requestViewMode': 'list'}), RequestViewMode.list);
    });

    test('a corrupted value falls back to tree', () {
      expect(AppConfiguration.requestViewModeOf({'requestViewMode': 'rubbish'}), RequestViewMode.tree);
      expect(AppConfiguration.requestViewModeOf({'requestViewMode': null}), RequestViewMode.tree);
    });
  });

  group('RequestTree.visibleRows', () {
    final root = RequestTree.build('https://github.com', [
      _request('https://github.com/hominhtuong/proxypin'),
      _request('https://github.com/hominhtuong/proxypin/latest-commit'),
      _request('https://github.com/hominhtuong/other'),
    ]);

    test('a collapsed tree only shows its first level', () {
      final rows = RequestTree.visibleRows(root, RequestTreeExpansion());
      expect(rows.map((row) => row.label), ['hominhtuong']);
      expect(rows.single.isFolder, isTrue);
      expect(rows.single.parentKey, 'https://github.com', reason: 'mũi tên trái quay về dòng domain');
    });

    test('an open tree lists the lines top to bottom, exactly as rendered', () {
      final rows = RequestTree.visibleRows(root, RequestTreeExpansion(expandedByDefault: true));
      expect(rows.map((row) => row.label), [
        'hominhtuong',
        'proxypin',
        'latest-commit',
        'proxypin', // request tới chính thư mục, nằm sau các con của nó
        'other',
      ]);
      expect(rows.map((row) => row.depth), [1, 2, 3, 3, 2]);
      expect(rows.map((row) => row.isFolder), [true, true, false, false, false]);
    });

    test('every line points at the folder that holds it', () {
      final rows = RequestTree.visibleRows(root, RequestTreeExpansion(expandedByDefault: true));

      // hai dòng cùng tên proxypin: dòng 1 là thư mục, dòng 3 là request tới chính nó
      expect(rows[1].parentKey, 'https://github.com/hominhtuong', reason: 'thư mục proxypin');
      expect(rows[2].parentKey, 'https://github.com/hominhtuong/proxypin', reason: 'latest-commit');
      expect(rows[3].parentKey, 'https://github.com/hominhtuong/proxypin',
          reason: 'request tới chính thư mục nằm trong thư mục đó');
      expect(rows[4].parentKey, 'https://github.com/hominhtuong', reason: 'other');
    });

    test('line keys are unique so the cursor can never be ambiguous', () {
      final rows = RequestTree.visibleRows(root, RequestTreeExpansion(expandedByDefault: true));
      expect(rows.map((row) => row.key).toSet(), hasLength(rows.length));
    });

    test('collapsing a folder hides its subtree', () {
      final expansion = RequestTreeExpansion(expandedByDefault: true);
      expansion.setExpanded('https://github.com/hominhtuong/proxypin', false);

      final rows = RequestTree.visibleRows(root, expansion);
      expect(rows.map((row) => row.label), ['hominhtuong', 'proxypin', 'other']);
    });
  });

  group('RequestTreeExpansion', () {
    test('folders start collapsed and toggle one by one', () {
      final expansion = RequestTreeExpansion();
      expect(expansion.isExpanded('a'), isFalse);

      expansion.toggle('a');
      expect(expansion.isExpanded('a'), isTrue);
      expect(expansion.isExpanded('b'), isFalse);

      expansion.toggle('a');
      expect(expansion.isExpanded('a'), isFalse);
    });

    test('expandAll and collapseAll reset the per folder overrides', () {
      final expansion = RequestTreeExpansion();
      expansion.toggle('a');

      expansion.expandAll();
      expect(expansion.isExpanded('a'), isTrue);
      expect(expansion.isExpanded('anything'), isTrue);

      expansion.toggle('a');
      expect(expansion.isExpanded('a'), isFalse, reason: 'sau expandAll thì toggle là đóng lại');

      expansion.collapseAll();
      expect(expansion.isExpanded('a'), isFalse);
      expect(expansion.isExpanded('anything'), isFalse);
    });

    test('notifies its listeners', () {
      final expansion = RequestTreeExpansion();
      var notified = 0;
      expansion.addListener(() => notified++);

      expansion.toggle('a');
      expansion.expandAll();
      expansion.collapseAll();

      expect(notified, 3);
    });
  });
}
