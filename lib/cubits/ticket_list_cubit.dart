import 'package:flutter_bloc/flutter_bloc.dart';

import '../core/api.dart';
import '../models/models.dart';

class TicketListState {
  final List<Ticket> items;
  final int total, page, totalPages;
  final bool loading;
  final String? error;

  const TicketListState({this.items = const [], this.total = 0, this.page = 0, this.totalPages = 1, this.loading = false, this.error});

  bool get hasMore => page < totalPages;
}

/// Paginated ticket list (infinite scroll): [load] resets, [loadMore] appends the next page.
class TicketListCubit extends Cubit<TicketListState> {
  TicketListCubit(this.filters) : super(const TicketListState(loading: true));

  Map<String, dynamic> filters;

  Future<void> load() => _fetch(1);

  Future<void> loadMore() async {
    if (state.loading || !state.hasMore) return;
    await _fetch(state.page + 1);
  }

  Future<void> _fetch(int page) async {
    final keep = page == 1 ? <Ticket>[] : state.items;
    emit(TicketListState(items: page == 1 ? state.items : keep, total: state.total, page: state.page, totalPages: state.totalPages, loading: true));
    try {
      final res = await Api.tickets({...filters, 'page': page, 'pageSize': 30});
      if (isClosed) return;
      emit(TicketListState(items: [...keep, ...res.items], total: res.total, page: res.page, totalPages: res.totalPages));
    } catch (e) {
      if (isClosed) return;
      emit(TicketListState(items: state.items, total: state.total, page: state.page, totalPages: state.totalPages, error: e.toString()));
    }
  }
}
