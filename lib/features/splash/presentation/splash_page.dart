import 'package:flutter/material.dart';

import '../../../core/bootstrap/app_bootstrap_controller.dart';
import '../../../shared/widgets/app_buttons.dart';

class SplashPage extends StatelessWidget {
  const SplashPage({required this.bootstrapController, super.key});

  final AppBootstrapController bootstrapController;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: AnimatedBuilder(
            animation: bootstrapController,
            builder: (BuildContext context, Widget? child) {
              if (bootstrapController.hasFailed) {
                return Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(
                        Icons.error_outline,
                        size: 48,
                        color: Theme.of(context).colorScheme.error,
                      ),
                      const SizedBox(height: 12),
                      const Text('Startup failed'),
                      const SizedBox(height: 8),
                      Text(
                        bootstrapController.errorMessage ??
                            'Could not initialize app bootstrap.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      AppPrimaryButton(
                        label: 'Retry',
                        onPressed: bootstrapController.retryBootstrap,
                      ),
                    ],
                  ),
                );
              }

              return const Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Preparing Utilivos...'),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
