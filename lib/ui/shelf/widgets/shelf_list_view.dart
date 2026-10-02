import 'package:flutter/material.dart';

import '../../../domain/models/shelf.dart';
import '../../../domain/models/tape_item.dart';
import '../../core/themes/colors.dart';
import '../../core/themes/dimens.dart';
import '../../core/themes/tape_palette.dart';
import '../../core/themes/text_styles.dart';
import '../../core/ui/mini_tape.dart';
import '../../core/ui/parcel_box.dart';
import '../view_model/shelf_view_model.dart';
import 'shelf_drag.dart';
import '../../core/ui/tappable.dart';
import '../../core/ui/keep_all.dart';

/// 목록 보기 — 템플릿 `isList` 블록. "분류 안 함" + 사용자 칸, 드래그 정렬.
class ShelfListSections extends StatelessWidget {
  const ShelfListSections({
    super.key,
    required this.viewModel,
    required this.drag,
    required this.onOpen,
    required this.onMore,
    required this.onEditGroup,
  });

  final ShelfViewModel viewModel;
  final ShelfDragController drag;
  final void Function(TapeItem item) onOpen;
  final void Function(TapeItem item) onMore;
  final void Function(ShelfGroup group) onEditGroup;

  @override
  Widget build(BuildContext context) {
    final vm = viewModel;
    final s = vm.shelf;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 10, bottom: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 도착한 소포 (v10.2) — 안 뜯은 소포가 있을 때만
              if (vm.parcels.isNotEmpty)
                ParcelSection(
                  count: vm.parcels.length,
                  padding: const EdgeInsets.fromLTRB(0, 12, 0, 6),
                  headerPadding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final x in vm.parcels)
                        ShelfRow(
                          key: ValueKey(x.id),
                          item: x,
                          sub: vm.parcelSub(x),
                          pressedColor: AppColors.parcelPressed,
                          onTap: () => onOpen(x),
                          onMore: () => onMore(x),
                        ),
                    ],
                  ),
                ),
              DropZone(
                controller: drag,
                target: const DropTarget(null, 0),
                child: SectionHeader(
                  name: ShelfViewModel.unsortedName,
                  count: vm.unsortedCountText,
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
                ),
              ),
              // 분류 안 함: 뜯은 테이프만. 드롭 위치는 원래 `unsorted` 인덱스
              ..._unsortedRows(),
              if (vm.openedUnsorted.isEmpty)
                _EmptyZone(
                  drag: drag,
                  groupId: null,
                  on: vm.dropTarget?.groupId == null && vm.dropTarget != null,
                  text: '뜯은 테이프 중 칸에 넣지 않은 테이프가 여기 모여요',
                ),
            ],
          ),
        ),
        for (final g in s.groups)
          Padding(
            padding: const EdgeInsets.only(top: 14, bottom: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DropZone(
                  controller: drag,
                  target: DropTarget(g.id, 0),
                  child: Tappable(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => onEditGroup(g),
                    child: SectionHeader(
                      name: g.name,
                      count: vm.groupCountText(g),
                      groupCount: true,
                      countFull: vm.groupFull(g),
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
                    ),
                  ),
                ),
                ..._rows(g.id, g.items),
                if (g.items.isEmpty)
                  _EmptyZone(
                    drag: drag,
                    groupId: g.id,
                    on: vm.dropTarget?.groupId == g.id,
                    text: '아직 비어 있어요',
                  ),
              ],
            ),
          ),
      ],
    );
  }

  List<Widget> _unsortedRows() {
    final t = viewModel.dropTarget;
    final n = viewModel.shelf.unsorted.length;
    return [
      for (final (i, x) in viewModel.openedUnsorted)
        DropZone(
          key: ValueKey(x.id),
          controller: drag,
          target: DropTarget(null, i),
          row: true,
          child: ShelfRow(
            item: x,
            sub: viewModel.itemSub(x),
            dimmed: viewModel.draggingId == x.id,
            landed: viewModel.landedId == x.id,
            lineTop: t == DropTarget(null, i),
            lineBottom: i == n - 1 && t == DropTarget(null, n),
            drag: drag,
            onTap: () => onOpen(x),
            onMore: () => onMore(x),
          ),
        ),
    ];
  }

  List<Widget> _rows(String? groupId, List<TapeItem> items) {
    final t = viewModel.dropTarget;
    return [
      for (var i = 0; i < items.length; i++)
        DropZone(
          key: ValueKey(items[i].id),
          controller: drag,
          target: DropTarget(groupId, i),
          row: true,
          child: ShelfRow(
            item: items[i],
            sub: viewModel.itemSub(items[i]),
            dimmed: viewModel.draggingId == items[i].id,
            landed: viewModel.landedId == items[i].id,
            lineTop: t == DropTarget(groupId, i),
            lineBottom:
                i == items.length - 1 && t == DropTarget(groupId, items.length),
            drag: drag,
            onTap: () => onOpen(items[i]),
            onMore: () => onMore(items[i]),
          ),
        ),
    ];
  }
}

