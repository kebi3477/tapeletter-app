import 'package:flutter/material.dart';

import '../../core/themes/colors.dart';
import '../../core/themes/text_styles.dart';
import '../../core/ui/animations.dart';
import '../../core/ui/app_icons.dart';
import '../../core/ui/buttons.dart';
import '../../launch/widgets/update_screen.dart' show FullScreenMessage;
import '../view_model/status_view_model.dart';
import '../../core/ui/keep_all.dart';

/// 오프라인 배너 (`offlineOn`) — 상태바 바로 아래 30, `#111`
class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key, required this.viewModel});

  final StatusViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: viewModel,
      builder: (context, _) {
        if (!viewModel.offline) return const SizedBox.shrink();
        return Positioned(
          left: 0,
          right: 0,
          top: MediaQuery.viewPaddingOf(context).top,
          height: 30,
          child: IgnorePointer(
            child: FadeUp(
              child: Container(
                color: AppColors.ink,
                alignment: Alignment.center,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: AppColors.textMuted,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      keepAll('인터넷에 연결되어 있지 않아요'),
                      style: AppText.suit(600, 12.5, color: AppColors.paper),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// 서버 오류 (`serverOn`) — 5xx를 받으면 전체 화면, 다시 시도
class ServerErrorOverlay extends StatelessWidget {
  const ServerErrorOverlay({super.key, required this.viewModel});

  final StatusViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: viewModel,
      builder: (context, _) {
        if (!viewModel.serverError) return const SizedBox.shrink();
        return Positioned.fill(
          child: Material(
            color: AppColors.paper,
            child: SafeArea(
              bottom: false,
              child: FullScreenMessage(
                graphic: const SvgIcon(
                  AppIcons.symbolBlack,
                  width: 88,
                  height: 88,
                  tint: AppColors.toggleOff,
                ),
                title: '잠시 문제가 생겼어요',
                body: '저희 쪽 문제예요.\n조금 뒤에 다시 시도해 주세요.',
                button: AppButton(
                  label: viewModel.retrying ? '다시 시도하는 중…' : '다시 시도',
                  onTap: viewModel.retry,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
