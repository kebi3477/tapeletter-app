import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/themes/colors.dart';
import '../../core/themes/dimens.dart';
import '../../core/themes/tape_palette.dart';
import '../../core/themes/text_styles.dart';
import '../../core/ui/animations.dart';
import '../../core/ui/buttons.dart';
import '../../core/ui/parcel_box.dart';
import '../../core/ui/tape_widget.dart';
import '../view_model/record_view_model.dart';
import '../../core/ui/keep_all.dart';

/// 녹음 · 포장/발송 — 템플릿 `vSending` 블록.
///
/// 박스 안쪽을 깔고 테이프가 `tapeIn 1.1s`로 떨어져 들어간 뒤, 앞면이 가리고
/// 뚜껑이 `flapClose 2s`로 닫히고, 전체가 `fly 2.6s`로 오른쪽 위로 날아간다.
/// 서버 응답이 72% 시점까지 오지 않으면 박스는 그 자리에서 기다린다.
/// 실패하면 박스가 `shake`하며 위로 밀리고(패딩 200→300) 실패 패널이 뜬다.
class RecordSendingView extends StatelessWidget {
  const RecordSendingView({super.key, required this.viewModel});

  final RecordViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final vm = viewModel;
    return Stack(
      children: [
        Positioned.fill(
          child: AnimatedPadding(
            duration: const Duration(milliseconds: 400),
            curve: AppMotion.snap,
            padding: EdgeInsets.only(bottom: vm.sendFail ? 300 : 200),
            child: Align(
              alignment: Alignment.bottomCenter,
              child: SendingBox(
                palette: TapePalette.of(vm.tape),
                recipient: vm.to?.name ?? '',
                state: vm.sendState,
                failed: vm.sendFail,
                attempt: vm.sendAttempt,
              ),
            ),
          ),
        ),
        if (vm.sendFail)
          Positioned(
            left: 24,
            right: 24,
            bottom: bottomSafe(context),
            child: FadeUp(
              duration: const Duration(milliseconds: 300),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 18),
                    child: Column(
                      children: [
                        Text(
                          keepAll('보내지 못했어요'),
                          style: AppText.suit(800, 22, letterSpacingEm: -.02),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          keepAll('인터넷 연결을 확인하고 다시 보내 주세요\n테이프는 그대로 있어요'),
                          textAlign: TextAlign.center,
                          style: AppText.suit(
                            500,
                            14,
                            height: 1.55,
                            color: AppColors.textSub,
                          ),
                        ),
                      ],
                    ),
                  ),
                  AppButton(label: '다시 보내기', onTap: vm.retrySend),
                  const SizedBox(height: 8),
                  AppButton.soft(label: '돌아가기', onTap: vm.cancelSend),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// 260×190 소포 박스 + 떨어지는 테이프 + 뚜껑.
class SendingBox extends StatefulWidget {
  const SendingBox({
    super.key,
    required this.palette,
    required this.recipient,
    required this.state,
    required this.failed,
    required this.attempt,
  });

  final TapePalette palette;
  final String recipient;
  final SendState state;
  final bool failed;
  final int attempt;

  @override
  State<SendingBox> createState() => _SendingBoxState();
}

class _SendingBoxState extends State<SendingBox> with TickerProviderStateMixin {
  late final AnimationController _tapeIn = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..forward();
  late final AnimationController _flap = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2000),
  )..forward();
  late final AnimationController _fly = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  );
  late final AnimationController _shake = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  );

  static const double _hold = .72;

  @override
  void initState() {
    super.initState();
    _fly.addListener(_holdIfPending);
    _fly.forward();
    if (widget.failed) _shake.repeat();
  }

  void _holdIfPending() {
    if (!_fly.isAnimating) return;
    if (_fly.value >= _hold && widget.state != SendState.success) {
      _fly.stop();
      _fly.value = _hold;
    }
  }

  @override
  void didUpdateWidget(SendingBox old) {
    super.didUpdateWidget(old);
    if (widget.attempt != old.attempt) {
      _shake.reset();
      _fly.forward(from: 0);
    } else if (widget.state == SendState.success &&
        old.state != SendState.success &&
        !_fly.isAnimating) {
      _fly.forward();
    }
    if (widget.failed && !_shake.isAnimating) {
      _shake.repeat();
    } else if (!widget.failed && _shake.isAnimating) {
      _shake.reset();
    }
  }

  @override
  void dispose() {
    _tapeIn.dispose();
    _flap.dispose();
    _fly.dispose();
    _shake.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final box = SizedBox.fromSize(
      size: ParcelBox.size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          const Positioned.fill(child: ParcelBoxInside()),
          AnimatedBuilder(
            animation: _tapeIn,
            builder: (context, child) {
              // translate(-50%, y) scale(.7), transform-origin 50% 0
              final y = keyframes(
                _tapeIn.value,
                const [0, .55, 1],
                const [-230, -20, 0],
                curve: AppMotion.tapeIn,
              );
              return Positioned(
                left: (ParcelBox.size.width - AppSizes.tape.width) / 2,
                top: 6,
                width: AppSizes.tape.width,
                height: AppSizes.tape.height,
                child: Transform(
                  alignment: Alignment.topCenter,
                  transform: Matrix4.translationValues(0, y, 0)
                    ..multiply(Matrix4.diagonal3Values(.7, .7, 1)),
                  child: child,
                ),
              );
            },
            // 이 단계에서는 라벨 카드를 표시하지 않는다.
            child: TapeWidget(palette: widget.palette),
          ),
          Positioned.fill(child: ParcelBoxFront(recipient: widget.recipient)),
          AnimatedBuilder(
            animation: _flap,
            builder: (context, child) {
              // flapClose: 0%,50% rotateX(180deg) → 72%,100% rotateX(0)
              final deg = keyframes(
                _flap.value,
                const [0, .5, .72, 1],
                const [180, 180, 0, 0],
              );
              return Positioned(
                left: 0,
                right: 0,
                top: 0,
                height: ParcelBox.lidHeight,
                child: Transform(
                  alignment: Alignment.topCenter,
                  transform: Matrix4.identity()
                    ..setEntry(3, 2, 1 / 800)
                    ..rotateX(deg * math.pi / 180),
                  child: child,
                ),
              );
            },
            child: const ParcelBoxLid(),
          ),
        ],
      ),
    );

    return AnimatedBuilder(
      animation: Listenable.merge([_fly, _shake]),
      builder: (context, child) {
        if (widget.failed) {
          final deg = keyframes(
            _shake.value,
            const [0, .7, .75, .8, .85, .9, 1],
            const [0, 0, -3, 3, -2, 2, 0],
            curve: Curves.easeInOut,
          );
          return Transform.rotate(angle: deg * math.pi / 180, child: child);
        }
        final t = _fly.value;
        if (t <= _hold) return child!;
        final k = AppMotion.fly.transform((t - _hold) / (1 - _hold));
        return Opacity(
          opacity: (1 - k).clamp(0, 1),
          child: Transform(
            alignment: Alignment.center,
            transform: Matrix4.translationValues(240 * k, -560 * k, 0)
              ..rotateZ(-20 * k * math.pi / 180)
              ..multiply(Matrix4.diagonal3Values(1 - .65 * k, 1 - .65 * k, 1)),
            child: child,
          ),
        );
      },
      child: box,
    );
  }
}
