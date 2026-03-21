import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/bootstrap/app_bootstrap_controller.dart';
import '../../../core/config/app_config.dart';
import '../../../core/navigation/app_routes.dart';
import '../../../core/networking/network_exception.dart';
import '../../../shared/widgets/app_buttons.dart';
import '../../../shared/widgets/app_info_tile.dart';
import '../../../shared/widgets/app_state_views.dart';
import '../../../shared/widgets/app_surface_card.dart';
import '../data/health_api.dart';

class HomePage extends StatefulWidget {
  const HomePage({
    required this.config,
    required this.healthApi,
    required this.bootstrapController,
    super.key,
  });

  final AppConfig config;
  final HealthApi healthApi;
  final AppBootstrapController bootstrapController;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  AppViewState _healthState = AppViewState.content;
  String _healthMessage = 'Tap the button to call /v1/health.';
  bool _isUpdatingDeviceId = false;
  String _deviceMessage = 'Anonymous device ID initialized at startup.';

  Future<void> _checkHealth() async {
    setState(() {
      _healthState = AppViewState.loading;
      _healthMessage = 'Loading...';
    });

    try {
      final health = await widget.healthApi.fetchHealthStatus();
      if (!mounted) {
        return;
      }
      setState(() {
        _healthState = AppViewState.content;
        _healthMessage = 'API status: ${health.status}';
      });
    } on NetworkException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _healthState = AppViewState.error;
        _healthMessage = error.message;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _healthState = AppViewState.error;
        _healthMessage = 'Unexpected error: $error';
      });
    }
  }

  Future<void> _regenerateDeviceId() async {
    setState(() {
      _isUpdatingDeviceId = true;
    });

    await widget.bootstrapController.regenerateDeviceId();
    if (!mounted) {
      return;
    }
    setState(() {
      _deviceMessage = 'Device ID regenerated.';
      _isUpdatingDeviceId = false;
    });
  }

  void _goBack(BuildContext context) {
    if (GoRouter.of(context).canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.home);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Phase 1 Debug Console',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                fontSize: 22,
              ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Back',
          onPressed: () => _goBack(context),
        ),
        backgroundColor: Theme.of(context).colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0.5,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        children: <Widget>[
          AppSurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const AppInfoTile(
                  leading: Icons.network_check,
                  title: 'Networking',
                  subtitle: 'Health endpoint smoke checks',
                ),
                const SizedBox(height: 8),
                Text('API base URL: ${widget.config.apiBaseUrl}'),
                const SizedBox(height: 12),
                SizedBox(
                  height: 130,
                  child: AppStateBody(
                    state: _healthState,
                    loadingMessage: 'Checking API health...',
                    errorTitle: 'Health check failed',
                    errorMessage: _healthMessage,
                    onRetry: _checkHealth,
                    content: Center(child: Text(_healthMessage)),
                  ),
                ),
                const SizedBox(height: 12),
                AppPrimaryButton(
                  label: 'Check /v1/health',
                  onPressed: _checkHealth,
                  isLoading: _healthState == AppViewState.loading,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          AppSurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const AppInfoTile(
                  leading: Icons.phone_android_outlined,
                  title: 'Device Identity',
                  subtitle: 'Anonymous device-id diagnostics',
                ),
                const SizedBox(height: 8),
                Text(_deviceMessage),
                const SizedBox(height: 8),
                SelectableText(
                  widget.bootstrapController.deviceId ?? 'No device ID yet.',
                ),
                const SizedBox(height: 12),
                AppPrimaryButton(
                  label: 'Regenerate Device ID',
                  onPressed: _isUpdatingDeviceId ? null : _regenerateDeviceId,
                  isLoading: _isUpdatingDeviceId,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