/// 칸 제목 `800 17px` + 오른쪽 개수. 분류 안 함은 `600 13px #A5A5A2` "n개",
/// 칸은 `700 13px` tabular `n/10`, 꽉 차면 레드 `10/10 · 꽉 참` (`groupList.count`).
/// 분류 안 함에는 "새 테이프 N" 알약.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.name,
    required this.count,
    this.newCount = 0,
    this.groupCount = false,
    this.countFull = false,
    required this.padding,
  });

  final String name;
  final String count;

  /// 사용자 칸의 `n/10` (700). 분류 안 함은 false.
  final bool groupCount;
  final bool countFull;
  final int newCount;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.section,
                  ),
                ),
                if (newCount > 0) ...[
                  const SizedBox(width: 8),
                  Container(
                    height: 22,
                    padding: const EdgeInsets.symmetric(horizontal: 9),
                    decoration: BoxDecoration(
                      color: AppColors.redTint,
                      borderRadius: BorderRadius.circular(11),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      keepAll('새 테이프 $newCount'),
                      style: AppText.suit(700, 12, color: AppColors.red),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            count,
            style: AppText.suit(
              groupCount ? 700 : 600,
              13,
              tabularNums: groupCount,
              color: countFull ? AppColors.red : AppColors.textCount,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyZone extends StatelessWidget {
  const _EmptyZone({
    required this.drag,
    required this.groupId,
    required this.on,
    required this.text,
  });

  final ShelfDragController drag;
  final String? groupId;
  final bool on;
  final String text;

  @override
  Widget build(BuildContext context) {
    return DropZone(
      controller: drag,
      target: DropTarget(groupId, 0),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        constraints: const BoxConstraints(minHeight: 52),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        alignment: Alignment.centerLeft,
        decoration: BoxDecoration(
          color: on
              ? AppColors.redTint
              : AppColors.redTint.withValues(alpha: 0),
          borderRadius: BorderRadius.circular(AppRadius.row),
        ),
        child: Text(
          keepAll(text),
          style: AppText.suit(500, 13.5, color: AppColors.textFaint),
        ),
      ),
    );
  }
}

/// 목록 행 60: 미니 테이프(안 뜯은 소포는 크라프트 박스), 이름, 부제, 새 테이프 레드 점, ⋯.
class ShelfRow extends StatefulWidget {
  const ShelfRow({
    super.key,
    required this.item,
    required this.sub,
    required this.onTap,
    required this.onMore,
    this.drag,
    this.dimmed = false,
    this.landed = false,
    this.lineTop = false,
    this.lineBottom = false,
    this.pressedColor = AppColors.surfaceSoft,
  });

  final TapeItem item;
  final String sub;

  /// 누른 행 바탕 (`hover`) — 도착한 소포 구역은 `#F5EEE2`
  final Color pressedColor;
  final VoidCallback onTap;
  final VoidCallback onMore;

  /// 드래그할 수 있으면 컨트롤러 (안 뜯은 소포는 null)
  final ShelfDragController? drag;

  /// 끌리는 중인 행 (opacity .3)
  final bool dimmed;

  /// 옮긴 직후 `flash 1.2s`
  final bool landed;
  final bool lineTop;
  final bool lineBottom;

  @override
  State<ShelfRow> createState() => _ShelfRowState();
}

class _ShelfRowState extends State<ShelfRow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _flash = AnimationController(
    vsync: this,
    duration: ShelfViewModel.landTime,
  );
  bool _pressed = false;

  @override
  void initState() {
    super.initState();
    if (widget.landed) _flash.forward();
  }

  @override
  void didUpdateWidget(ShelfRow old) {
    super.didUpdateWidget(old);
    if (widget.landed && !old.landed) _flash.forward(from: 0);
  }

  @override
  void dispose() {
    _flash.dispose();
    super.dispose();
  }

  /// `@keyframes flash{0%,60%{background:#FDECE9}100%{background:transparent}}`
  Color _bg() {
    if (_flash.isAnimating) {
      final t = _flash.value;
      if (t <= .6) return AppColors.redTint;
      final k = Curves.ease.transform((t - .6) / .4);
      return AppColors.redTint.withValues(alpha: 1 - k);
    }
    return _pressed
        ? widget.pressedColor
        : widget.pressedColor.withValues(alpha: 0);
  }

  @override
  Widget build(BuildContext context) {
    final x = widget.item;
    final isNew = x.groupId == null && !x.opened;
    final row = AnimatedBuilder(
      animation: _flash,
      builder: (context, child) => Container(
        // 큰 글씨(v10.4): 최소 높이 60
        constraints: const BoxConstraints(minHeight: AppSizes.row),
        padding: const EdgeInsets.only(left: 12, right: 4),
        decoration: BoxDecoration(
          color: _bg(),
          borderRadius: BorderRadius.circular(AppRadius.row),
        ),
        child: child,
      ),
      child: Row(
        children: [
          isNew
              ? const MiniParcel()
              : MiniTape(palette: TapePalette.of(x.type)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  x.from,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.rowTitle,
                ),
                const SizedBox(height: 2),
                // 메모(최대 40자)가 붙으면 길어진다 — 한 줄로 줄인다
                Text(
                  widget.sub,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.caption,
                ),
              ],
            ),
          ),
          if (isNew) ...[
            const SizedBox(width: 14),
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: AppColors.red,
                shape: BoxShape.circle,
              ),
            ),
          ],
          const SizedBox(width: 14),
          MoreButton(onTap: widget.onMore),
        ],
      ),
    );

    final content = Stack(
      clipBehavior: Clip.none,
      children: [
        Opacity(opacity: widget.dimmed ? .3 : 1, child: row),
        _DropLine(top: true, on: widget.lineTop),
        _DropLine(top: false, on: widget.lineBottom),
      ],
    );

    final drag = widget.drag;
    if (drag == null) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: Haptic.selection.wrap(widget.onTap),
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        child: content,
      );
    }
    return Listener(
      onPointerDown: (_) => setState(() => _pressed = true),
      onPointerUp: (_) => setState(() => _pressed = false),
      onPointerCancel: (_) => setState(() => _pressed = false),
      child: DragRowGestures(
        controller: drag,
        item: x,
        onTap: widget.onTap,
        child: content,
      ),
    );
  }
}

