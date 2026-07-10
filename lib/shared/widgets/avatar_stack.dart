import 'package:flutter/material.dart';

class AvatarStack extends StatelessWidget {
  final List<String> uids;
  final Map<String, String>? nicknames;
  final int maxVisible;
  final double size;

  const AvatarStack({
    super.key,
    required this.uids,
    this.nicknames,
    this.maxVisible = 3,
    this.size = 24,
  });

  static const _palette = [
    Color(0xFFE57373),
    Color(0xFF64B5F6),
    Color(0xFF81C784),
    Color(0xFFF06292),
    Color(0xFF4DD0E1),
    Color(0xFFBA68C8),
    Color(0xFFAED581),
    Color(0xFFFFD54F),
  ];

  Color _colorFor(String uid) {
    final hash = uid.hashCode;
    return _palette[(hash % _palette.length).abs()];
  }

  String _initialFor(String uid) {
    if (nicknames?.containsKey(uid) == true) {
      final name = nicknames![uid]!;
      if (name.isNotEmpty) return name[0].toUpperCase();
    }
    return uid.isNotEmpty ? uid[0].toUpperCase() : '?';
  }

  @override
  Widget build(BuildContext context) {
    final visible = uids.take(maxVisible).toList();
    final overflow = uids.length - maxVisible;
    final overlap = size * 0.35;
    final totalWidth = size + (visible.length - 1) * overlap + (overflow > 0 ? size * 0.7 : 0);

    return SizedBox(
      width: totalWidth,
      height: size,
      child: Stack(
        children: [
          for (int i = 0; i < visible.length; i++)
            Positioned(
              left: i * overlap,
              child: CircleAvatar(
                radius: size / 2,
                backgroundColor: _colorFor(visible[i]),
                child: Text(
                  _initialFor(visible[i]),
                  style: TextStyle(
                    fontSize: size * 0.4,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          if (overflow > 0)
            Positioned(
              left: maxVisible * overlap,
              child: CircleAvatar(
                radius: size / 2,
                backgroundColor: Colors.grey.shade500,
                child: Text(
                  '+$overflow',
                  style: TextStyle(
                    fontSize: size * 0.35,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
