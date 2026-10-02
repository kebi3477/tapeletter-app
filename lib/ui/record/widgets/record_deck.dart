import 'package:flutter/material.dart';

import '../../core/themes/colors.dart';
import '../../core/themes/deck_colors.dart';
import '../../core/themes/text_styles.dart';
import '../../core/ui/css_paint.dart';
import '../../core/ui/tappable.dart';

/// 데크 키 — 왼쪽부터 REW·PLAY·REC·STOP·FF·EJECT
enum DeckKey {
  rew('REW'),
  play('PLAY'),
  rec('REC'),
  stop('STOP'),
  ff('FF'),
  eject('EJECT');

  const DeckKey(this.label);

  final String label;
}

/// 키 한 개의 상태 (`dk.*`) — [enabled]면 누를 수 있고, [latched]면 눌린 채로 있다(녹음 중 REC, 재생 중 PLAY).
class DeckKeyState {
  const DeckKeyState({this.enabled = false, this.latched = false});

  static const off = DeckKeyState();

  final bool enabled;
  final bool latched;
}

/// 데크형 녹음 버튼 (`deckBtn` · `deckConfirm`) — 카세트 플레이어 키 줄.
///
/// 키는 눌렀다 **뗄 때** 동작하고, 누른 채 키 밖으로 나가면 취소된다.
/// [center] 키가 가운데 오도록 줄이 `transform .45s cubic-bezier(.3,.7,.3,1)`로 밀린다(`deckRowX`).
class RecordDeck extends StatefulWidget {
  const RecordDeck({
    super.key,
    required this.keys,
    required this.center,
    required this.onKey,
    this.recording = false,
    this.playing = false,
    this.recLocked = false,
  });

  final Map<DeckKey, DeckKeyState> keys;
  final DeckKey center;
  final ValueChanged<DeckKey> onKey;

  /// REC LED (`ledBg`)
  final bool recording;

  /// PLAY LED (`pLedBg`)
  final bool playing;

  /// 고른 테이프가 0개라 REC 동그라미가 회색 (`recBg` `#DADAD7`)
  final bool recLocked;

  /// 컨테이너 높이 (`height:112px`)
  static const height = 112.0;

  static const keyWidth = 74.0;
  static const keyHeight = 84.0;
  static const keyGap = 4.0;

  /// 가운데 키의 중심 = 줄 왼쪽에서 (37 + 78 × i) → `deckRowX` −115 / −193 / −271
  static double rowXFor(DeckKey k) =>
      -(keyWidth / 2 + (keyWidth + keyGap) * k.index);

  @override
  State<RecordDeck> createState() => _RecordDeckState();
}

class _RecordDeckState extends State<RecordDeck> {
  DeckKey? _down;

  DeckKeyState _state(DeckKey k) => widget.keys[k] ?? DeckKeyState.off;

  void _press(DeckKey k) {
    if (!_state(k).enabled) return;
    // 데크 키는 눌리는 순간 묵직하게 (비활성 키는 울리지 않는다)
    Haptic.medium.fire();
    setState(() => _down = k);
  }

  void _cancel() {
    if (_down != null) setState(() => _down = null);
  }

  void _release(DeckKey k) {
    if (_down != k) return;
    setState(() => _down = null);
    widget.onKey(k);
  }

  @override
  Widget build(BuildContext context) =>
      // 카세트 데크는 시스템 글자 크기와 상관없이 고정 (v10.4)
      MediaQuery.withNoTextScaling(child: Builder(builder: _build));

