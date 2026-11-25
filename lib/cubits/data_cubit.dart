import 'package:flutter_bloc/flutter_bloc.dart';

/// State for any screen that loads data from the API.
class DataState<T> {
  final T? data;
  final bool loading;
  final String? error;

  const DataState({this.data, this.loading = false, this.error});
}

/// Simple reusable cubit: give it a loader function, call [load] to (re)fetch.
/// Existing data stays visible while refreshing (pull-to-refresh).
class DataCubit<T> extends Cubit<DataState<T>> {
  DataCubit(this.loader) : super(const DataState(loading: true));

  Future<T> Function() loader;

  Future<void> load() async {
    emit(DataState(data: state.data, loading: true));
    try {
      final result = await loader();
      if (!isClosed) emit(DataState(data: result));
    } catch (e) {
      if (!isClosed) emit(DataState(data: state.data, error: e.toString()));
    }
  }

  /// Replace the data locally (e.g. after an update returned the new object).
  void set(T data) => emit(DataState(data: data));
}
