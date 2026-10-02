import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../themes/colors.dart';
import '../themes/dimens.dart';
import '../themes/tape_palette.dart';
import '../themes/text_styles.dart';
import 'css_paint.dart';
import 'keep_all.dart';

/// 카세트테이프 — source/Tape.template.html + Tape.logic.js (320×204 고정).
///
/// | prop | 뜻 |
/// |---|---|
/// | [palette] | 케이스·아래 사다리꼴·라벨 윗띠 색과 `15 SEC` 글자 |
/// | [title] | 라벨 첫 줄 |
/// | [packL] / [packR] | 왼쪽·오른쪽 릴에 감긴 테이프 지름(px), 0.3초 linear로 바뀐다 |
/// | [spinning] / [speed] | 릴 회전 여부와 한 바퀴 시간(초) |
/// | [from] / [to] | 있으면 오른쪽 위에 흰 라벨 카드(보낸 사람 / 받는 사람) |
class TapeWidget extends StatefulWidget {
  const TapeWidget({
    super.key,
    this.palette = TapePalette.s15,
    this.title = '',
    this.packL = 64,
    this.packR = 30,
    this.spinning = false,
    this.speed = 1.4,
    this.from,
    this.to,
  });

  final TapePalette palette;
  final String title;
  final double packL;
  final double packR;
  final bool spinning;
  final double speed;
  final String? from;

  /// null이면 받는 사람 칸을 그리지 않는다. 빈 문자열이면 칸만 그린다.
  final String? to;

  static const size = AppSizes.tape;

  @override
  State<TapeWidget> createState() => _TapeWidgetState();
}

class _TapeWidgetState extends State<TapeWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _spin = AnimationController(
    vsync: this,
    duration: _spinDuration,
  );

  Duration get _spinDuration =>
      Duration(milliseconds: (widget.speed * 1000).round());

  @override
  void initState() {
    super.initState();
    if (widget.spinning) _spin.repeat();
  }

  @override
  void didUpdateWidget(TapeWidget old) {
    super.didUpdateWidget(old);
    if (old.speed != widget.speed) _spin.duration = _spinDuration;
    if (widget.spinning && !_spin.isAnimating) {
      _spin.repeat();
    } else if (!widget.spinning && _spin.isAnimating) {
      // CSS에서 animation:none이 되면 처음 각도로 돌아간다.
      _spin.reset();
    }
  }

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.palette;
    // 테이프 그림은 시스템 글자 크기와 상관없이 고정 (v10.4)
    return MediaQuery.withNoTextScaling(child: _tape(p));
  }

  Widget _tape(TapePalette p) {
    return SizedBox.fromSize(
      size: TapeWidget.size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                boxShadow: AppShadows.tape,
              ),
              child: TweenAnimationBuilder<Offset>(
                tween: Tween(end: Offset(widget.packL, widget.packR)),
                duration: const Duration(milliseconds: 300),
                builder: (context, pack, _) => AnimatedBuilder(
                  animation: _spin,
                  builder: (context, _) => CustomPaint(
                    painter: TapeBodyPainter(
                      palette: p,
                      packL: pack.dx,
                      packR: pack.dy,
                      hubAngle: _spin.value * 2 * math.pi,
                    ),
                  ),
                ),
              ),
            ),
          ),
          // 라벨 윗띠: A · 15 SEC
          Positioned(
            left: 24,
            right: 24,
            top: 12,
            height: 22,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('A', style: _t(800, 12, AppColors.paper)),
                Text(p.len, style: _t(700, 10.5, AppColors.paper, ls: .06)),
              ],
            ),
          ),
          // 라벨 제목 (밑줄 위 4px)
          Positioned(
            left: 26,
            right: 26,
            top: 38,
            height: 18,
            child: Align(
              alignment: Alignment.bottomLeft,
              child: Text(
                widget.title,
                maxLines: 1,
                overflow: TextOverflow.clip,
                style: _t(600, 13, TapeInk.title),
              ),
            ),
          ),
          // NR · TYPE I · NORMAL
          Positioned(
            left: 26,
            right: 26,
            top: 135,
            height: 7,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('NR', style: _t(600, 7, TapeInk.fine, ls: .12)),
                Text(
                  'TYPE I · NORMAL',
                  style: _t(600, 7, TapeInk.fine, ls: .12),
                ),
              ],
            ),
          ),
          if (widget.from != null)
            Positioned(
              right: -10,
              top: -22,
              child: TapeNote(from: widget.from!, to: widget.to),
            ),
        ],
      ),
    );
  }

  static TextStyle _t(int w, double size, Color color, {double ls = 0}) =>
      AppText.suit(w, size, height: 1, color: color, letterSpacingEm: ls);
}

