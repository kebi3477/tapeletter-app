import 'package:flutter/material.dart';

import '../../../domain/models/friend.dart';

import '../../../domain/models/friend_tapes.dart';
import '../../core/themes/colors.dart';
import '../../core/themes/dimens.dart';
import '../../core/themes/tape_palette.dart';
import '../../core/themes/text_styles.dart';
import '../../core/ui/buttons.dart';
import '../../core/ui/mini_tape.dart';
import '../view_model/friend_view_model.dart';
import '../../core/ui/tappable.dart';
import '../../core/ui/keep_all.dart';

/// 친구 화면 — 템플릿 `fvOn` 블록. 그 친구가 보낸 테이프만 모아 본다.
class FriendScreen extends StatelessWidget {
  const FriendScreen({
    super.key,
    required this.viewModel,
    required this.onBack,
    required this.onAlias,
    required this.onPlay,
    required this.onRecord,
  });

  final FriendViewModel viewModel;
  final VoidCallback onBack;

  /// 별명 설정 시트
  final ValueChanged<Friend> onAlias;

  /// 행을 누르거나 "모두 재생" (첫 테이프부터)
  final void Function(FriendTape tape) onPlay;

  /// 녹음해서 보내기
  final VoidCallback onRecord;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.paper,
      body: SafeArea(
        bottom: false,
        child: ListenableBuilder(
          listenable: viewModel,
          builder: (context, _) {
            final vm = viewModel;
            final tapes = vm.tapes;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                BackBar(onBack: onBack),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 4, 24, 18),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(vm.name, style: AppText.bigTitle),
                            const SizedBox(height: 4),
                            Text(
                              vm.subtitle,
                              style: AppText.suit(
                                500,
                                13.5,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      // 별명 설정 (`fvAlias`) — 40 높이 알약
                      if (vm.friend case final f?)
                        Semantics(
                          button: true,
                          child: Tappable(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => onAlias(f),
                            child: Container(
                              constraints: const BoxConstraints(minHeight: 40),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Center(
                                widthFactor: 1,
                                child: Text(
                                  keepAll('별명 설정'),
                                  style: AppText.suit(700, 13.5),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 14),
                  child: Row(
                    children: [
                      Expanded(
                        child: AppButton(
                          label: '모두 재생',
                          height: 50,
                          radius: AppRadius.row,
                          textStyle: AppText.suit(700, 15),
                          background: tapes.isEmpty
                              ? AppColors.disabled
                              : AppColors.ink,
                          leading: const CustomPaint(
                            size: Size(11, 14),
                            painter: _PlayTriangle(),
                          ),
                          onTap: tapes.isEmpty
                              ? null
                              : () => onPlay(tapes.first),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: AppButton.soft(
                          label: '녹음해서 보내기',
                          height: 50,
                          radius: AppRadius.row,
                          textStyle: AppText.suit(700, 15),
                          leading: Container(
                            width: 10,
                            height: 10,
                            decoration: const BoxDecoration(
                              color: AppColors.red,
                              shape: BoxShape.circle,
                            ),
                          ),
                          onTap: vm.friend == null ? null : onRecord,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: DecoratedBox(
                    decoration: const BoxDecoration(
                      border: Border(top: BorderSide(color: AppColors.line)),
                    ),
                    child: vm.empty
                        ? Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: 40,
                              horizontal: 24,
                            ),
                            child: Text(
                              keepAll('아직 받은 테이프가 없어요'),
                              textAlign: TextAlign.center,
                              style: AppText.suit(
                                500,
                                14,
                                height: 1.5,
                                color: AppColors.textFaint,
                              ),
                            ),
                          )
                        : ListView.builder(
                            padding: EdgeInsets.fromLTRB(
                              12,
                              4,
                              12,
                              24 + MediaQuery.viewPaddingOf(context).bottom,
                            ),
                            itemCount: tapes.length,
                            itemBuilder: (context, i) => _TapeRow(
                              vm: vm,
                              tape: tapes[i],
                              onTap: () => onPlay(tapes[i]),
                            ),
                          ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// 행 60: 미니 테이프, 날짜(700 15.5), "3분 · 2026 생일", 오른쪽 길이
class _TapeRow extends StatelessWidget {
  const _TapeRow({required this.vm, required this.tape, required this.onTap});

  final FriendViewModel vm;
  final FriendTape tape;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tappable(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: AppSizes.row),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              MiniTape(palette: TapePalette.of(tape.item.type)),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      vm.dateOf(tape),
                      style: AppText.suit(700, 15.5, tabularNums: true),
                    ),
                    const SizedBox(height: 2),
                    Text(vm.subOf(tape), style: AppText.caption),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Text(
                vm.durOf(tape),
                style: AppText.suit(
                  600,
                  12,
                  color: AppColors.textFaint,
                  tabularNums: true,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// ▶ (border-left 11, 위아래 7)
class _PlayTriangle extends CustomPainter {
  const _PlayTriangle();

  @override
  void paint(Canvas canvas, Size size) {
    final p = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, size.height / 2)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(p, Paint()..color = AppColors.paper);
  }

  @override
  bool shouldRepaint(_PlayTriangle old) => false;
}
