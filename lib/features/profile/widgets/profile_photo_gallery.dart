import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';

/// Move-only από `profile_editor_screen` (Γ7, όριο 500 γραμμών).
class ProfilePhotoGallery extends StatelessWidget {
  final List<String> photoUrls;
  final int? uploadingIndex;
  final ValueChanged<int> onAdd;
  final ValueChanged<int> onRemove;
  final bool isGreek;

  const ProfilePhotoGallery({
    super.key,
    required this.photoUrls,
    required this.uploadingIndex,
    required this.onAdd,
    required this.onRemove,
    required this.isGreek,
  });

  @override
  Widget build(BuildContext context) {
    final g = isGreek;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (var i = 0; i < photoUrls.length; i++)
          Stack(children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: CachedNetworkImage(
                imageUrl: photoUrls[i],
                width: 100,
                height: 100,
                fit: BoxFit.cover,
                placeholder: (_, _) => Container(
                    color: Colors.grey.shade200,
                    child: const Center(
                        child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2)))),
                errorWidget: (_, _, _) => Container(
                    color: Colors.grey.shade200,
                    child: const Icon(Icons.broken_image)),
              ),
            ),
            Positioned(
                top: 4,
                right: 4,
                child: GestureDetector(
                    onTap: () => onRemove(i),
                    child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: const BoxDecoration(
                            color: Colors.black54, shape: BoxShape.circle),
                        child: const Icon(Icons.close,
                            size: 14, color: Colors.white)))),
            if (uploadingIndex == i)
              Positioned.fill(
                  child: Container(
                      decoration: BoxDecoration(
                          color: Colors.black26,
                          borderRadius: BorderRadius.circular(10)),
                      child: const Center(
                          child: SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))))),
          ]),
        if (photoUrls.length < 5)
          GestureDetector(
              onTap: () => onAdd(photoUrls.length),
              child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(10)),
                  child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_photo_alternate_outlined,
                            color: AppColors.primary),
                        const SizedBox(height: 4),
                        Text(g ? 'Προσθήκη' : 'Add',
                            style: AppTypography.caption
                                .copyWith(color: AppColors.primary)),
                      ]))),
      ]),
      Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(g ? 'Μέχρι 5 φωτογραφίες' : 'Up to 5 photos',
              style: AppTypography.caption
                  .copyWith(color: AppColors.textSecondaryLight))),
    ]);
  }
}
