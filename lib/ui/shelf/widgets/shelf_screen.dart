import 'package:flutter/material.dart';

import '../../../domain/models/tape_item.dart';
import '../../../utils/format.dart';
import '../../core/themes/colors.dart';
import '../../core/themes/dimens.dart';
import '../../core/themes/tape_palette.dart';
import '../../core/themes/text_styles.dart';
import '../view_model/shelf_view_model.dart';
import 'shelf_bookcase_view.dart';
import 'shelf_drag.dart';
import 'shelf_list_view.dart';
import 'shelf_sheets.dart';
import '../../core/ui/tappable.dart';

/// 서랍 탭 — 템플릿 `vShelf` 블록.
class ShelfScreen extends StatefulWidget {
  const ShelfScreen({
    super.key,
    required this.viewModel,
    required this.onOpen,
    required this.onReply,
    required this.onGoShop,
    required this.onGoRecord,
  });

  final ShelfViewModel viewModel;

  /// 테이프 열기 (재생 오버레이)
  final void Function(TapeItem item) onOpen;

  /// ⋯ > 답장 녹음하기 → 녹음 탭
  final void Function(TapeItem item) onReply;

  /// 꽉 참·거의 참 배너 → 상점
  final VoidCallback onGoShop;

  /// 빈 서랍 → 녹음 탭
  final VoidCallback onGoRecord;

  @override
  State<ShelfScreen> createState() => _ShelfScreenState();
}

class _ShelfScreenState extends State<ShelfScreen> {
  final ScrollController _scroll = ScrollController();
  late final ShelfDragController _drag = ShelfDragController(
    viewModel: widget.viewModel,
    scroll: _scroll,
  );

  @override
  void initState() {
    super.initState();
    widget.viewModel.enter();
  }