  Widget _build(BuildContext context) {
    return SizedBox(
      height: RecordDeck.height,
      width: double.infinity,
      child: LayoutBuilder(
        builder: (context, box) {
          final mid = box.maxWidth / 2;
          return Stack(
            clipBehavior: Clip.none,
            children: [
              // 본체 440×190 (top −12), 키 홈 420×100 (top 8)
              Positioned(
                left: mid - 220,
                top: -12,
                width: 440,
                height: 190,
                child: const IgnorePointer(
                  child: CustomPaint(painter: _BodyPainter()),
                ),
              ),
              Positioned(
                left: mid - 210,
                top: 8,
                width: 420,
                height: 100,
                child: const IgnorePointer(
                  child: CustomPaint(painter: _SlotPainter()),
                ),
              ),
              TweenAnimationBuilder<double>(
                tween: Tween(end: RecordDeck.rowXFor(widget.center)),
                duration: const Duration(milliseconds: 450),
                curve: const Cubic(.3, .7, .3, 1),
                builder: (context, x, child) => Positioned(
                  left: mid + x,
                  top: 14,
                  height: RecordDeck.keyHeight + 6,
                  child: child!,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final k in DeckKey.values) ...[
                      if (k != DeckKey.rew)
                        const SizedBox(width: RecordDeck.keyGap),
                      _Key(
                        id: k,
                        state: _state(k),
                        pressed: _down == k,
                        led: switch (k) {
                          DeckKey.rec =>
                            widget.recording ? _Led.recOn : _Led.recOff,
                          DeckKey.play =>
                            widget.playing ? _Led.playOn : _Led.playOff,
                          _ => null,
                        },
                        recLocked: widget.recLocked,
                        onDown: () => _press(k),
                        onUp: () => _release(k),
                        onCancel: _cancel,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

enum _Led {
  recOn(DeckColors.recLedOn, DeckColors.recLedGlow),
  recOff(DeckColors.recLedOff, null),
  playOn(DeckColors.playLedOn, DeckColors.playLedGlow),
  playOff(DeckColors.playLedOff, null);

  const _Led(this.color, this.glow);

  final Color color;
  final Color? glow;
}

/// 한 조각 키 (74×84, radius 3 3 6 6, 눌림 3px)
class _Key extends StatelessWidget {
  const _Key({
    required this.id,
    required this.state,
    required this.pressed,
    required this.led,
    required this.recLocked,
    required this.onDown,
    required this.onUp,
    required this.onCancel,
  });

  final DeckKey id;
  final DeckKeyState state;
  final bool pressed;
  final _Led? led;
  final bool recLocked;
  final VoidCallback onDown;
  final VoidCallback onUp;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final en = state.enabled;
    final lit = en || state.latched;
    final dn = state.latched || (en && pressed);
    final look = dn
        ? _KeyLook.down
        : en
        ? _KeyLook.up
        : _KeyLook.off;
    const size = Size(RecordDeck.keyWidth, RecordDeck.keyHeight);
    return Semantics(
      button: true,
      enabled: en,
      toggled: state.latched,
      label: id.label,
      excludeSemantics: true,
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: (_) => onDown(),
        onPointerMove: (e) {
          // 누른 채 키 밖으로 나가면 취소 (`deckLeave`)
          if (!(Offset.zero & size).contains(e.localPosition)) onCancel();
        },
        onPointerUp: (e) {
          if ((Offset.zero & size).contains(e.localPosition)) {
            onUp();
          } else {
            onCancel();
          }
        },
        onPointerCancel: (_) => onCancel(),
        child: AnimatedOpacity(
          // opacity .2s
          duration: const Duration(milliseconds: 200),
          opacity: lit ? 1 : .55,
          child: TweenAnimationBuilder<double>(
            // transform .08s
            tween: Tween(end: dn ? 3 : 0),
            duration: const Duration(milliseconds: 80),
            builder: (context, y, child) =>
                Transform.translate(offset: Offset(0, y), child: child),
            child: SizedBox.fromSize(
              size: size,
              child: CustomPaint(
                painter: _KeyPainter(lit: lit, look: look),
                child: Stack(
                  children: [
                    // 아래 점 3개 (bottom 7, 3px, 간격 4)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 7,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          for (var i = 0; i < 3; i++) ...[
                            if (i > 0) const SizedBox(width: 4),
                            Container(
                              width: 3,
                              height: 3,
                              decoration: const BoxDecoration(
                                color: DeckColors.dot,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (led case final l?)
                      Positioned(
                        top: 22,
                        right: 8,
                        child: Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: l.color,
                            shape: BoxShape.circle,
                            boxShadow: [
                              if (l.glow case final g?)
                                BoxShadow(
                                  color: g,
                                  blurRadius: 6,
                                  spreadRadius: 1,
                                ),
                            ],
                          ),
                        ),
                      ),
                    Positioned.fill(
                      top: 14,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            height: 14,
                            child: Center(
                              child: _Icon(id: id, recLocked: recLocked),
                            ),
                          ),
                          const SizedBox(height: 7),
                          Text(
                            id.label,
                            style: AppText.suit(
                              800,
                              9.5,
                              height: 1,
                              letterSpacingEm: .14,
                              color: DeckColors.label,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

enum _KeyLook { up, down, off }

/// 키 모양 — 윗면 그라데이션(14px에서 꺾이는 선), 아래 두께 그림자, 안쪽 가장자리 빛
class _KeyPainter extends CustomPainter {
  const _KeyPainter({required this.lit, required this.look});

  final bool lit;
  final _KeyLook look;

  static const _radius = BorderRadius.only(
    topLeft: Radius.circular(3),
    topRight: Radius.circular(3),
    bottomLeft: Radius.circular(6),
    bottomRight: Radius.circular(6),
  );

  @override
  void paint(Canvas canvas, Size size) {
    final r = _radius.toRRect(Offset.zero & size);
    // 바깥 그림자: 앞에 적힌 것이 위에 그려진다 (0 4px #5E5E5B, 0 5px #0A0A0A)
    final (edge, edgeY, footY) = switch (look) {
      _KeyLook.down => (DeckColors.keyEdge, 1.0, 1.0),
      _KeyLook.up => (DeckColors.keyEdge, 4.0, 5.0),
      _KeyLook.off => (DeckColors.keyEdgeOff, 4.0, 5.0),
    };
    canvas.drawRRect(
      r.shift(Offset(0, footY)),
      Paint()..color = DeckColors.keyFoot,
    );
    canvas.drawRRect(r.shift(Offset(0, edgeY)), Paint()..color = edge);

    final h = size.height;
    final face = Paint()
      ..shader = CssPaint.linearGradient(
        Offset.zero & size,
        180,
        lit ? DeckColors.keyLit : DeckColors.keyOff,
        [0, 9 / h, 13 / h, 14 / h, 15 / h, 22 / h, .55, 1],
      );
    canvas.drawRRect(r, face);

    // inset 1px 0 0 (왼쪽 빛)
    CssPaint.insetShadow(
      canvas,
      r,
      offset: const Offset(1, 0),
      color: switch (look) {
        _KeyLook.up => DeckColors.keyHighlight,
        _KeyLook.down => DeckColors.keyHighlightDown,
        _KeyLook.off => DeckColors.keyHighlightOff,
      },
    );
    switch (look) {
      case _KeyLook.up:
        // inset -1px 0 0 rgba(0,0,0,.18)
        CssPaint.insetShadow(
          canvas,
          r,
          offset: const Offset(-1, 0),
          color: DeckColors.keyInnerRight,
        );
      case _KeyLook.down:
        // inset 0 -8px 12px -8px rgba(0,0,0,.35)
        CssPaint.insetShadow(
          canvas,
          r,
          offset: const Offset(0, -8),
          blur: 12,
          spread: -8,
          color: DeckColors.keyPressShade,
        );
      case _KeyLook.off:
        break;
    }
  }

  @override
  bool shouldRepaint(_KeyPainter old) => old.lit != lit || old.look != look;
}

/// 키 기호 (CSS 삼각형 → 도형)
class _Icon extends StatelessWidget {
  const _Icon({required this.id, required this.recLocked});

  final DeckKey id;
  final bool recLocked;

  @override
  Widget build(BuildContext context) {
    return switch (id) {
      DeckKey.rec => Container(
        width: 14,
        height: 14,
        decoration: BoxDecoration(
          color: recLocked ? AppColors.toggleOff : AppColors.red,
          shape: BoxShape.circle,
        ),
      ),
      DeckKey.stop => Container(
        width: 13,
        height: 13,
        decoration: BoxDecoration(
          color: DeckColors.icon,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
      _ => CustomPaint(
        size: switch (id) {
          DeckKey.rew || DeckKey.ff => const Size(18, 12),
          DeckKey.play => const Size(9, 12),
          _ => const Size(14, 11), // EJECT: 삼각형 7 + 간격 2 + 막대 2
        },
        painter: _IconPainter(id),
      ),
    };
  }
}

class _IconPainter extends CustomPainter {
  const _IconPainter(this.id);

  final DeckKey id;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = DeckColors.icon;
    // 오른쪽을 향한 9×12 삼각형 (border-left 9, top/bottom 6)
    Path right(double x) => Path()
      ..moveTo(x, 0)
      ..lineTo(x + 9, 6)
      ..lineTo(x, 12)
      ..close();
    Path left(double x) => Path()
      ..moveTo(x + 9, 0)
      ..lineTo(x, 6)
      ..lineTo(x + 9, 12)
      ..close();
    switch (id) {
      case DeckKey.play:
        canvas.drawPath(right(0), p);
      case DeckKey.ff:
        canvas.drawPath(right(0), p);
        canvas.drawPath(right(9), p);
      case DeckKey.rew:
        canvas.drawPath(left(0), p);
        canvas.drawPath(left(9), p);
      case DeckKey.eject:
        canvas.drawPath(
          Path()
            ..moveTo(0, 7)
            ..lineTo(7, 0)
            ..lineTo(14, 7)
            ..close(),
          p,
        );
        canvas.drawRect(const Rect.fromLTWH(0, 9, 14, 2), p);
      case DeckKey.rec || DeckKey.stop:
        break;
    }
  }

  @override
  bool shouldRepaint(_IconPainter old) => old.id != id;
}

/// 은색 브러시드 금속 본체 (radius 14 14 0 0)
class _BodyPainter extends CustomPainter {
  const _BodyPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final r = RRect.fromRectAndCorners(
      rect,
      topLeft: const Radius.circular(14),
      topRight: const Radius.circular(14),
    );
    // 0 -6px 18px -10px rgba(0,0,0,.35)
    canvas.drawRRect(
      r.deflate(10).shift(const Offset(0, -6)),
      Paint()
        ..color = DeckColors.bodyShadow
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 9),
    );
    canvas.drawRRect(
      r,
      Paint()
        ..shader = CssPaint.linearGradient(
          rect,
          180,
          const [DeckColors.bodyTop, DeckColors.bodyMid, DeckColors.bodyBottom],
          const [0, .3, 1],
        ),
    );
    // 브러시드 결 (1px 밝게 · 1px 어둡게 반복)
    canvas.save();
    canvas.clipRRect(r);
    final light = Paint()..color = DeckColors.bodyStripeLight;
    final dark = Paint()..color = DeckColors.bodyStripeDark;
    for (var y = 0.0; y < size.height; y += 2) {
      canvas.drawRect(Rect.fromLTWH(0, y, size.width, 1), light);
      canvas.drawRect(Rect.fromLTWH(0, y + 1, size.width, 1), dark);
    }
    canvas.restore();
    // inset 0 2px 0 #F7F7F5, inset 0 -1px 0 #8E8E8A
    CssPaint.insetShadow(
      canvas,
      r,
      offset: const Offset(0, 2),
      color: DeckColors.bodyInnerTop,
    );
    CssPaint.insetShadow(
      canvas,
      r,
      offset: const Offset(0, -1),
      color: DeckColors.bodyInnerBottom,
    );
    // 윗면 3px 빛 줄
    final shine = RRect.fromRectAndCorners(
      Rect.fromLTWH(0, 0, size.width, 3),
      topLeft: const Radius.circular(14),
      topRight: const Radius.circular(14),
    );
    canvas.drawRRect(
      shine,
      Paint()
        ..shader = CssPaint.linearGradient(
          shine.outerRect,
          90,
          DeckColors.bodyShine,
          const [0, .3, .5, .7, 1],
        ),
    );
  }

  @override
  bool shouldRepaint(_BodyPainter old) => false;
}

/// 검은 키 홈 (radius 4)
class _SlotPainter extends CustomPainter {
  const _SlotPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final r = RRect.fromRectAndRadius(rect, const Radius.circular(4));
    // 0 1px 0 #EDEDEA, 0 -1px 0 #8E8E8A
    canvas.drawRRect(
      r.shift(const Offset(0, -1)),
      Paint()..color = DeckColors.slotLipAbove,
    );
    canvas.drawRRect(
      r.shift(const Offset(0, 1)),
      Paint()..color = DeckColors.slotLipBelow,
    );
    canvas.drawRRect(
      r,
      Paint()
        ..shader = CssPaint.linearGradient(rect, 180, const [
          DeckColors.slotTop,
          DeckColors.slotBottom,
        ]),
    );
    // inset 0 4px 6px rgba(0,0,0,.9)
    CssPaint.insetShadow(
      canvas,
      r,
      offset: const Offset(0, 4),
      blur: 6,
      color: DeckColors.slotInner,
    );
  }

  @override
  bool shouldRepaint(_SlotPainter old) => false;
}
