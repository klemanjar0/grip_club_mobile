import 'package:equatable/equatable.dart';

/// One page of a paginated endpoint, mirroring the API's `PageEnvelope<T>`.
///
/// [page] is **zero-based**, and [hasNext] is derived server-side without a
/// COUNT query — so there is no total count to show, only "is there more".
class PageEnvelope<T> extends Equatable {
  const PageEnvelope({
    required this.items,
    required this.page,
    required this.pageSize,
    required this.hasNext,
  });

  /// [itemFromJson] parses one element; the list itself is never null per the
  /// API contract, but a missing or malformed key must not crash the feed.
  factory PageEnvelope.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic> json) itemFromJson,
  ) {
    final rawItems = json['items'];

    return PageEnvelope<T>(
      items: <T>[
        if (rawItems is List)
          for (final item in rawItems)
            if (item is Map<String, dynamic>) itemFromJson(item),
      ],
      page: json['page'] as int? ?? 0,
      pageSize: json['page_size'] as int? ?? defaultPageSize,
      hasNext: json['has_next'] as bool? ?? false,
    );
  }

  /// The API's own default; sent explicitly so paging stays stable if the
  /// server default ever changes.
  static const int defaultPageSize = 10;

  final List<T> items;
  final int page;
  final int pageSize;
  final bool hasNext;

  @override
  List<Object?> get props => [items, page, pageSize, hasNext];
}
