import 'package:flutter/material.dart';

import 'app_buttons.dart';

enum AppViewState { content, loading, empty, error }

class AppViewStateSelector extends StatelessWidget {
  const AppViewStateSelector({
    required this.state,
    required this.onChanged,
    super.key,
  });

  final AppViewState state;
  final ValueChanged<AppViewState> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: <Widget>[
        Text('View State', style: Theme.of(context).textTheme.labelLarge),
        SegmentedButton<AppViewState>(
          segments: const <ButtonSegment<AppViewState>>[
            ButtonSegment<AppViewState>(
              value: AppViewState.content,
              label: Text('Content'),
            ),
            ButtonSegment<AppViewState>(
              value: AppViewState.loading,
              label: Text('Loading'),
            ),
            ButtonSegment<AppViewState>(
              value: AppViewState.empty,
              label: Text('Empty'),
            ),
            ButtonSegment<AppViewState>(
              value: AppViewState.error,
              label: Text('Error'),
            ),
          ],
          selected: <AppViewState>{state},
          onSelectionChanged: (Set<AppViewState> selection) {
            onChanged(selection.first);
          },
        ),
      ],
    );
  }
}

class AppStateBody extends StatelessWidget {
  const AppStateBody({
    required this.state,
    required this.content,
    this.loadingBuilder,
    this.loadingMessage = 'Loading...',
    this.emptyTitle = 'Nothing to show',
    this.emptyMessage = 'No content available yet.',
    this.errorTitle = 'Something went wrong',
    this.errorMessage = 'Please try again.',
    this.onRetry,
    super.key,
  });

  final AppViewState state;
  final Widget content;
  final WidgetBuilder? loadingBuilder;
  final String loadingMessage;
  final String emptyTitle;
  final String emptyMessage;
  final String errorTitle;
  final String errorMessage;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return switch (state) {
      AppViewState.content => content,
      AppViewState.loading =>
        loadingBuilder?.call(context) ??
            AppLoadingView(message: loadingMessage),
      AppViewState.empty => AppEmptyView(
        title: emptyTitle,
        message: emptyMessage,
      ),
      AppViewState.error => AppErrorView(
        title: errorTitle,
        message: errorMessage,
        onRetry: onRetry,
      ),
    };
  }
}

class AppLoadingView extends StatelessWidget {
  const AppLoadingView({this.message = 'Loading...', super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const CircularProgressIndicator(),
          const SizedBox(height: 12),
          Text(message),
        ],
      ),
    );
  }
}

class AppEmptyView extends StatelessWidget {
  const AppEmptyView({
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    super.key,
  });

  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.inbox_outlined,
              size: 42,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(message, textAlign: TextAlign.center),
            if (actionLabel != null && onAction != null) ...<Widget>[
              const SizedBox(height: 12),
              AppSecondaryButton(label: actionLabel!, onPressed: onAction),
            ],
          ],
        ),
      ),
    );
  }
}

class AppErrorView extends StatelessWidget {
  const AppErrorView({
    required this.title,
    required this.message,
    this.onRetry,
    super.key,
  });

  final String title;
  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.error_outline,
              size: 42,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(message, textAlign: TextAlign.center),
            if (onRetry != null) ...<Widget>[
              const SizedBox(height: 12),
              AppSecondaryButton(label: 'Retry', onPressed: onRetry),
            ],
          ],
        ),
      ),
    );
  }
}