/// 테이프 오른쪽 위의 흰 라벨 카드 (받는 사람 / 보낸 사람).
class TapeNote extends StatelessWidget {
  const TapeNote({super.key, required this.from, this.to});

  final String from;
  final String? to;

  @override
  Widget build(BuildContext context) {
    final hasTo = to != null;
    final caption = AppText.suit(
      600,
      10,
      height: 1,
      color: AppColors.textMuted,
    );
    return Container(
      constraints: const BoxConstraints(minWidth: 104),
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
      decoration: BoxDecoration(
        color: AppColors.paper,
        borderRadius: BorderRadius.circular(10),
        boxShadow: AppShadows.label,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (hasTo) ...[
            Text(keepAll('받는 사람'), style: caption),
            const SizedBox(height: 4),
            ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 20),
              child: Text(
                to!,
                style: AppText.suit(
                  800,
                  17,
                  height: 1.2,
                  letterSpacingEm: -.02,
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
          Text(keepAll('보낸 사람'), style: caption),
          const SizedBox(height: 4),
          Text(
            from,
            style: hasTo
                ? AppText.suit(700, 13, height: 1.2, letterSpacingEm: -.02)
                : AppText.suit(800, 17, height: 1.2, letterSpacingEm: -.02),
          ),
        ],
      ),
    );
  }
}

/// 테이프 본체의 CSS 도형을 그대로 옮긴 페인터. 좌표는 원본 px과 같다.
class TapeBodyPainter extends CustomPainter {
  TapeBodyPainter({
    required this.palette,
    required this.packL,
    required this.packR,
    required this.hubAngle,
  });

  final TapePalette palette;
  final double packL;
  final double packR;
  final double hubAngle;

  static const _white = AppColors.paper;
  static const _black = AppColors.black;

  @override
  void paint(Canvas canvas, Size size) {
    _shell(canvas);
    _label(canvas);
    _window(canvas);
    _edge(canvas);
    for (final o in const [
      Offset(6, 4),
      Offset(305, 4),
      Offset(6, 189),
      Offset(305, 189),
      Offset(155.5, 169),
    ]) {
      _screw(canvas, o);
    }
    for (final x in const [4.0, 310.0]) {
      final r = Rect.fromLTWH(x, 60, 6, 56);
      canvas.save();
      canvas.clipRRect(RRect.fromRectAndRadius(r, const Radius.circular(2)));
      CssPaint.stripes(
        canvas,
        r,
        line: 2,
        period: 5,
        color: _white.withValues(alpha: .12),
        vertical: true,
      );
      canvas.restore();
    }
  }

  void _shell(Canvas canvas) {
    final shell = RRect.fromRectAndRadius(
      const Rect.fromLTWH(0, 0, 320, 204),
      const Radius.circular(10),
    );
    canvas.drawRRect(shell, Paint()..color = palette.shell);
    CssPaint.insetShadow(
      canvas,
      shell,
      offset: const Offset(0, 1),
      color: _white.withValues(alpha: .22),
    );
    CssPaint.insetShadow(
      canvas,
      shell,
      offset: const Offset(0, -2),
      color: _black.withValues(alpha: .22),
    );
    CssPaint.insetShadow(
      canvas,
      shell,
      offset: const Offset(1, 0),
      color: _white.withValues(alpha: .08),
    );
  }

