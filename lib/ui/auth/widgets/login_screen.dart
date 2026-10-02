import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../core/themes/colors.dart';
import '../../core/themes/text_styles.dart';
import '../../core/ui/animations.dart';
import '../../core/ui/app_icons.dart';
import '../../core/ui/brand.dart';
import '../../core/ui/buttons.dart';
import '../view_model/login_view_model.dart';
import '../../core/ui/keep_all.dart';

/// 로그인 (`auLogin`) — 카카오 / Apple, 약관 안내.
/// Android는 Apple 대신 Google 버튼을 같은 자리·같은 크기로 둔다.
class LoginScreen extends StatelessWidget {
  const LoginScreen({
    super.key,
    required this.viewModel,
    required this.onOpenTerms,
    required this.onOpenPrivacy,
    this.devLogin = kDebugMode,
  });

  final LoginViewModel viewModel;
  final VoidCallback onOpenTerms;
  final VoidCallback onOpenPrivacy;

  /// 개발 빌드에서만: 앱 아이콘을 길게 누르면 개발 로그인 (`POST /auth/dev`)
  final bool devLogin;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.paper,
      body: SafeArea(
        bottom: false,
        child: ListenableBuilder(
          listenable: viewModel,
          builder: (context, _) {
            final busy = viewModel.busy;
            return Column(
              children: [
                Expanded(
                  child: FadeUp(
                    duration: const Duration(milliseconds: 500),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          GestureDetector(
                            onLongPress: devLogin ? viewModel.signInDev : null,
                            child: const AppIconMark(glow: true),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            'tapeletter',
                            style: AppText.suit(
                              800,
                              34,
                              height: 1,
                              letterSpacingEm: -.045,
                            ),
                          ),
                          const SizedBox(height: 18),
                          Text(
                            keepAll('목소리를 테이프에 담아 보내요'),
                            textAlign: TextAlign.center,
                            style: AppText.suit(
                              600,
                              15,
                              height: 1.5,
                              color: AppColors.textSub,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                FadeUp(
                  duration: const Duration(milliseconds: 500),
                  delay: const Duration(milliseconds: 150),
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      24,
                      0,
                      24,
                      bottomSafe(context),
                    ),
                    child: Column(
                      children: [
                        AppButton(
                          label: busy == LoginProvider.kakao
                              ? '연결 중…'
                              : '카카오로 시작하기',
                          background: AppColors.kakao,
                          foreground: AppColors.kakaoInk,
                          leading: Opacity(
                            opacity: busy == LoginProvider.kakao ? 0 : 1,
                            child: Container(
                              width: 20,
                              height: 17,
                              decoration: const BoxDecoration(
                                color: AppColors.kakaoInk,
                                borderRadius: BorderRadius.all(
                                  Radius.elliptical(10, 8.5),
                                ),
                              ),
                            ),
                          ),
                          onTap: () => viewModel.signIn(LoginProvider.kakao),
                        ),
                        const SizedBox(height: 8),
                        if (defaultTargetPlatform == TargetPlatform.android)
                          _GoogleButton(
                            busy: busy == LoginProvider.google,
                            onTap: () => viewModel.signIn(LoginProvider.google),
                          )
                        else
                          AppButton(
                            label: busy == LoginProvider.apple
                                ? '연결 중…'
                                : 'Apple로 계속하기',
                            onTap: () => viewModel.signIn(LoginProvider.apple),
                          ),
                        const SizedBox(height: 18),
                        _Terms(onTerms: onOpenTerms, onPrivacy: onOpenPrivacy),
                      ],
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

/// Google로 계속하기 — Apple 버튼과 같은 56 / radius 16 자리.
/// Google 로그인 브랜딩 가이드 라이트 테마: 흰 바탕, `#747775` 1px 테두리, 멀티컬러 "G",
/// 글자는 앱 글꼴 SUIT 600 16.
class _GoogleButton extends StatelessWidget {
  const _GoogleButton({required this.busy, required this.onTap});

  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppButton(
      label: busy ? '연결 중…' : 'Google로 계속하기',
      background: AppColors.googleFill,
      foreground: AppColors.googleInk,
      borderColor: AppColors.googleStroke,
      textStyle: AppText.suit(600, 16),
      gap: 10,
      leading: Opacity(
        opacity: busy ? 0 : 1,
        child: const SvgIcon(AppIcons.googleG, width: 20, height: 20),
      ),
      onTap: onTap,
    );
  }
}

/// 약관 동의·만 14세 안내 (500 12/1.6 `#9A9A97`). "이용약관"·"개인정보 처리방침"은
/// `#6E6E6B` 밑줄 링크로 문서를 연다 (`openDoc`).
/// CSS의 `text-underline-offset:2px`는 Flutter 글자 스타일에 없어 기본 위치의 밑줄로 그린다.
class _Terms extends StatefulWidget {
  const _Terms({required this.onTerms, required this.onPrivacy});

  final VoidCallback onTerms;
  final VoidCallback onPrivacy;

  @override
  State<_Terms> createState() => _TermsState();
}

class _TermsState extends State<_Terms> {
  late final TapGestureRecognizer _t = TapGestureRecognizer()
    ..onTap = widget.onTerms;
  late final TapGestureRecognizer _p = TapGestureRecognizer()
    ..onTap = widget.onPrivacy;

  @override
  void dispose() {
    _t.dispose();
    _p.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = AppText.suit(500, 12, height: 1.6, color: AppColors.textMuted);
    final link = base.copyWith(
      color: AppColors.textSecondary,
      decoration: TextDecoration.underline,
      decorationColor: AppColors.textSecondary,
    );
    return Text.rich(
      TextSpan(
        style: base,
        children: [
          TextSpan(text: keepAll('계속하면 ')),
          TextSpan(text: '이용약관', style: link, recognizer: _t),
          TextSpan(text: keepAll('과 ')),
          TextSpan(text: keepAll('개인정보 처리방침'), style: link, recognizer: _p),
          TextSpan(text: keepAll('에 동의하게 돼요.\n만 14세 이상만 이용할 수 있어요')),
        ],
      ),
      textAlign: TextAlign.center,
    );
  }
}
