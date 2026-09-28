/// 설정 > 정보의 외부 링크. 페이지는 tapeletter-api가 서비스한다 (GET /privacy, /terms).
abstract final class AppLinks {
  static final terms = Uri.parse('https://tapeletter.lab241.com/terms');
  static final privacy = Uri.parse('https://tapeletter.lab241.com/privacy');

  /// 문의·개인정보 보호책임자 이메일 (서버 POLICY_CONTACT_EMAIL과 같게)
  static final contact = Uri.parse('mailto:kebi3477@naver.com');
}
