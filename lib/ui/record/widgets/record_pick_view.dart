import 'package:flutter/material.dart';

import '../../../domain/models/friend.dart';
import '../../../utils/format.dart';
import '../../core/themes/colors.dart';
import '../../core/themes/dimens.dart';
import '../../core/themes/text_styles.dart';
import '../../core/ui/animations.dart';
import '../../core/ui/buttons.dart';
import '../../friend/widgets/alias_sheet.dart';
import '../view_model/record_view_model.dart';
import '../../core/ui/tappable.dart';

/// 녹음 · 받는 사람 — 템플릿 `vPick` 블록. 즐겨찾기 먼저.
class RecordPickView extends StatelessWidget {
  const RecordPickView({super.key, required this.viewModel});

  final RecordViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final vm = viewModel;
    final friends = vm.sortedFriends;
    return SlideUp(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          BackBar(onBack: vm.backConfirm),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 4, 24, 18),
            child: Text('누구에게\n보낼까요?', style: AppText.bigTitle),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: friends.length,
              itemBuilder: (context, i) => _FriendRow(
                friend: friends[i],
                onTap: () => vm.pickFriend(friends[i]),
                onStar: () => vm.toggleStar(friends[i]),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(24, 12, 24, bottomSafe(context)),
            child: AppButton.soft(
              label: '새 친구에게 링크로 보내기',
              textStyle: AppText.suit(700, 15),
              onTap: vm.pickNew,
              leading: Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.ink, width: 1.8),
                ),
                alignment: Alignment.center,
                child: Text(
                  '+',
                  textScaler: TextScaler.noScaling,
                  style: AppText.suit(700, 13, height: 1),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 행 64: 이름(700 16) + "즐겨찾기 · 09.24" / "최근 09.24", 오른쪽 ★/☆
class _FriendRow extends StatefulWidget {
  const _FriendRow({
    required this.friend,
    required this.onTap,
    required this.onStar,
  });

  final Friend friend;
  final VoidCallback onTap;
  final VoidCallback onStar;

  @override
  State<_FriendRow> createState() => _FriendRowState();
}

class _FriendRowState extends State<_FriendRow> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final f = widget.friend;
    final last = f.lastAt == null ? '-' : formatMonthDay(f.lastAt!);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: Haptic.selection.wrap(widget.onTap),
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: Container(
        constraints: const BoxConstraints(minHeight: 64),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          // style-hover="background:#F6F6F4" — 터치에서는 누르는 동안
          color: _pressed ? AppColors.surfaceSoft : null,
          borderRadius: BorderRadius.circular(AppRadius.row),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FriendNameLine(friend: f, style: AppText.suit(700, 16)),
                  const SizedBox(height: 2),
                  Text(
                    f.starred ? '즐겨찾기 · $last' : '최근 $last',
                    style: AppText.caption,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Semantics(
              button: true,
              label: f.starred ? '즐겨찾기 해제' : '즐겨찾기',
              excludeSemantics: true,
              child: Tappable(
                behavior: HitTestBehavior.opaque,
                onTap: widget.onStar,
                child: SizedBox.square(
                  dimension: 40,
                  child: Center(
                    child: Text(
                      f.starred ? '★' : '☆',
                      // 글자 모양 아이콘 — 큰 글씨에도 크기 고정 (v10.4)
                      textScaler: TextScaler.noScaling,
                      style: AppText.suit(
                        400,
                        20,
                        height: 1,
                        color: f.starred ? AppColors.star : AppColors.disabled,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
