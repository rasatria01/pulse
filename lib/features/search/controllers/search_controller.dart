import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/di.dart';
import '../../../domain/entities/search.dart';
import '../../../domain/entities/tag.dart';

/// Null [results] = nothing typed yet, or the first answer is on its way.
typedef SearchState = ({
  String text,
  EntityType? type,
  AsyncValue<List<SearchHit>>? results,
});

const searchDebounce = Duration(milliseconds: 150);

final searchControllerProvider =
    NotifierProvider.autoDispose<SearchController, SearchState>(
      SearchController.new,
    );

class SearchController extends Notifier<SearchState> {
  Timer? _timer;

  /// Only the answer to the latest question is shown.
  int _asked = 0;

  @override
  SearchState build() {
    ref.onDispose(() => _timer?.cancel());
    return (text: '', type: null, results: null);
  }

  void setText(String text) {
    if (text == state.text) return;
    state = (text: text, type: state.type, results: state.results);
    _timer?.cancel();
    _timer = Timer(searchDebounce, search);
  }

  /// A chip is one deliberate tap: no debounce.
  void setType(EntityType? type) {
    state = (text: state.text, type: type, results: state.results);
    search();
  }

  Future<void> search() async {
    _timer?.cancel();
    final asked = ++_asked;
    final (:text, :type, results: _) = state;
    AsyncValue<List<SearchHit>>? results;
    if (text.trim().isNotEmpty) {
      results = await AsyncValue.guard(
        () => ref
            .read(searchRepositoryProvider)
            .search(SearchQuery(text: text, type: type)),
      );
    }
    if (!ref.mounted || asked != _asked) return;
    state = (text: state.text, type: state.type, results: results);
  }
}
