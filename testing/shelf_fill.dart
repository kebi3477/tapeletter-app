import 'package:tapeletter_app/data/model/shelf_dto.dart';
import 'package:tapeletter_app/data/services/local/local_store.dart';

/// 가짜 서버의 [gi]번째 칸을 테이프 [n]개로 채운다 (첫 테이프를 복사, 새 id).
void fillGroup(LocalStore s, int gi, int n) {
  final g = s.groups[gi];
  final base = g.items.first;
  g.items = [
    ...g.items,
    for (var i = g.items.length; i < n; i++)
      ShelfItemDto(
        id: s.nextId('t'),
        sender: base.sender,
        tapeType: base.tapeType,
        durationMs: base.durationMs,
        tag: base.tag,
        sentAt: base.sentAt,
        opened: true,
        openedAt: base.openedAt,
        viaLink: false,
        groupId: g.id,
      ),
  ];
}
