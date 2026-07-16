import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/debug/debug_config.dart';
import '../../../core/l10n/l10n.dart';
import '../../../shared/utils/giphy_service.dart';

Future<void> showGifPickerSheet(
  BuildContext context, {
  required void Function(String gifUrl) onSelected,
}) async {
  DebugConfig.log(DebugConfig.uiInteraction, 'GifPickerSheet: shown');
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (_) => _GifPickerSheetContent(onSelected: onSelected),
  );
}

class _GifPickerSheetContent extends StatefulWidget {
  final void Function(String gifUrl) onSelected;

  const _GifPickerSheetContent({required this.onSelected});

  @override
  State<_GifPickerSheetContent> createState() => _GifPickerSheetContentState();
}

class _GifPickerSheetContentState extends State<_GifPickerSheetContent> {
  final _searchCtrl = TextEditingController();
  final _focusNode = FocusNode();
  List<GiphyGif> _results = [];
  bool _loading = true;
  bool _error = false;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _loadTrending();
    _focusNode.requestFocus();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _focusNode.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _loadTrending() async {
    setState(() { _loading = true; _error = false; });
    try {
      final results = await GiphyService.trending();
      if (mounted) setState(() { _results = results; _loading = false; });
    } catch (e) {
      DebugConfig.error('GifPickerSheet: trending failed', data: e);
      if (mounted) setState(() { _error = true; _loading = false; });
    }
  }

  Future<void> _search(String query) async {
    if (query.trim().isEmpty) {
      await _loadTrending();
      return;
    }
    setState(() { _loading = true; _error = false; });
    try {
      final results = await GiphyService.search(query.trim());
      if (mounted) setState(() { _results = results; _loading = false; });
    } catch (e) {
      DebugConfig.error('GifPickerSheet: search failed', data: e);
      if (mounted) setState(() { _error = true; _loading = false; });
    }
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () => _search(value));
  }

  void _onSelectGif(GiphyGif gif) {
    DebugConfig.log(DebugConfig.uiInteraction, 'GifPickerSheet: selected');
    widget.onSelected(gif.url);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final greek = L10n.isGreek(context);
    final theme = Theme.of(context);
    final screenHeight = MediaQuery.of(context).size.height;
    final sheetHeight = MediaQuery.of(context).orientation == Orientation.landscape
        ? screenHeight * 0.75
        : screenHeight * 0.60;

    return SizedBox(
      height: sheetHeight,
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.only(
              top: 12, left: 16, right: 16,
              bottom: MediaQuery.of(context).padding.bottom + 8,
            ),
            child: TextField(
              controller: _searchCtrl,
              focusNode: _focusNode,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: greek ? 'Αναζήτηση GIF...' : 'Search GIFs...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24)),
                filled: true,
                fillColor: theme.colorScheme.surfaceContainerHighest.withAlpha(80),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
            ),
          ),
          Expanded(child: _buildContent(greek, theme)),
        ],
      ),
    );
  }

  Widget _buildContent(bool greek, ThemeData theme) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48,
                color: theme.colorScheme.error),
            const SizedBox(height: 12),
            Text(
              greek ? 'Σφάλμα φόρτωσης' : 'Failed to load',
              style: theme.textTheme.bodyLarge,
            ),
            const SizedBox(height: 12),
            FilledButton.tonal(
              onPressed: _searchCtrl.text.trim().isEmpty
                  ? _loadTrending
                  : () => _search(_searchCtrl.text),
              child: Text(greek ? 'Δοκίμασε ξανά' : 'Retry'),
            ),
          ],
        ),
      );
    }

    if (_results.isEmpty) {
      return Center(
        child: Text(
          greek ? 'Δεν βρέθηκαν GIF' : 'No GIFs found',
          style: theme.textTheme.bodyLarge
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 1,
      ),
      itemCount: _results.length,
      itemBuilder: (_, i) {
        final gif = _results[i];
        return GestureDetector(
          onTap: () => _onSelectGif(gif),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: CachedNetworkImage(
              imageUrl: gif.previewUrl,
              fit: BoxFit.cover,
              placeholder: (_, _) => Container(
                color: theme.colorScheme.surfaceContainerHighest,
              ),
              errorWidget: (_, _, _) => Container(
                color: theme.colorScheme.surfaceContainerHighest,
                child: Icon(Icons.broken_image,
                    color: theme.colorScheme.onSurfaceVariant),
              ),
            ),
          ),
        );
      },
    );
  }
}
