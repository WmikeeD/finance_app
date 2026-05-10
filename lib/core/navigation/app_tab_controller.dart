import 'package:flutter/foundation.dart';

class AppTabController {
  AppTabController._();

  static final ValueNotifier<int> tabIndex = ValueNotifier<int>(0);

  static void goToTab(int index) => tabIndex.value = index;
  static void goToHome() => goToTab(0);
  static void goToTransacciones() => goToTab(1);
  static void goToReportes() => goToTab(2);
  static void goToProyeccion() => goToTab(3);
  static void goToConfig() => goToTab(4);
}