/// 2px 레드 드롭 표시선 (left 12, right 12)
class _DropLine extends StatelessWidget {
  const _DropLine({required this.top, required this.on});

  final bool top;
  final bool on;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 12,
      right: 12,
      top: top ? -1 : null,
      bottom: top ? null : -1,
      height: 2,
      child: IgnorePointer(
        child: Opacity(
          opacity: on ? 1 : 0,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: AppColors.red,
              borderRadius: BorderRadius.circular(1),
            ),
          ),
        ),
      ),
    );
  }
}

/// ⋯ 버튼 (36×44, 점 3.5px `#9A9A97`, 간격 3). 길게 눌러도 드래그가 시작되지 않는다.
class MoreButton extends StatelessWidget {
  const MoreButton({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '더 보기',
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: Haptic.selection.wrap(onTap),
        onLongPress: () {},
        child: SizedBox(
          width: 36,
          height: 44,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < 3; i++) ...[
                if (i > 0) const SizedBox(width: 3),
                Container(
                  width: 3.5,
                  height: 3.5,
                  decoration: const BoxDecoration(
                    color: AppColors.textMuted,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// 드래그 고스트 카드 — 흰 바탕, −1.5° 회전, scale 1.03 (z 45).
class DragGhost extends StatelessWidget {
  const DragGhost({super.key, required this.item, required this.sub});

  final TapeItem item;
  final String sub;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Transform.rotate(
        angle: -1.5 * 3.141592653589793 / 180,
        child: Transform.scale(
          scale: 1.03,
          child: Container(
            height: AppSizes.row,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: AppColors.paper,
              borderRadius: BorderRadius.circular(AppRadius.row),
              boxShadow: AppShadows.dragGhost,
            ),
            child: Row(
              children: [
                MiniTape(palette: TapePalette.of(item.type)),
                const SizedBox(width: 14),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.from, style: AppText.rowTitle),
                    const SizedBox(height: 2),
                    Text(sub, style: AppText.caption),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 도착한 소포 구역 카드 (v10.2): `#FBF9F5` + `inset 0 0 0 1px #EFE4CF`, radius 18, 아래 여백 14.
/// 머리: 레드 점 8 + "도착한 소포" `800 17` / 오른쪽 "N개" `700 13` 레드, 안내 "눌러서 뜯어 주세요".
class ParcelSection extends StatelessWidget {
  const ParcelSection({
    super.key,
    required this.count,
    required this.padding,
    required this.headerPadding,
    required this.child,
    this.margin = const EdgeInsets.only(bottom: 14),
  });

  final int count;

  /// 카드 안 여백 (목록 12 0 6, 선반 12 12 8)
  final EdgeInsets padding;

  /// 머리·안내 줄 좌우 여백 (목록은 행과 맞춰 12)
  final EdgeInsets headerPadding;
  final EdgeInsets margin;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.parcelCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.parcelStroke),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: headerPadding.add(
              const EdgeInsets.only(bottom: 2),
            ) as EdgeInsets,
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: AppColors.red,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    keepAll('도착한 소포'),
                    style: AppText.section,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '$count개',
                  style: AppText.suit(
                    700,
                    13,
                    tabularNums: true,
                    color: AppColors.red,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: headerPadding.add(
              const EdgeInsets.only(bottom: 6),
            ) as EdgeInsets,
            child: Text(
              keepAll('눌러서 뜯어 주세요'),
              style: AppText.suit(
                500,
                12.5,
                height: 1.4,
                color: AppColors.textMuted,
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}
