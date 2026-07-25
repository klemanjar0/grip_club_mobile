import 'package:flutter/material.dart';

/// Pull-to-refresh list that asks for the next page as the bottom approaches.
///
/// The one place infinite scroll is implemented — the lobby feeds and the
/// notification feed all mount this. Guarding against a duplicate fetch is the
/// bloc's job: [onLoadMore] fires on every qualifying scroll frame, and the
/// blocs no-op while a page is already in flight or `has_next` is false.
class PaginatedListView extends StatefulWidget {
  const PaginatedListView({
    required this.itemCount,
    required this.itemBuilder,
    required this.onRefresh,
    required this.onLoadMore,
    this.isLoadingMore = false,
    this.padding = const EdgeInsets.fromLTRB(16, 8, 16, 24),
    super.key,
  });

  final int itemCount;
  final NullableIndexedWidgetBuilder itemBuilder;
  final Future<void> Function() onRefresh;
  final VoidCallback onLoadMore;

  /// Appends a trailing spinner row.
  final bool isLoadingMore;

  final EdgeInsets padding;

  @override
  State<PaginatedListView> createState() => _PaginatedListViewState();
}

class _PaginatedListViewState extends State<PaginatedListView> {
  static const double _loadMoreThreshold = 300;

  final ScrollController _controller = ScrollController();

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onScroll);
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_controller.hasClients) return;

    final position = _controller.position;
    if (position.pixels >= position.maxScrollExtent - _loadMoreThreshold) {
      widget.onLoadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: widget.onRefresh,
      child: ListView.separated(
        controller: _controller,
        padding: widget.padding,
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: widget.itemCount + (widget.isLoadingMore ? 1 : 0),
        separatorBuilder: (context, index) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          if (index >= widget.itemCount) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: SizedBox.square(
                  dimension: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            );
          }

          return widget.itemBuilder(context, index);
        },
      ),
    );
  }
}

/// Wraps a full-screen state (empty / error) so pull-to-refresh keeps working
/// when there is nothing to scroll.
class RefreshableMessage extends StatelessWidget {
  const RefreshableMessage({
    required this.onRefresh,
    required this.child,
    super.key,
  });

  final Future<void> Function() onRefresh;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: child,
          ),
        ),
      ),
    );
  }
}