  void _label(Canvas canvas) {
    final label = RRect.fromRectAndRadius(
      const Rect.fromLTWH(14, 12, 292, 134),
      const Radius.circular(6),
    );
    CssPaint.ring(canvas, label, 1, _black.withValues(alpha: .06));
    canvas.drawRRect(label, Paint()..color = AppColors.labelPaper);
    canvas.save();
    canvas.clipRRect(label);
    canvas.drawRect(
      const Rect.fromLTWH(14, 12, 292, 22),
      Paint()..color = palette.band,
    );
    final line = Paint()..color = TapeInk.labelLine;
    // 제목 줄: top 26 + height 22 아래의 border-bottom 1px
    canvas.drawRect(const Rect.fromLTWH(26, 60, 268, 1), line);
    canvas.drawRect(const Rect.fromLTWH(26, 135, 268, 1), line);
    canvas.restore();
  }

  void _window(Canvas canvas) {
    const rect = Rect.fromLTWH(72, 62, 176, 56);
    final win = RRect.fromRectAndRadius(rect, const Radius.circular(9));
    CssPaint.ring(canvas, win, 5, palette.shell);
    canvas.drawRRect(
      win,
      Paint()
        ..shader = CssPaint.linearGradient(rect, 180, const [
          TapeInk.windowTop,
          TapeInk.windowBottom,
        ]),
    );
    CssPaint.insetShadow(
      canvas,
      win,
      offset: const Offset(0, 2),
      blur: 6,
      color: _black.withValues(alpha: .7),
    );
    canvas.save();
    canvas.clipRRect(win);
    _reel(canvas, const Offset(102, 90), packL);
    _reel(canvas, const Offset(218, 90), packR);

    // 가운데 창
    final glass = RRect.fromRectAndRadius(
      const Rect.fromLTWH(128, 71, 64, 38),
      const Radius.circular(2),
    );
    canvas.drawRRect(glass, Paint()..color = _white.withValues(alpha: .07));
    canvas.drawRRect(
      glass.deflate(.5),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = _white.withValues(alpha: .1),
    );
    CssPaint.stripes(
      canvas,
      const Rect.fromLTWH(132, 75, 56, 5),
      line: 1,
      period: 7,
      color: _white.withValues(alpha: .45),
    );
    CssPaint.stripes(
      canvas,
      const Rect.fromLTWH(132, 102, 56, 3),
      line: 1,
      period: 7,
      color: _white.withValues(alpha: .3),
    );

    _hub(canvas, const Offset(102, 90));
    _hub(canvas, const Offset(218, 90));

    // 유리 반사
    canvas.drawRect(
      rect,
      Paint()
        ..shader = CssPaint.linearGradient(
          rect,
          165,
          [_white.withValues(alpha: .16), _white.withValues(alpha: 0)],
          const [0, .4],
        ),
    );
    canvas.restore();
  }

  void _reel(Canvas canvas, Offset c, double d) {
    final r = d / 2;
    canvas.drawCircle(c, r + 1, Paint()..color = _black.withValues(alpha: .4));
    final rect = Rect.fromCircle(center: c, radius: r);
    // radial-gradient(circle, …)의 기본 크기는 farthest-corner(= r·√2)다.
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = const RadialGradient(
          radius: math.sqrt2 / 2,
          colors: [
            TapeInk.reel0,
            TapeInk.reel0,
            TapeInk.reel1,
            TapeInk.reel2,
            TapeInk.reel3,
          ],
          stops: [0, .38, .62, .90, 1],
        ).createShader(rect),
    );
  }

