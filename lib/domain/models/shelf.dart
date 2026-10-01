import 'tape_item.dart';

/// 사용자 칸 — logic.js `Group`.
class ShelfGroup {
  const ShelfGroup({
    required this.id,
    required this.name,
    required this.items,
    this.cap = defaultCap,
  });

  /// 한 칸에 넣을 수 있는 테이프 수 (계약서 `groups[].cap`, 지금 10)
  static const defaultCap = 10;

  final String id;
  final String name;
  final List<TapeItem> items;
  final int cap;

  /// 꽉 찼다 (`items.length >= cap`, `gFull`). 더 넣는 것만 막는다.
  bool get full => items.length >= cap;

  ShelfGroup copyWith({String? name, List<TapeItem>? items}) => ShelfGroup(
    id: id,
    name: name ?? this.name,
    items: items ?? this.items,
    cap: cap,
  );
}

/// 서랍 전체 — "분류 안 함"(`unsorted`) + 사용자 칸 + 보관 한도.
class Shelf {
  const Shelf({
    required this.unsorted,
    required this.groups,
    required this.cap,
  });

  static const empty = Shelf(unsorted: [], groups: [], cap: 12);

  /// 분류 안 함. 새로 받은 테이프가 여기로 들어온다.
  final List<TapeItem> unsorted;
  final List<ShelfGroup> groups;

  /// 보관 한도 (처음 12)
  final int cap;

  /// 보관량 = 뜯은 테이프 수 (모든 칸 + 분류 안 함의 뜯은 테이프). 안 뜯은 소포는 세지 않는다
  /// (계약서 `stored`).
  int get stored =>
      groups.fold<int>(0, (a, g) => a + g.items.length) +
      unsorted.where((x) => x.opened).length;

  bool get full => stored >= cap;

  bool get isEmpty => unsorted.isEmpty && groups.isEmpty;

  int get unopenedCount => unsorted.where((x) => !x.opened).length;

  bool get hasNew => unopenedCount > 0;

  ShelfGroup? group(String id) => groups.where((g) => g.id == id).firstOrNull;

  /// [groupId]가 null이면 분류 안 함.
  List<TapeItem> itemsOf(String? groupId) =>
      groupId == null ? unsorted : (group(groupId)?.items ?? const []);

  TapeItem? find(String id) {
    for (final x in unsorted) {
      if (x.id == id) return x;
    }
    for (final g in groups) {
      for (final x in g.items) {
        if (x.id == id) return x;
      }
    }
    return null;
  }

  Shelf copyWith({List<TapeItem>? unsorted, List<ShelfGroup>? groups}) => Shelf(
    unsorted: unsorted ?? this.unsorted,
    groups: groups ?? this.groups,
    cap: cap,
  );
}
