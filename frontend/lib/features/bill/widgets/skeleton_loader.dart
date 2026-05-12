import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class SkeletonLoader extends StatelessWidget {
  const SkeletonLoader({super.key});

  static const bgLight = Color(0xFFF6F8FD);
  static const cardWhite = Colors.white;
  static const skeletonGray = Color(0xFFE8EBF4);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Shimmer.fromColors(
        baseColor: skeletonGray,
        highlightColor: const Color(0xFFF6F8FD),
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
      ),
    );
  }

  Widget _buildHeaderCardSkeleton() {
    return Container(
      width: double.infinity,
      height: 96,
      decoration: BoxDecoration(
        color: cardWhite,
        borderRadius: BorderRadius.circular(16),
      ),
    );
  }

  Widget _buildSearchFieldSkeleton() {
    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: cardWhite,
        borderRadius: BorderRadius.circular(14),
      ),
    );
  }

  Widget _buildTitleSkeleton() {
    return Container(
      width: 110,
      height: 20,
      decoration: BoxDecoration(
        color: cardWhite,
        borderRadius: BorderRadius.circular(6),
      ),
    );
  }

  Widget _buildBillCardSkeleton() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardWhite,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: skeletonGray,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 120,
                      height: 16,
                      decoration: BoxDecoration(
                        color: skeletonGray,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: 80,
                      height: 12,
                      decoration: BoxDecoration(
                        color: skeletonGray,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 64,
                height: 28,
                decoration: BoxDecoration(
                  color: skeletonGray,
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                width: 90,
                height: 30,
                decoration: BoxDecoration(
                  color: skeletonGray,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 90,
                height: 30,
                decoration: BoxDecoration(
                  color: skeletonGray,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 44,
                  decoration: BoxDecoration(
                    color: skeletonGray,
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  height: 44,
                  decoration: BoxDecoration(
                    color: skeletonGray,
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}