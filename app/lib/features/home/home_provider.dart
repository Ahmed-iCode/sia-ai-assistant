import 'package:flutter_riverpod/flutter_riverpod.dart';

class HomeNotifier extends Notifier<int> {
  @override
  int build() {
    return 0; // Default to Schedule (Tasks)
  }

  void setTab(int index) {
    state = index;
  }
}

final homeTabProvider = NotifierProvider<HomeNotifier, int>(
  HomeNotifier.new,
);
