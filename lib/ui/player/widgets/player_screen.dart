import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../domain/models/tape_repeat.dart';
import '../../../domain/models/tape_item.dart';
import '../../../domain/models/tape_type.dart';
import '../../../utils/format.dart';
import '../../core/themes/colors.dart';
import '../../core/themes/dimens.dart';
import '../../core/themes/tape_palette.dart';
import '../../core/themes/text_styles.dart';
import '../../core/ui/animations.dart';
import '../../core/ui/app_icons.dart';
import '../../core/ui/css_paint.dart';
import '../../core/ui/grain_overlay.dart';
import '../../core/ui/mini_tape.dart';
import '../../core/ui/tape_motion.dart';
import '../../core/ui/tape_widget.dart';
import '../view_model/player_view_model.dart';
import '../../core/ui/tappable.dart';

/// 테이프 재생 오버레이 — 템플릿 `viewerOn` 블록 (`vParcel` / `vPlay`).
class PlayerScreen extends StatelessWidget {
  const PlayerScreen({
    super.key,
    required this.viewModel,
    required this.onClose,
    this.onMore,
  });

  final PlayerViewModel viewModel;
  final VoidCallback onClose;

  /// 재생 중 왼쪽 위 ⋯ (`vMore`) — 답장·신고
  final VoidCallback? onMore;

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
            return Column(
              children: [
                SizedBox(
                  height: AppSizes.backBar,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      children: [
                        if (vm.phase == ViewerPhase.play && onMore != null)
                          _MoreButton(onTap: onMore!),
                        const Spacer(),
                        Semantics(
                          button: true,
                          label: '닫기',
                          excludeSemantics: true,
                          child: Tappable(
                            behavior: HitTestBehavior.opaque,
                            onTap: onClose,
                            child: SizedBox.square(
                              dimension: AppSizes.minTap,
                              child: Center(
                                child: Text(
                                  '✕',
                                  style: AppText.suit(400, 22, height: 1),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: vm.phase == ViewerPhase.play
                      ? _PlayView(vm: vm)
                      : _ParcelView(vm: vm),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ── 소포 (`vParcel`) ──────────────────────────────────
class _ParcelView extends StatelessWidget {
  const _ParcelView({required this.vm});

  final PlayerViewModel vm;

  @override
  Widget build(BuildContext context) {
    final item = vm.current;
    if (item == null) return const SizedBox.shrink();
    final tearing = vm.phase == ViewerPhase.tearing;
    return Tappable(
      behavior: HitTestBehavior.opaque,
      onTap: vm.unwrap,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 80),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (vm.showLinkChip) ...[
              FadeUp(
                duration: const Duration(milliseconds: 400),
                child: Container(
                  height: 36,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Center(
                    widthFactor: 1,
                    child: Text(
                      '${item.from}님과 친구가 되었어요',
                      style: AppText.suit(700, 14),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 30),
            ],
            _Shake(
              active: !tearing,
              child: SizedBox(
                width: 260,
                height: 190,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned(
                      left: 0,
                      top: 0,
                      bottom: 0,
                      width: 130,
                      child: _Tear(
                        active: tearing,
                        left: true,
                        child: const _Half(left: true),
                      ),
                    ),
                    Positioned(
                      right: 0,
                      top: 0,
                      bottom: 0,
                      width: 130,
                      child: _Tear(
                        active: tearing,
                        left: false,
                        child: _Half(left: false, from: item.from),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 30),
            Opacity(
              opacity: tearing ? 0 : 1,
              child: Text(
                '탭해서 뜯기',
                style: AppText.suit(700, 15, color: AppColors.textMuted),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 소포 반쪽 (왼쪽 `#D2AB72→#C29558`, 오른쪽 `#C9A066→#B98B4F` + 보낸 사람 메모)
class _Half extends StatelessWidget {
  const _Half({required this.left, this.from});

  final bool left;
  final String? from;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _HalfPainter(left),
      child: from == null
          ? const SizedBox.expand()
          : Stack(
              children: [
                Positioned(
                  right: 14,
                  bottom: 16,
                  width: 92,
                  child: Transform.rotate(
                    angle: -3 * math.pi / 180,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: 9,
                        horizontal: 10,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.paper,
                        borderRadius: BorderRadius.circular(3),
                        boxShadow: AppShadows.memo,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '보낸 사람',
                            style: AppText.suit(
                              600,
                              10,
                              color: AppColors.textMuted,
                            ),
                          ),
                          Text(
                            from!,
                            maxLines: 1,
                            softWrap: false,
                            overflow: TextOverflow.clip,
                            style: AppText.suit(800, 15),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _HalfPainter extends CustomPainter {
  _HalfPainter(this.left);

  final bool left;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    const r8 = Radius.circular(8);
    final rr = left
        ? RRect.fromRectAndCorners(rect, topLeft: r8, bottomLeft: r8)
        : RRect.fromRectAndCorners(rect, topRight: r8, bottomRight: r8);
    canvas.save();
    canvas.clipRRect(rr);
    canvas.drawRect(
      rect,
      Paint()
        ..shader = CssPaint.linearGradient(
          rect,
          135,
          left
              ? const [AppColors.kraftLight, AppColors.kraftDark]
              : const [AppColors.kraftRightLight, AppColors.kraftRightDark],
        ),
    );
    final tape = Paint()
      ..color = left ? AppColors.kraftTape : AppColors.flapTape;
    canvas.drawRect(
      Rect.fromLTWH(left ? size.width - 10 : 0, 0, 10, size.height),
      tape,
    );
    canvas.drawRect(Rect.fromLTWH(0, 88, size.width, 12), tape);
    canvas.restore();
    CssPaint.insetShadow(
      canvas,
      rr,
      spread: 1,
      color: AppColors.ink.withValues(alpha: .06),
    );
  }

  @override
  bool shouldRepaint(_HalfPainter old) => old.left != left;
}

/// `@keyframes shake` 2.2s ease-in-out infinite
class _Shake extends StatefulWidget {
  const _Shake({required this.active, required this.child});

  final bool active;
  final Widget child;

  @override
  State<_Shake> createState() => _ShakeState();
}

class _ShakeState extends State<_Shake> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  );

  @override
  void initState() {
    super.initState();
    if (widget.active) _c.repeat();
  }

  @override
  void didUpdateWidget(_Shake old) {
    super.didUpdateWidget(old);
    if (widget.active && !_c.isAnimating) _c.repeat();
    if (!widget.active && _c.isAnimating) _c.reset();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) {
        final deg = keyframes(
          _c.value,
          const [0, .7, .75, .8, .85, .9, 1],
          const [0, 0, -3, 3, -2, 2, 0],
          curve: Curves.easeInOut,
        );
        return Transform.rotate(angle: deg * math.pi / 180, child: child);
      },
      child: widget.child,
    );
  }
}

/// `tearL` / `tearR` .7s cubic-bezier(.5,0,.7,.4) forwards
class _Tear extends StatefulWidget {
  const _Tear({required this.active, required this.left, required this.child});

  final bool active;
  final bool left;
  final Widget child;

  @override
  State<_Tear> createState() => _TearState();
}

class _TearState extends State<_Tear> with SingleTickerProviderStateMixin {
  static const _curve = Cubic(.5, 0, .7, .4);
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  );

  @override
  void initState() {
    super.initState();
    if (widget.active) _c.forward();
  }

  @override
  void didUpdateWidget(_Tear old) {
    super.didUpdateWidget(old);
    if (widget.active && !old.active) _c.forward(from: 0);
    if (!widget.active && old.active) _c.reset();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sign = widget.left ? -1.0 : 1.0;
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) {
        final k = _curve.transform(_c.value);
        return Opacity(
          opacity: 1 - k,
          child: Transform(
            alignment: Alignment.center,
            transform: Matrix4.translationValues(180 * sign * k, 60 * k, 0)
              ..rotateZ(24 * sign * k * math.pi / 180),
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}

// ── 재생 (`vPlay`) ───────────────────────────────────
class _PlayView extends StatelessWidget {
  const _PlayView({required this.vm});

  final PlayerViewModel vm;

  @override
  Widget build(BuildContext context) {
    final item = vm.current;
    final palette = TapePalette.of(item?.type ?? TapeType.s15);
    final p = vm.progress;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Column(
            children: [
              _Insert(
                key: ValueKey(vm.insertCount),
                child: Wobble(
                  active: vm.playing,
                  child: Stack(
                    children: [
                      TapeWidget(
                        palette: palette,
                        title: item == null
                            ? ''
                            : formatMonthDayTime(item.date),
                        packL: palette.packL(p),
                        packR: palette.packR(p),
                        spinning: vm.playing,
                        speed: 1.8,
                        from: item?.from,
                      ),
                      if (vm.playing)
                        const Positioned.fill(
                          child: GrainOverlay(mode: GrainMode.loop),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              switch (vm.load) {
                TrackLoad.loading => const _Loading(),
                TrackLoad.error => _LoadError(onRetry: vm.retry),
                TrackLoad.ready => _Controls(vm: vm),
              },
            ],
          ),
        ),
        const SizedBox(height: 20),
        Expanded(child: _Queue(vm: vm)),
      ],
    );
  }
}

/// `@keyframes insert` .7s cubic-bezier(.3,.7,.3,1) — 곡이 바뀔 때마다 다시 재생
class _Insert extends StatefulWidget {
  const _Insert({super.key, required this.child});

  final Widget child;

  @override
  State<_Insert> createState() => _InsertState();
}

class _InsertState extends State<_Insert> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  )..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) {
        final t = _c.value;
        const stops = [0.0, .6, 1.0];
        final y = keyframes(t, stops, const [
          -120,
          6,
          0,
        ], curve: AppMotion.settle);
        final deg = keyframes(t, stops, const [
          -6,
          0,
          0,
        ], curve: AppMotion.settle);
        final op = keyframes(t, stops, const [
          0,
          1,
          1,
        ], curve: AppMotion.settle);
        return Opacity(
          opacity: op.clamp(0, 1),
          child: Transform.translate(
            offset: Offset(0, y),
            child: Transform.rotate(angle: deg * math.pi / 180, child: child),
          ),
        );
      },
      child: widget.child,
    );
  }
}

/// 불러오는 중 (`vLoadingOn`, 높이 100)
class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 100,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const LoadingDots(),
          const SizedBox(height: 14),
          Text(
            '테이프를 불러오는 중이에요',
            style: AppText.suit(600, 14, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}

/// 불러오기 실패 (`vErrorOn`)
class _LoadError extends StatelessWidget {
  const _LoadError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return FadeUp(
      duration: const Duration(milliseconds: 300),
      child: SizedBox(
        height: 100,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('테이프를 불러오지 못했어요', style: AppText.suit(700, 15)),
            const SizedBox(height: 12),
            Tappable(
              onTap: onRetry,
              child: Container(
                height: 40,
                padding: const EdgeInsets.symmetric(horizontal: 18),
                decoration: BoxDecoration(
                  color: AppColors.ink,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Center(
                  widthFactor: 1,
                  child: Text(
                    '다시 시도',
                    style: AppText.suit(700, 14, color: AppColors.paper),
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

/// 진행 바(너비 280) + 컨트롤 줄(너비 300)
class _Controls extends StatelessWidget {
  const _Controls({required this.vm});

  final PlayerViewModel vm;

  @override
  Widget build(BuildContext context) {
    final label = AppText.suit(
      600,
      12,
      color: AppColors.textMuted,
      tabularNums: true,
    );
    return Column(
      children: [
        SizedBox(
          width: 280,
          child: Row(
            children: [
              Text(formatClock(vm.pos), style: label),
              const SizedBox(width: 10),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: SizedBox(
                    height: 3,
                    child: Stack(
                      children: [
                        const Positioned.fill(
                          child: ColoredBox(color: AppColors.progressTrack),
                        ),
                        FractionallySizedBox(
                          widthFactor: vm.progress,
                          heightFactor: 1,
                          child: const ColoredBox(color: AppColors.ink),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(formatClock(vm.duration), style: label),
            ],
          ),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: 300,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _RepeatButton(mode: vm.repeat, onTap: vm.cycleRepeat),
              _SkipButton(next: false, enabled: vm.canPrev, onTap: vm.prev),
              PlayButton(playing: vm.playing, onTap: vm.togglePlay),
              _SkipButton(next: true, enabled: vm.canNext, onTap: vm.next),
              SizedBox(
                width: 44,
                child: Text(
                  vm.indexText,
                  textAlign: TextAlign.center,
                  style: AppText.suit(
                    700,
                    13,
                    color: AppColors.textMuted,
                    tabularNums: true,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// 반복 44 — off는 `#C5C5C2`, one이면 작은 "1" 배지
class _RepeatButton extends StatelessWidget {
  const _RepeatButton({required this.mode, required this.onTap});

  final TapeRepeat mode;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '반복',
      value: mode.label,
      excludeSemantics: true,
      child: Tappable(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox.square(
          dimension: 44,
          child: Stack(
            alignment: Alignment.center,
            children: [
              SvgIcon(
                AppIcons.repeat,
                width: 22,
                height: 22,
                color: mode == TapeRepeat.off
                    ? AppColors.textOff
                    : AppColors.ink,
              ),
              if (mode == TapeRepeat.one)
                Positioned(
                  top: 5,
                  right: 3,
                  child: Container(
                    width: 14,
                    height: 14,
                    decoration: const BoxDecoration(
                      color: AppColors.ink,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '1',
                      style: AppText.suit(
                        800,
                        9,
                        height: 1,
                        color: AppColors.paper,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 이전·다음 44 (막대 3×16 + 삼각형 13×16). 못 누를 때 opacity .3
class _SkipButton extends StatelessWidget {
  const _SkipButton({
    required this.next,
    required this.enabled,
    required this.onTap,
  });

  final bool next;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bar = Container(
      width: 3,
      height: 16,
      decoration: BoxDecoration(
        color: AppColors.ink,
        borderRadius: BorderRadius.circular(1),
      ),
    );
    final tri = CustomPaint(
      size: const Size(13, 16),
      painter: _Triangle(pointRight: next),
    );
    return Semantics(
      button: true,
      label: next ? '다음' : '이전',
      excludeSemantics: true,
      child: Tappable(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Opacity(
          opacity: enabled ? 1 : .3,
          child: SizedBox.square(
            dimension: 44,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: next
                  ? [tri, const SizedBox(width: 1), bar]
                  : [bar, const SizedBox(width: 1), tri],
            ),
          ),
        ),
      ),
    );
  }
}

class _Triangle extends CustomPainter {
  _Triangle({required this.pointRight});

  final bool pointRight;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Path();
    if (pointRight) {
      p
        ..moveTo(0, 0)
        ..lineTo(size.width, size.height / 2)
        ..lineTo(0, size.height);
    } else {
      p
        ..moveTo(size.width, 0)
        ..lineTo(0, size.height / 2)
        ..lineTo(size.width, size.height);
    }
    canvas.drawPath(p..close(), Paint()..color = AppColors.ink);
  }

  @override
  bool shouldRepaint(_Triangle old) => old.pointRight != pointRight;
}

/// 이어 듣기 목록 (`vQueue`)
class _Queue extends StatelessWidget {
  const _Queue({required this.vm});

  final PlayerViewModel vm;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.line)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 14, 24, 6),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    vm.queueName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.suit(800, 15),
                  ),
                ),
                Text(
                  vm.repeat.label,
                  style: AppText.suit(600, 12.5, color: AppColors.textMuted),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.fromLTRB(
                12,
                0,
                12,
                24 + MediaQuery.viewPaddingOf(context).bottom,
              ),
              itemCount: vm.queue.length,
              itemBuilder: (context, i) => _QueueRow(
                item: vm.queue[i],
                on: i == vm.index,
                onTap: () => vm.goTrack(i),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QueueRow extends StatelessWidget {
  const _QueueRow({required this.item, required this.on, required this.onTap});

  final TapeItem item;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = TapePalette.of(item.type);
    return Tappable(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        height: 54,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: on ? AppColors.surfaceSoft : null,
          borderRadius: BorderRadius.circular(AppRadius.queueRow),
        ),
        child: Row(
          children: [
            MiniTape(palette: p),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.from, style: AppText.suit(700, 15)),
                  const SizedBox(height: 1),
                  Text(
                    '${formatMonthDayTime(item.date)} · ${p.name}',
                    style: AppText.suit(500, 12, color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            on
                ? Text(
                    '재생 중',
                    style: AppText.suit(700, 12, color: AppColors.red),
                  )
                : Text(
                    formatClock(item.duration.inSeconds),
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
    );
  }
}

/// 재생 화면 왼쪽 위 ⋯ (44, 점 4px 세 개, 간격 4)
class _MoreButton extends StatelessWidget {
  const _MoreButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    Widget dot() => Container(
      width: 4,
      height: 4,
      decoration: const BoxDecoration(
        color: AppColors.ink,
        shape: BoxShape.circle,
      ),
    );
    return Semantics(
      button: true,
      label: '더 보기',
      excludeSemantics: true,
      child: Tappable(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox.square(
          dimension: AppSizes.minTap,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              dot(),
              const SizedBox(width: 4),
              dot(),
              const SizedBox(width: 4),
              dot(),
            ],
          ),
        ),
      ),
    );
  }
}
