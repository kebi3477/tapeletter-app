import 'package:flutter/material.dart';

import '../../../utils/format.dart';
import '../../core/themes/colors.dart';
import '../../core/themes/tape_palette.dart';
import '../../core/themes/text_styles.dart';
import '../../core/ui/animations.dart';
import '../../core/ui/buttons.dart';
import '../../core/ui/grain_overlay.dart';
import '../../core/ui/tape_motion.dart';
import '../../core/ui/tape_widget.dart';
import '../../core/ui/app_sheet.dart';
import '../view_model/record_view_model.dart';
import 'record_deck.dart';
import '../../core/ui/tappable.dart';
import '../../core/ui/keep_all.dart';

/// 녹음 · 확인 — 템플릿 `vConfirm` 블록.
///
/// 테이프가 `clack .6s`로 떨어지고, 변환하는 동안 노이즈(`grainOn 1.4s`)를 보여준 뒤
/// 자동으로 미리 듣기를 시작한다. 재생 중에는 `wobble 2.4s`와 노이즈 루프.
class RecordConfirmView extends StatelessWidget {
  const RecordConfirmView({super.key, required this.viewModel});

  final RecordViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final vm = viewModel;
    final palette = TapePalette.of(vm.tape);
    final cp = vm.previewProgress;
    return Column(
      children: [
        BackBar(onBack: vm.backIdle),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Clack(
                child: Wobble(
                  active: vm.playing,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      TapeWidget(
                        palette: palette,
                        packL: palette.packL(cp),
                        packR: palette.packR(cp),
                        spinning: vm.playing,
                        speed: 1.8,
                        from: vm.myName,
                      ),
                      if (vm.converting)
                        const Positioned.fill(
                          child: GrainOverlay(mode: GrainMode.once),
                        ),
                      if (vm.playing || vm.convSlow)
                        const Positioned.fill(
                          child: GrainOverlay(mode: GrainMode.loop),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 36),
              if (vm.convSlow)
                const _ConvertSlow()
              else if (vm.convFail)
                const _ConvertFail()
              else
                _Preview(vm: vm),
            ],
          ),
        ),
        // `padding: 0 24px {cBotPad}` — 데크형은 22
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 22),
          child: Column(
            children: [
              if (!vm.convFail)
                AppButton(
                  label: vm.sendCta,
                  background: vm.converting
                      ? AppColors.disabled
                      : AppColors.ink,
                  onTap: vm.goSend,
                ),
              if (vm.convFail) ...[
                AppButton(label: '다시 시도', onTap: vm.retryConvert),
                const SizedBox(height: 8),
                AppButton.soft(label: '처음부터 다시 녹음', onTap: vm.redoRec),
              ],
            ],
          ),
        ),
        // 녹음 확인 · 데크형 (`deckConfirm`): margin-top 12, margin-bottom 84
        const SizedBox(height: 12),
        _ConfirmDeck(vm: vm),
        const SizedBox(height: 84),
      ],
    );
  }
}

/// 정지 후에도 데크가 남고 PLAY가 가운데(`deckRowX` −115).
/// 확인=PLAY·REC·REW(pos>0)·FF(+5초)·STOP(재생 중), 변환 중=없음, EJECT는 항상 비활성.
class _ConfirmDeck extends StatelessWidget {
  const _ConfirmDeck({required this.vm});

  final RecordViewModel vm;