  @override
  void dispose() {
    _drag.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _more(TapeItem item) => showItemSheet(
    context,
    viewModel: widget.viewModel,
    item: item,
    onReply: item.senderId == null ? null : () => widget.onReply(item),
  );

  @override
  Widget build(BuildContext context) {
    final vm = widget.viewModel;
    return ListenableBuilder(
      listenable: Listenable.merge([vm, _drag]),
      builder: (context, _) {
        final ghost = _drag.ghostItem;
        return Stack(
          key: _drag.areaKey,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Header(
                  viewModel: vm,
                  onAdd: () => showGroupSheet(context, viewModel: vm),
                ),
                Expanded(
                  child: Stack(
                    children: [
                      Positioned.fill(child: _body(vm)),
                      if (vm.skeleton)
                        const Positioned.fill(child: ShelfSkeleton()),
                    ],
                  ),
                ),
              ],
            ),
            if (ghost != null && _drag.ghostY != null)
              Positioned(
                left: 18,
                right: 18,
                top: _drag.ghostY,
                child: DragGhost(
                  item: ghost,
                  sub:
                      '${formatMonthDayTime(ghost.date)} · ${TapePalette.of(ghost.type).name}',
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _body(ShelfViewModel vm) {
    return SingleChildScrollView(
      key: _drag.viewportKey,
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (vm.fullOn) _FullBanner(onTap: widget.onGoShop),
          if (vm.emptyOn)
            _EmptyShelf(onGoRecord: widget.onGoRecord)
          else if (vm.view == ShelfView.list)
            ShelfListSections(
              viewModel: vm,
              drag: _drag,
              onOpen: widget.onOpen,
              onMore: _more,
              onEditGroup: (g) =>
                  showGroupSheet(context, viewModel: vm, group: g),
            )
          else
            ShelfBookcase(
              viewModel: vm,
              drag: _drag,
              onOpen: widget.onOpen,
              onEditGroup: (g) =>
                  showGroupSheet(context, viewModel: vm, group: g),
            ),
          _AddGroupButton(onTap: () => showGroupSheet(context, viewModel: vm)),
          if (vm.capNear) _NearFull(onTap: widget.onGoShop),
        ],
      ),
    );
  }
}

/// 헤더 60: "서랍" + 보관량, 보기 전환 세그먼트, + 버튼
class _Header extends StatelessWidget {
  const _Header({required this.viewModel, required this.onAdd});

  final ShelfViewModel viewModel;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final vm = viewModel;
    return SizedBox(
      height: AppSizes.header,
      child: Padding(
        padding: const EdgeInsets.only(left: 24, right: 16),
        child: Row(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text('서랍', style: AppText.screenTitle),
                const SizedBox(width: 8),
                Text(
                  vm.capText,
                  style: AppText.suit(
                    700,
                    13,
                    tabularNums: true,
                    color: vm.capFull ? AppColors.red : AppColors.textCount,
                  ),
                ),
              ],
            ),
            const Spacer(),
            _ViewSwitch(value: vm.view, onChanged: vm.setView),
            const SizedBox(width: 4),
            Semantics(
              button: true,
              label: '칸 추가',
              excludeSemantics: true,
              child: Tappable(
                behavior: HitTestBehavior.opaque,
                onTap: onAdd,
                child: SizedBox.square(
                  dimension: 40,
                  child: Center(
                    child: Text('+', style: AppText.suit(300, 30, height: 1)),
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

/// 목록 ↔ 책꽂이 세그먼트 (트랙 `#F3F3F1` radius 18 패딩 3, 버튼 36×30)
class _ViewSwitch extends StatelessWidget {
  const _ViewSwitch({required this.value, required this.onChanged});

  final ShelfView value;
  final ValueChanged<ShelfView> onChanged;

  @override
  Widget build(BuildContext context) {
    Widget seg(ShelfView v, String label, Widget icon) {
      final on = v == value;
      return Semantics(
        button: true,
        selected: on,
        label: label,
        excludeSemantics: true,
        child: Tappable(
          onTap: () => onChanged(v),
          child: Container(
            width: 36,
            height: 30,
            decoration: BoxDecoration(
              color: on
                  ? AppColors.paper
                  : AppColors.paper.withValues(alpha: 0),
              borderRadius: BorderRadius.circular(15),
              boxShadow: on ? AppShadows.segmentOn : null,
            ),
            child: icon,
          ),
        ),
      );
    }

    Color ink(ShelfView v) => v == value ? AppColors.ink : AppColors.textCount;
    Widget bar(double w, double h, Color c) => Container(
      width: w,
      height: h,
      decoration: BoxDecoration(
        color: c,
        borderRadius: BorderRadius.circular(1),
      ),
    );

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          seg(
            ShelfView.list,
            '목록 보기',
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                bar(14, 2, ink(ShelfView.list)),
                const SizedBox(height: 3),
                bar(14, 2, ink(ShelfView.list)),
                const SizedBox(height: 3),
                bar(14, 2, ink(ShelfView.list)),
              ],
            ),
          ),
          seg(
            ShelfView.shelf,
            '책꽂이 보기',
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (final (i, h) in const [
                    12.0,
                    14.0,
                    10.0,
                    13.0,
                  ].indexed) ...[
                    if (i > 0) const SizedBox(width: 2),
                    bar(3, h, ink(ShelfView.shelf)),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 서랍 꽉 참 배너 (`fullOn`)
class _FullBanner extends StatelessWidget {
  const _FullBanner({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tappable(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(top: 4, bottom: 8),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        decoration: BoxDecoration(
          color: AppColors.redTint,
          borderRadius: BorderRadius.circular(AppRadius.row),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('서랍이 꽉 찼어요', style: AppText.suit(800, 14.5)),
                  const SizedBox(height: 2),
                  Text(
                    '지우거나 넓혀야 새 테이프를 받을 수 있어요',
                    style: AppText.suit(
                      500,
                      12.5,
                      height: 1.45,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text('넓히기 ›', style: AppText.suit(700, 13, color: AppColors.red)),
          ],
        ),
      ),
    );
  }
}

/// 빈 서랍 (`emptyOn`)
class _EmptyShelf extends StatelessWidget {
  const _EmptyShelf({required this.onGoRecord});

  final VoidCallback onGoRecord;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 48, 12, 8),
      child: Column(
        children: [
          SizedBox(
            width: 220,
            child: Column(
              children: [
                Container(
                  height: 100,
                  alignment: Alignment.bottomCenter,
                  decoration: const BoxDecoration(
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(10),
                    ),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        AppColors.shelfBoardTop,
                        AppColors.shelfBoardBottom,
                      ],
                    ),
                  ),
                  child: const CustomPaint(
                    size: Size(30, 84),
                    painter: _DashedSpine(),
                  ),
                ),
                Container(
                  height: 10,
                  decoration: const BoxDecoration(
                    color: AppColors.shelfPlank,
                    borderRadius: BorderRadius.vertical(
                      bottom: Radius.circular(4),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 30),
          Text(
            '아직 받은 테이프가 없어요',
            style: AppText.suit(800, 20, letterSpacingEm: -.02),
          ),
          const SizedBox(height: 8),
          Text(
            '친구에게 먼저 보내면 답장이 여기로 와요',
            textAlign: TextAlign.center,
            style: AppText.suit(500, 14, height: 1.5, color: AppColors.textSub),
          ),
          const SizedBox(height: 26),
          Tappable(
            onTap: onGoRecord,
            child: Container(
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 22),
              decoration: BoxDecoration(
                color: AppColors.ink,
                borderRadius: BorderRadius.circular(AppRadius.button),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 9,
                    height: 9,
                    decoration: const BoxDecoration(
                      color: AppColors.red,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '녹음하러 가기',
                    style: AppText.suit(700, 15, color: AppColors.paper),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 1.5px 점선 등 (radius 3 3 1 1, `#CFC6B5`)
class _DashedSpine extends CustomPainter {
  const _DashedSpine();

  @override
  void paint(Canvas canvas, Size size) {
    final r = RRect.fromRectAndCorners(
      (Offset.zero & size).deflate(.75),
      topLeft: const Radius.circular(3),
      topRight: const Radius.circular(3),
      bottomLeft: const Radius.circular(1),
      bottomRight: const Radius.circular(1),
    );
    final paint = Paint()
      ..color = AppColors.shelfDash
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final path = Path()..addRRect(r);
    for (final m in path.computeMetrics()) {
      for (var d = 0.0; d < m.length; d += 7) {
        canvas.drawPath(m.extractPath(d, d + 4), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DashedSpine old) => false;
}

/// "+ 칸 추가" (52, `#F6F6F4`)
class _AddGroupButton extends StatelessWidget {
  const _AddGroupButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tappable(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 18, 12, 0),
        height: 52,
        decoration: BoxDecoration(
          color: AppColors.surfaceSoft,
          borderRadius: BorderRadius.circular(AppRadius.row),
        ),
        alignment: Alignment.center,
        child: Text('+ 칸 추가', style: AppText.suit(700, 14)),
      ),
    );
  }
}

/// "서랍이 거의 찼어요 · 넓히기 ›" (`capOn`)
class _NearFull extends StatelessWidget {
  const _NearFull({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tappable(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.row),
          border: Border.all(color: AppColors.line, width: 1.5),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('서랍이 거의 찼어요', style: AppText.suit(700, 14)),
            Text('넓히기 ›', style: AppText.suit(700, 13, color: AppColors.red)),
          ],
        ),
      ),
    );
  }
}

/// 서랍 스켈레톤 (`skShelf`) — 탭에 처음 들어갈 때 0.65초.
class ShelfSkeleton extends StatefulWidget {
  const ShelfSkeleton({super.key});

  @override
  State<ShelfSkeleton> createState() => _ShelfSkeletonState();
}

class _ShelfSkeletonState extends State<ShelfSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  static Widget _bar(double w, double h, Color c, [double r = 6]) => Container(
    width: w,
    height: h,
    decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(r)),
  );

  Widget _row() => AnimatedBuilder(
    animation: _c,
    builder: (context, child) {
      // skel: 0%,100% opacity 1 · 50% opacity .45 (ease-in-out)
      final t = _c.value;
      final k = Curves.easeInOut.transform(t < .5 ? t * 2 : (1 - t) * 2);
      return Opacity(opacity: 1 - .55 * k, child: child);
    },
    child: SizedBox(
      height: 60,
      child: Row(
        children: [
          _bar(48, 32, AppColors.line, 4),
          const SizedBox(width: 14),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _bar(92, 13, AppColors.line),
              const SizedBox(height: 7),
              _bar(140, 10, AppColors.skeletonLight),
            ],
          ),
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.paper,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 14, 24, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _bar(84, 16, AppColors.line),
            const SizedBox(height: 8),
            _row(),
            _row(),
            _row(),
            const SizedBox(height: 22),
            _bar(110, 16, AppColors.line),
            const SizedBox(height: 8),
            _row(),
            _row(),
          ],
        ),
      ),
    );
  }
}
