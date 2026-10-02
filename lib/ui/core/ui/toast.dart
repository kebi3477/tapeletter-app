import 'dart:async';

import 'package:flutter/material.dart';

import '../themes/colors.dart';
import '../themes/dimens.dart';
import '../themes/text_styles.dart';
import 'animations.dart';
import 'keep_all.dart';

/// 토스트 — logic.js `say(msg)`: 1.8초 동안 띄운다.
class ToastController extends ChangeNotifier {
  ToastController({this.duration = AppMotion.toast});

  final Duration duration;
  String? _message;
  int _serial = 0;
  Timer? _timer;

  String? get message => _message;

  /// 같은 문구를 다시 띄워도 애니메이션이 다시 재생되도록 매번 바뀌는 값.
  int get serial => _serial;

  void show(String message) {
    _message = message;
    _serial++;
    _timer?.cancel();
    _timer = Timer(duration, () {
      _message = null;
      notifyListeners();
    });
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

/// 화면 하단 104px에 뜨는 토스트 (z-index 70).
class ToastHost extends StatelessWidget {
  const ToastHost({super.key, required this.controller});

  final ToastController controller;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final msg = controller.message;
        if (msg == null) return const SizedBox.shrink();
        return Positioned(
          left: 0,
          right: 0,
          bottom: 104,
          child: IgnorePointer(
            child: Center(
              child: FadeUp(
                key: ValueKey(controller.serial),
                duration: AppMotion.fadeUp,
                child: Container(
                  constraints: const BoxConstraints(minHeight: 44),
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  decoration: BoxDecoration(
                    color: AppColors.ink,
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Center(
                    widthFactor: 1,
                    child: Text(
                      keepAll(msg),
                      style: AppText.suit(700, 14, color: AppColors.paper),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
