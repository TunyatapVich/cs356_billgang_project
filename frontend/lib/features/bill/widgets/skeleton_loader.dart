import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class SkeletonLoader extends StatelessWidget {
  const SkeletonLoader({super.key});

  static const bgLight = Color(0xFFF6F8FD);
  static const cardWhite = Colors.white;
  static const primaryBlue = Color(0xFF4E54C8);
  static const shimmerBase = Color(0xFFE8EBF4);
  static const shimmerHighlight = Color(0xFFF6F8FD);

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeaderCardSkeleton(),
          const SizedBox(height: 20),
          _buildSearchFieldSkeleton(),
          const SizedBox(height: 20),
          _buildTitleSkeleton(),
          const SizedBox(height: 12),
          _buildBillCardSkeleton(),
          const SizedBox(height: 14),
          _buildBillCardSkeleton(),
          const SizedBox(height: 14),
          _buildBillCardSkeleton(),
        ],
      ),
    );
  }

  Widget _buildHeaderCardSkeleton() {
    return Shimmer.fromColors(
      baseColor: shimmerBase,
      highlightColor: shimmerHighlight,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: cardWhite,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: cardWhite,
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            const SizedBox(width: 16),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: 4),
                  _SkeletonBox(width: 140, height: 18),
                  SizedBox(height: 8),
                  _SkeletonBox(width: 200, height: 13),
                ],
              ),
            ),
            const _SkeletonBox(width: 36, height: 36),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchFieldSkeleton() {
    return Shimmer.fromColors(
      baseColor: shimmerBase,
      highlightColor: shimmerHighlight,
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          color: cardWhite,
          borderRadius: BorderRadius.circular(14),
        ),
      ),
    );
  }

  Widget _buildTitleSkeleton() {
    return Shimmer.fromColors(
      baseColor: shimmerBase,
      highlightColor: shimmerHighlight,
      child: const _SkeletonBox(width: 110, height: 20),
    );
  }

  Widget _buildBillCardSkeleton() {
    return Shimmer.fromColors(
      baseColor: shimmerBase,
      highlightColor: shimmerHighlight,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: cardWhite,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: shimmerBase,
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _SkeletonBox(width: 120, height: 16),
                      const SizedBox(height: 8),
                      const _SkeletonBox(width: 80, height: 12),
                    ],
                  ),
                ),
                Container(
                  width: 60,
                  height: 28,
                  decoration: BoxDecoration(
                    color: shimmerBase,
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const _SkeletonBox(width: 80, height: 30),
                const SizedBox(width: 8),
                const _SkeletonBox(width: 100, height: 30),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Expanded(child: _SkeletonBox(width: double.infinity, height: 44)),
                const SizedBox(width: 10),
                const Expanded(child: _SkeletonBox(width: double.infinity, height: 44)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SkeletonBox extends StatelessWidget {
  const _SkeletonBox({
    required this.width,
    required this.height,
  });

  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFFE8EBF4),
        borderRadius: BorderRadius.circular(6),
      ),
    );
  }
}