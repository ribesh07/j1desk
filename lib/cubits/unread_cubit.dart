import 'package:flutter_bloc/flutter_bloc.dart';

import '../core/api.dart';

/// Unread notification count shown in the drawer and app bar bell.
class UnreadCubit extends Cubit<int> {
  UnreadCubit() : super(0);

  Future<void> refresh() async {
    try {
      emit(await Api.unreadCount());
    } catch (_) {
      // Ignore: the badge simply keeps its last value.
    }
  }

  void reset() => emit(0);

  void set(int count) => emit(count);
}
