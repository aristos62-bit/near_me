import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/debug/debug_config.dart';
import '../../../core/theme/responsive_utils.dart';
import '../../../shared/widgets/profile_card.dart';
import '../providers/search_provider.dart';

class SearchResultsGrid extends ConsumerStatefulWidget {
  const SearchResultsGrid({super.key});

  @override
  ConsumerState<SearchResultsGrid> createState() => _SearchResultsGridState();
}

class _SearchResultsGridState extends ConsumerState<SearchResultsGrid> {
  static const _scrollThreshold = 0.8;
  final ScrollController _scrollController = ScrollController();
  bool _isLoadingMore = false;

  @override
  void initState() {
    super.initState();
    DebugConfig.log(DebugConfig.uiRebuild, 'SearchResultsGrid init');
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    final state = ref.read(searchProvider);
    if (!state.hasMore || _isLoadingMore) return;
    final pos = _scrollController.position;
    if (pos.pixels >= pos.maxScrollExtent * _scrollThreshold) {
      _triggerLoadMore();
    }
  }

  Future<void> _triggerLoadMore() async {
    if (_isLoadingMore) {
      DebugConfig.log(DebugConfig.uiInteraction, '_triggerLoadMore: skipped (already loading)');
      return;
    }
    _isLoadingMore = true;
    DebugConfig.log(DebugConfig.uiInteraction, '_triggerLoadMore: started');
    try {
      await ref.read(searchProvider.notifier).loadMore();
      DebugConfig.log(DebugConfig.repositoryResult, '_triggerLoadMore: completed');
    } finally {
      if (mounted) _isLoadingMore = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(searchProvider);
    DebugConfig.log(DebugConfig.uiRebuild,
        'SearchResultsGrid built: ${state.results.length} cards');

    return LayoutBuilder(
      builder: (context, constraints) {
        final w = ResponsiveUtils.resolveWidth(context, constraints);
        final isMobile = ResponsiveUtils.isMobileFromWidth(w);
        final hPad = ResponsiveUtils.horizontalPaddingFromWidth(w);

        return ListView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(hPad.left, 12, hPad.right, 24),
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.center,
              children: state.results.map((p) {
                final dist = state.distances[p.uid];
                return ProfileCard(
                  key: ValueKey(p.uid),
                  profile: p,
                  width: isMobile ? double.infinity : 180,
                  distanceKm: dist,
                  onTap: () => context.push('/user/${p.uid}'),
                );
              }).toList(),
            ),
            if (_isLoadingMore || state.hasMore)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              ),
          ],
        );
      },
    );
  }
}
