import 'package:flutter_bloc/flutter_bloc.dart';

import '../core/api.dart';
import '../core/meta.dart';
import '../models/models.dart';

class BoardState {
  final List<Ticket> tickets;
  final int total;
  final bool loading;
  final String? error;

  const BoardState({this.tickets = const [], this.total = 0, this.loading = false, this.error});

  /// Tickets grouped by status column, ordered by their board position.
  Map<String, List<Ticket>> get columns {
    final map = {for (final s in boardColumns) s: <Ticket>[]};
    for (final t in tickets) {
      map[t.status]?.add(t);
    }
    for (final list in map.values) {
      list.sort((a, b) => a.position.compareTo(b.position));
    }
    return map;
  }
}

/// Kanban board data + drag & drop moves.
/// Moves are applied optimistically, saved with POST /api/tickets/:id/move and rolled back on error.
/// The server sends the push notification to the team after every status change.
class BoardCubit extends Cubit<BoardState> {
  BoardCubit(this.filters) : super(const BoardState(loading: true));

  /// Extra ticket filters, e.g. {projectId: 'ERP'} or {assigneeId: 'me'}
  Map<String, dynamic> filters;

  static const _gap = 1000.0;

  Future<void> load() async {
    emit(BoardState(tickets: state.tickets, total: state.total, loading: true));
    try {
      final page = await Api.tickets({...filters, 'pageSize': 500, 'sort': 'position', 'order': 'asc'});
      if (!isClosed) emit(BoardState(tickets: page.items, total: page.total));
    } catch (e) {
      if (!isClosed) emit(BoardState(tickets: state.tickets, total: state.total, error: e.toString()));
    }
  }

  /// Fractional position for dropping at [index] of [column] (the dragged card is not in the list).
  /// Placing between two cards takes the middle value, so no other card needs renumbering.
  static double positionAt(List<Ticket> column, int index) {
    final prev = index > 0 ? column[index - 1].position : null;
    final next = index < column.length ? column[index].position : null;
    if (prev != null && next != null) return (prev + next) / 2;
    if (prev != null) return prev + _gap;
    if (next != null) return next - _gap;
    return _gap;
  }

  /// Moves [ticket] to column [to] at [index]. Returns null on success or an error message.
  Future<String?> move(Ticket ticket, String to, int index, {String? reason}) async {
    final column = (state.columns[to] ?? []).where((t) => t.id != ticket.id).toList();
    final position = positionAt(column, index.clamp(0, column.length));
    final before = state.tickets;

    // Optimistic update: show the card in its new place right away.
    emit(BoardState(
      tickets: [for (final t in before) t.id == ticket.id ? t.copyWith(status: to, position: position) : t],
      total: state.total,
    ));

    try {
      await Api.moveTicket(ticket.key, to, position, reason: reason);
      if (to != ticket.status) load(); // refresh assignee / counters changed by the workflow
      return null;
    } catch (e) {
      // Roll back to where it was.
      if (!isClosed) emit(BoardState(tickets: before, total: state.total));
      return e.toString();
    }
  }
}