  @override
  Widget build(BuildContext context) {
    final ready = vm.previewReady;
    return RecordDeck(
      center: DeckKey.play,
      playing: vm.playing,
      recLocked: vm.curLocked,
      keys: {
        DeckKey.rew: DeckKeyState(enabled: ready && vm.pos > 0),
        DeckKey.play: DeckKeyState(
          enabled: ready,
          latched: ready && vm.playing,
        ),
        DeckKey.rec: DeckKeyState(enabled: ready),
        DeckKey.stop: DeckKeyState(enabled: ready && vm.playing),
        DeckKey.ff: DeckKeyState(enabled: ready && vm.pos < vm.recorded),
      },
      onKey: (k) {
        switch (k) {
          case DeckKey.rew:
            vm.rewind();
          case DeckKey.play:
            vm.pressPlay();
          case DeckKey.rec:
            // 다시 녹음 확인 (`shRedo`)
            vm.pressStop();
            showRedoSheet(context, onRedo: vm.redoRec);
          case DeckKey.stop:
            vm.pressStop();
          case DeckKey.ff:
            vm.fastForward();
          case DeckKey.eject:
            break;
        }
      },
    );
  }
}

/// 다시 녹음할까요? (`shRedo`) — "지우고 다시 녹음"은 대기로 돌아가고 녹음은 자동으로 시작하지 않는다.
Future<void> showRedoSheet(
  BuildContext context, {
  required VoidCallback onRedo,
}) {
  return showAppSheet<void>(
    context,
    builder: (sheet) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          keepAll('다시 녹음할까요?'),
          style: AppText.suit(800, 20, letterSpacingEm: -.01),
        ),
        const SizedBox(height: 6),
        Text(
          keepAll('지금 녹음한 목소리는 지워져요. REC를 눌러 처음부터 다시 녹음할 수 있어요'),
          style: AppText.suit(500, 14, height: 1.55, color: AppColors.textSub),
        ),
        const SizedBox(height: 22),
        AppButton(
          label: '지우고 다시 녹음',
          onTap: () {
            Navigator.of(sheet).pop();
            onRedo();
          },
        ),
        const SizedBox(height: 2),
        Tappable(
          behavior: HitTestBehavior.opaque,
          onTap: () => Navigator.of(sheet).pop(),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Center(child: Text('취소', style: AppText.suit(600, 14))),
          ),
        ),
      ],
    ),
  );
}

/// 진행 바 + 60 재생 버튼 (너비 260, 간격 18)
class _Preview extends StatelessWidget {
  const _Preview({required this.vm});

  final RecordViewModel vm;

  @override
  Widget build(BuildContext context) {
    final label = AppText.suit(
      600,
      12,
      color: AppColors.textMuted,
      tabularNums: true,
    );
    return SizedBox(
      width: 260,
      child: Column(
        children: [
          Row(
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
                          widthFactor: vm.previewProgress,
                          heightFactor: 1,
                          child: const ColoredBox(color: AppColors.ink),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(formatClock(vm.recorded), style: label),
            ],
          ),
          // 데크형이라 동그란 재생 버튼은 숨긴다 (`roundPlay: false`)
        ],
      ),
    );
  }
}

/// 변환이 1.4초를 넘길 때 — `convSlowOn`
class _ConvertSlow extends StatelessWidget {
  const _ConvertSlow();

  @override
  Widget build(BuildContext context) {
    return FadeUp(
      duration: const Duration(milliseconds: 300),
      child: SizedBox(
        height: 96,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const LoadingDots(),
            const SizedBox(height: 12),
            Text(keepAll('테이프 소리로 바꾸는 중이에요'), style: AppText.suit(700, 15)),
            const SizedBox(height: 3),
            Text(
              keepAll('조금 오래 걸리고 있어요. 잠시만요'),
              style: AppText.suit(500, 13, color: AppColors.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}

/// 변환 실패 — `convFailOn`
class _ConvertFail extends StatelessWidget {
  const _ConvertFail();

  @override
  Widget build(BuildContext context) {
    return FadeUp(
      duration: const Duration(milliseconds: 300),
      child: SizedBox(
        height: 96,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(keepAll('테이프로 바꾸지 못했어요'), style: AppText.suit(800, 18)),
            const SizedBox(height: 6),
            Text(
              keepAll('녹음은 그대로 있어요. 다시 시도해 볼까요?'),
              textAlign: TextAlign.center,
              style: AppText.suit(
                500,
                13.5,
                height: 1.5,
                color: AppColors.textSub,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
