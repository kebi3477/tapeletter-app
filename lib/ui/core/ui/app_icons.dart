import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// 핸드오프 `assets/`의 SVG.
abstract final class AppIcons {
  static const credit = 'assets/svg/icon-credit.svg';
  static const infinity = 'assets/svg/icon-infinity.svg';
  static const repeat = 'assets/svg/icon-repeat.svg';
  static const symbolBlack = 'assets/svg/symbol-black.svg';
  static const symbolRed = 'assets/svg/symbol-red.svg';
  static const symbolWhite = 'assets/svg/symbol-white.svg';
  static const appIcon = 'assets/svg/app-icon.svg';

  /// 마이 "보낸 테이프" 메뉴 — 종이비행기 외곽선 (v10.5, 템플릿 `m.i2` SVG)
  static const paperPlane = 'assets/svg/icon-paper-plane.svg';

  /// Google 로그인 버튼의 공식 멀티컬러 "G" (Google 로그인 브랜딩 가이드)
  static const googleG = 'assets/svg/google-g.svg';
}

/// SVG 아이콘. `stroke="currentColor"`인 아이콘은 [color]로 칠한다.
class SvgIcon extends StatelessWidget {
  const SvgIcon(
    this.asset, {
    super.key,
    required this.width,
    required this.height,
    this.color,
    this.tint,
  });

  final String asset;
  final double width;
  final double height;
  final Color? color;

  /// 도형 전체를 이 색으로 칠한다 (심볼을 회색으로 등)
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      asset,
      width: width,
      height: height,
      theme: color == null ? const SvgTheme() : SvgTheme(currentColor: color!),
      colorFilter: tint == null
          ? null
          : ColorFilter.mode(tint!, BlendMode.srcIn),
    );
  }
}
