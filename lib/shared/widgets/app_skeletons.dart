import 'package:flutter/material.dart';

class AppSkeletonBox extends StatefulWidget {
  const AppSkeletonBox({
    required this.width,
    required this.height,
    this.borderRadius = 8,
    super.key,
  });

  final double width;
  final double height;
  final double borderRadius;

  @override
  State<AppSkeletonBox> createState() => _AppSkeletonBoxState();
}

class _AppSkeletonBoxState extends State<AppSkeletonBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    duration: const Duration(milliseconds: 900),
    vsync: this,
  )..repeat(reverse: true);
  late final Animation<double> _opacity = Tween<double>(
    begin: 0.5,
    end: 1,
  ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.surfaceContainerHighest;
    return FadeTransition(
      opacity: _opacity,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(widget.borderRadius),
        ),
        child: SizedBox(width: widget.width, height: widget.height),
      ),
    );
  }
}

class AppCardSkeleton extends StatelessWidget {
  const AppCardSkeleton({this.lines = 2, super.key});

  final int lines;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant,
          width: 0.8,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const AppSkeletonBox(width: 52, height: 52, borderRadius: 10),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const AppSkeletonBox(width: 140, height: 14),
                  const SizedBox(height: 8),
                  const AppSkeletonBox(width: 110, height: 12),
                  for (var i = 0; i < lines; i++) ...<Widget>[
                    const SizedBox(height: 8),
                    AppSkeletonBox(
                      width: i == lines - 1 ? 170 : double.infinity,
                      height: 11,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AppCardSkeletonList extends StatelessWidget {
  const AppCardSkeletonList({this.items = 4, this.lines = 2, super.key});

  final int items;
  final int lines;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        for (var i = 0; i < items; i++) ...<Widget>[
          AppCardSkeleton(lines: lines),
          if (i < items - 1) const SizedBox(height: 10),
        ],
      ],
    );
  }
}

/// Matches [InstalledToolCard] grids on Home: 3 columns, same spacing and aspect ratio.
class AppHomeToolGridSkeleton extends StatelessWidget {
  const AppHomeToolGridSkeleton({this.cells = 9, super.key});

  final int cells;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.86,
      ),
      itemCount: cells,
      itemBuilder: (BuildContext context, int index) {
        return DecoratedBox(
          decoration: BoxDecoration(
            color: scheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: scheme.outlineVariant,
              width: 0.8,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Expanded(
                  child: LayoutBuilder(
                    builder: (BuildContext context, BoxConstraints c) {
                      final side = c.maxWidth < c.maxHeight
                          ? c.maxWidth
                          : c.maxHeight;
                      return Center(
                        child: AppSkeletonBox(
                          width: side,
                          height: side,
                          borderRadius: 12,
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 8),
                LayoutBuilder(
                  builder: (BuildContext context, BoxConstraints c) {
                    final w = c.maxWidth;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        AppSkeletonBox(
                          width: w * 0.88,
                          height: 10,
                          borderRadius: 4,
                        ),
                        const SizedBox(height: 6),
                        AppSkeletonBox(
                          width: w * 0.55,
                          height: 9,
                          borderRadius: 4,
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
