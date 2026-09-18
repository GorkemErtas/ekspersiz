
class AppLocaleController {
  AppLocaleController._();

  static final AppLocaleController instance = AppLocaleController._();

  String translate(String source) => source;
}

extension LocalizedString on String {
  String get tr => this;
}