  void _hub(Canvas canvas, Offset c) {
    canvas.drawCircle(c, 14, Paint()..color = TapeInk.hub);
    canvas.drawCircle(
      c,
      13.5,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = _black.withValues(alpha: .2),
    );
    canvas.drawCircle(c, 8, Paint()..color = TapeInk.hubCore);
    final tooth = Paint()..color = TapeInk.hub;
    for (var k = 0; k < 6; k++) {
      canvas.save();
      canvas.translate(c.dx, c.dy);
      canvas.rotate(hubAngle + k * math.pi / 3);
      canvas.drawRect(const Rect.fromLTWH(-1.5, -9, 3, 5), tooth);
      canvas.restore();
    }
  }

  void _edge(Canvas canvas) {
    const o = Offset(62, 164);
    final trap = Path()
      ..moveTo(62 + 196 * .07, 164)
      ..lineTo(62 + 196 * .93, 164)
      ..lineTo(258, 204)
      ..lineTo(62, 204)
      ..close();
    canvas.save();
    canvas.clipPath(trap);
    canvas.drawRect(
      const Rect.fromLTWH(62, 164, 196, 40),
      Paint()..color = palette.edge,
    );
    canvas.drawRect(
      const Rect.fromLTWH(62, 164, 196, 1),
      Paint()..color = _white.withValues(alpha: .12),
    );
    canvas.translate(o.dx, o.dy);
    final dark = Paint()..color = TapeInk.tooth;
    final brown = Paint()..color = TapeInk.toothBrown;
    const top2 = Radius.circular(2);
    RRect topRound(Rect r) =>
        RRect.fromRectAndCorners(r, topLeft: top2, topRight: top2);

    canvas.drawRRect(topRound(const Rect.fromLTWH(82, 28, 32, 12)), dark);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(91, 31, 14, 4),
        const Radius.circular(1),
      ),
      Paint()..color = TapeInk.toothLight,
    );
    canvas.drawRect(const Rect.fromLTWH(82, 36, 32, 2), brown);
    for (final r in const [
      Rect.fromLTWH(52, 31, 12, 9),
      Rect.fromLTWH(132, 31, 12, 9),
      Rect.fromLTWH(24, 32, 10, 8),
      Rect.fromLTWH(162, 32, 10, 8),
    ]) {
      canvas.drawRRect(topRound(r), dark);
      canvas.drawRect(Rect.fromLTWH(r.left, 36, r.width, 2), brown);
    }
    canvas.drawCircle(const Offset(57.5, 20.5), 4.5, dark);
    canvas.drawCircle(const Offset(138.5, 20.5), 4.5, dark);
    canvas.restore();
  }

  void _screw(Canvas canvas, Offset o) {
    final c = o + const Offset(4.5, 4.5);
    canvas.drawCircle(c, 5.5, Paint()..color = _black.withValues(alpha: .25));
    final rect = Rect.fromCircle(center: c, radius: 4.5);
    canvas.drawCircle(
      c,
      4.5,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-.3, -.3),
          // circle at 35% 35%의 farthest-corner = .65·9·√2 = 8.27px
          radius: .919,
          colors: [TapeInk.screwLight, TapeInk.screwDark],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(TapeBodyPainter old) =>
      old.palette != palette ||
      old.packL != packL ||
      old.packR != packR ||
      old.hubAngle != hubAngle;
}

/// [child]를 [scale]만큼 줄여서 줄어든 크기로 자리를 차지하게 한다
/// (CSS `transform: scale(); transform-origin: 0 0` + 감싼 상자 크기).
class ScaledBox extends StatelessWidget {
  const ScaledBox({
    super.key,
    required this.scale,
    required this.size,
    required this.child,
  });

  final double scale;
  final Size size;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size.width * scale,
      height: size.height * scale,
      child: OverflowBox(
        alignment: Alignment.topLeft,
        minWidth: size.width,
        maxWidth: size.width,
        minHeight: size.height,
        maxHeight: size.height,
        child: Transform.scale(
          scale: scale,
          alignment: Alignment.topLeft,
          child: child,
        ),
      ),
    );
  }
}
