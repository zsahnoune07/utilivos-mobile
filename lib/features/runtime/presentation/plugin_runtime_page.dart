import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

import '../../../core/entitlement/entitlement_controller.dart';
import '../../../core/networking/network_exception.dart';
import '../../../core/pro/paywall_coordinator.dart';
import '../../../core/pro/paywall_models.dart';
import '../../../core/pro/pro_analytics.dart';
import '../../../core/pro/pro_capability_service.dart';
import '../../../core/pro/tool_gate.dart';
import '../../../core/pro/tool_session_store.dart';
import '../../../core/theme/app_design_tokens.dart';
import '../../../shared/widgets/app_state_views.dart';
import '../../discover/data/catalog_api.dart';
import '../../discover/data/models/catalog_models.dart';
import '../../downloads/application/tool_bundle_download_service.dart';
import '../../downloads/data/download_api.dart';
import '../../downloads/data/models/downloaded_tool_bundle.dart';

class PluginRuntimePage extends StatefulWidget {
  const PluginRuntimePage({
    required this.pluginSlug,
    this.initialToolName,
    this.restoreSessionRequested = false,
    required this.catalogApi,
    required this.downloadApi,
    required this.toolBundleDownloadService,
    required this.entitlementController,
    required this.proCapabilityService,
    required this.paywallCoordinator,
    required this.toolSessionStore,
    required this.proAnalytics,
    super.key,
  });

  final String pluginSlug;
  final String? initialToolName;
  final bool restoreSessionRequested;
  final CatalogApi catalogApi;
  final DownloadApi downloadApi;
  final ToolBundleDownloadService toolBundleDownloadService;
  final EntitlementController entitlementController;
  final ProCapabilityService proCapabilityService;
  final PaywallCoordinator paywallCoordinator;
  final ToolSessionStore toolSessionStore;
  final ProAnalytics proAnalytics;

  @override
  State<PluginRuntimePage> createState() => _PluginRuntimePageState();
}

class _PluginRuntimePageState extends State<PluginRuntimePage> {
  static const MethodChannel _runtimeChannel = MethodChannel(
    'com.utilivo.utilivo_mobile/runtime',
  );

  AppViewState _viewState = AppViewState.loading;
  String _statusMessage = 'Preparing tool runtime...';
  String? _errorMessage;
  WebViewController? _webViewController;
  String? _toolName;
  double? _downloadProgress;
  bool _isPreparing = false;
  bool _previewMode = false;
  static const Duration _proOfflineWindow = Duration(hours: 72);

  @override
  void initState() {
    super.initState();
    _toolName = widget.initialToolName;
    unawaited(
      widget.proCapabilityService.recordToolEngagement(widget.pluginSlug),
    );
    unawaited(_prepareAndLoad());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    unawaited(_injectThemeIntoWebView());
  }

  Future<void> _prepareAndLoad() async {
    if (_isPreparing) {
      return;
    }
    _isPreparing = true;

    setState(() {
      _viewState = AppViewState.loading;
      _statusMessage = 'Preparing tool runtime...';
      _errorMessage = null;
      _downloadProgress = null;
    });

    try {
      final preparedBundle = await _resolveBundle();
      final entryFilePath = preparedBundle.entryFilePath;
      if (entryFilePath == null || entryFilePath.trim().isEmpty) {
        throw const _RuntimeLaunchException(
          'Bundle is missing plugin entry metadata.',
        );
      }

      final entryFile = File(entryFilePath);
      if (!await entryFile.exists()) {
        throw const _RuntimeLaunchException(
          'Plugin entry file is missing from local storage.',
        );
      }
      if (!mounted) {
        return;
      }

      final preview = CatalogPlugin.tierIsPro(preparedBundle.verifiedTier ?? '') &&
          !widget.entitlementController.hasProAccess;
      _previewMode = preview;

      final webViewController = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(Theme.of(context).colorScheme.surface)
        ..addJavaScriptChannel(
          'UtilivoHost',
          onMessageReceived: (JavaScriptMessage message) {
            unawaited(_handleHostMessage(message.message));
          },
        )
        ..setNavigationDelegate(
          NavigationDelegate(
            onPageFinished: (_) {
              unawaited(_injectThemeIntoWebView());
              unawaited(_injectHostBootstrap());
            },
            onWebResourceError: (WebResourceError error) {
              if (!mounted) {
                return;
              }
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Runtime load error: ${error.description}'),
                ),
              );
            },
          ),
        );
      await _configureLocalBundleAccess(webViewController);
      await webViewController.loadFile(entryFile.path);

      if (!mounted) {
        return;
      }

      setState(() {
        _webViewController = webViewController;
        _viewState = AppViewState.content;
        _toolName = preparedBundle.pluginName ?? widget.pluginSlug;
      });
      unawaited(_injectThemeIntoWebView());
      unawaited(_injectHostBootstrap());
    } on NetworkException catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _viewState = AppViewState.error;
        _errorMessage =
            'Tool files are not ready on this device yet. Connect once to finish preparing this tool, then it will run offline.';
      });
    } on _RuntimeLaunchException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _viewState = AppViewState.error;
        _errorMessage = error.message;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _viewState = AppViewState.error;
        _errorMessage = 'Failed to start tool runtime: $error';
      });
    } finally {
      _isPreparing = false;
    }
  }

  Future<DownloadedToolBundle> _resolveBundle() async {
    final cached = await widget.toolBundleDownloadService.findRunnableBundle(
      widget.pluginSlug,
    );
    if (cached != null) {
      await _assertBundleLaunchAllowed(cached);
      if (mounted) {
        setState(() {
          _statusMessage = 'Loading local plugin bundle...';
        });
      }
      return cached;
    }

    if (mounted) {
      setState(() {
        _statusMessage = 'Preparing tool files for first run...';
      });
    }

    CatalogPlugin plugin;
    try {
      plugin = await widget.catalogApi.getPluginBySlug(widget.pluginSlug);
    } on NetworkException {
      throw const _RuntimeLaunchException(
        'Tool files are not ready on this device yet. Connect once to prepare this tool, then it will run offline.',
      );
    }

    final assertionToken = await _resolveAssertionToken(plugin);

    final grant = await widget.downloadApi.requestDownload(
      pluginSlug: widget.pluginSlug,
      entitlementAssertionToken: assertionToken,
    );

    if (mounted) {
      setState(() {
        _toolName = plugin.name;
        _statusMessage = 'Downloading tool files...';
      });
    }

    final downloaded = await widget.toolBundleDownloadService.downloadBundle(
      pluginSlug: widget.pluginSlug,
      grant: grant,
      onProgress: (double progress) {
        if (!mounted) {
          return;
        }
        setState(() {
          _downloadProgress = progress.clamp(0, 1);
        });
      },
    );

    if (!downloaded.isRunnable) {
      throw const _RuntimeLaunchException(
        'Tool files were downloaded but runtime preparation failed.',
      );
    }
    await _assertBundleLaunchAllowed(downloaded);
    return downloaded;
  }

  Future<void> _assertBundleLaunchAllowed(DownloadedToolBundle bundle) async {
    final rawTier = bundle.verifiedTier?.trim();
    if (rawTier == null || rawTier.isEmpty) {
      throw const _RuntimeLaunchException(
        'Bundle metadata is not verified. Reinstall this tool from Tool Library.',
      );
    }
    if (!CatalogPlugin.tierIsPro(rawTier)) {
      return;
    }
    if (widget.entitlementController.hasProAccess) {
      final entitlement = widget.entitlementController.entitlement;
      final now = DateTime.now().toUtc();
      final referenceTime =
          entitlement.lastVerificationAt ?? bundle.entitlementVerifiedAt;
      final hasRecentVerification =
          referenceTime != null &&
          now.difference(referenceTime.toUtc()) <= _proOfflineWindow;
      if (!entitlement.proActive || !hasRecentVerification) {
        throw const _RuntimeLaunchException(
          'Pro authorization expired or missing. Reconnect and verify entitlement to continue.',
        );
      }
      return;
    }
    // Pro-tier bundle without subscription: preview mode (catalog allowed install).
  }

  Future<void> _configureLocalBundleAccess(WebViewController controller) async {
    if (!Platform.isAndroid) {
      return;
    }
    final platformController = controller.platform;
    if (platformController is! AndroidWebViewController) {
      return;
    }
    try {
      await _runtimeChannel.invokeMethod<void>(
        'configureToolRuntimeWebView',
        <String, Object>{
          'webViewIdentifier': platformController.webViewIdentifier,
        },
      );
    } on MissingPluginException {
      // Ignore when the Android bridge is unavailable.
    }
  }

  Future<String?> _resolveAssertionToken(CatalogPlugin plugin) async {
    if (!plugin.isPro) {
      return null;
    }
    if (widget.entitlementController.hasProAccess) {
      var assertionToken = widget.entitlementController.activeAssertionToken;
      if (assertionToken != null && assertionToken.trim().isNotEmpty) {
        return assertionToken;
      }
      await widget.entitlementController.backgroundReverify(
        reason: 'runtime_launch',
      );
      assertionToken = widget.entitlementController.activeAssertionToken;
      if (assertionToken != null && assertionToken.trim().isNotEmpty) {
        return assertionToken;
      }
      throw const _RuntimeLaunchException(
        'Pro verification is required before first run. Connect once and try again.',
      );
    }
    if (plugin.proPreview) {
      return null;
    }
    throw const _RuntimeLaunchException(
      'This tool requires Pro. Subscribe to install and run the full version.',
    );
  }

  Future<void> _handleHostMessage(String raw) async {
    if (!mounted) {
      return;
    }
    Map<String, dynamic>? data;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        data = decoded;
      }
    } catch (_) {
      return;
    }
    if (data == null) {
      return;
    }
    final type = data['type']?.toString();
    final id = data['id']?.toString() ?? '';

    switch (type) {
      case 'gate':
        final action = data['action']?.toString() ?? '';
        if (widget.proCapabilityService.hasProAccess) {
          _emitHostReply(<String, Object?>{'id': id, 'allowed': true});
          return;
        }
        widget.proAnalytics.blockedFeatureAttempted(
          featureId: analyticsIdForGateAction(action),
          source: 'tool_runtime',
        );
        await widget.paywallCoordinator.show(
          context,
          PaywallRequest(
            trigger: PaywallTrigger.hardGate,
            triggerSource: 'tool_runtime_gate',
            blockedFeatureId: action,
            contextMessage: paywallContextForGateAction(action),
          ),
        );
        _emitHostReply(<String, Object?>{'id': id, 'allowed': false});
        return;
      case 'persistState':
        final payload = data['payload'];
        if (payload is String) {
          await widget.toolSessionStore.writeStateJson(
            widget.pluginSlug,
            payload,
          );
        }
        _emitHostReply(<String, Object?>{'id': id, 'ok': true});
        return;
      case 'loadState':
        final json = await widget.toolSessionStore.readStateJson(
          widget.pluginSlug,
        );
        _emitHostReply(<String, Object?>{
          'id': id,
          'payload': json,
        });
        return;
      case 'recordStorage':
        if (!widget.proCapabilityService.canPerformStorageAction()) {
          await widget.paywallCoordinator.show(
            context,
            PaywallRequest(
              trigger: PaywallTrigger.limitReached,
              triggerSource: 'storage_quota',
              contextMessage: paywallContextForGateAction('storage'),
            ),
          );
          _emitHostReply(<String, Object?>{'id': id, 'ok': false});
          return;
        }
        await widget.proCapabilityService.recordStorageActionConsumed();
        _emitHostReply(<String, Object?>{'id': id, 'ok': true});
        return;
      case 'pinHomeShortcut':
        if (!widget.proCapabilityService.canAddHomeScreenLaunchers) {
          await widget.paywallCoordinator.show(
            context,
            const PaywallRequest(
              trigger: PaywallTrigger.contextualFeature,
              triggerSource: 'home_shortcut',
              blockedFeatureId: 'home_shortcut',
              contextMessage: 'Pin tools to your home screen with Pro.',
            ),
          );
          _emitHostReply(<String, Object?>{'id': id, 'ok': false});
          return;
        }
        final label = (data['label']?.toString().trim().isNotEmpty ?? false)
            ? data['label'].toString()
            : (widget.initialToolName ?? widget.pluginSlug);
        try {
          final ok = await _runtimeChannel.invokeMethod<bool>(
            'requestPinToolShortcut',
            <String, Object>{
              'pluginSlug': widget.pluginSlug,
              'toolName': label,
            },
          );
          _emitHostReply(<String, Object?>{'id': id, 'ok': ok ?? false});
        } catch (_) {
          _emitHostReply(<String, Object?>{'id': id, 'ok': false});
        }
        return;
      default:
        return;
    }
  }

  void _emitHostReply(Map<String, Object?> detail) {
    final controller = _webViewController;
    if (controller == null) {
      return;
    }
    final encoded = jsonEncode(detail);
    unawaited(
      controller.runJavaScript(
        'document.dispatchEvent(new CustomEvent("utilivo-host-reply", { detail: $encoded }));',
      ),
    );
  }

  Future<void> _injectHostBootstrap() async {
    final webViewController = _webViewController;
    if (webViewController == null || !mounted) {
      return;
    }

    final cap = widget.proCapabilityService;
    final snapshot = <String, Object?>{
      'previewMode': _previewMode,
      'hasPro': widget.entitlementController.hasProAccess,
      'persistAllowed': cap.canPersistToolState,
      'restoreRequested': widget.restoreSessionRequested,
      'storageRemaining': cap.remainingFreeStorageActionsToday,
      'slug': widget.pluginSlug,
      'canPinShortcut': cap.canAddHomeScreenLaunchers,
    };
    final snapshotJson = jsonEncode(snapshot);

    String? initialState;
    if (widget.restoreSessionRequested && cap.canRestoreSession) {
      initialState = await widget.toolSessionStore.readStateJson(
        widget.pluginSlug,
      );
    }
    final stateInit = initialState == null
        ? 'window.__UTILIVO_INITIAL_STATE__ = null;'
        : 'window.__UTILIVO_INITIAL_STATE__ = JSON.parse(${jsonEncode(initialState)});';

    final script =
        '''
(() => {
  const snapshot = $snapshotJson;
  window.__UTILIVO_HOST__ = snapshot;
  $stateInit
  if (!window.utilivo) {
    window.utilivo = {
      requestGate(action) {
        return new Promise((resolve) => {
          const id = String(Math.random()).slice(2);
          function onReply(e) {
            if (!e || !e.detail || e.detail.id !== id) return;
            document.removeEventListener('utilivo-host-reply', onReply);
            resolve(!!e.detail.allowed);
          }
          document.addEventListener('utilivo-host-reply', onReply);
          UtilivoHost.postMessage(JSON.stringify({ type: 'gate', id, action: String(action || '') }));
        });
      },
      persistState(payload) {
        return new Promise((resolve) => {
          const id = String(Math.random()).slice(2);
          function onReply(e) {
            if (!e || !e.detail || e.detail.id !== id) return;
            document.removeEventListener('utilivo-host-reply', onReply);
            resolve(!!e.detail.ok);
          }
          document.addEventListener('utilivo-host-reply', onReply);
          UtilivoHost.postMessage(JSON.stringify({ type: 'persistState', id, payload: typeof payload === 'string' ? payload : JSON.stringify(payload) }));
        });
      },
      loadState() {
        return new Promise((resolve) => {
          const id = String(Math.random()).slice(2);
          function onReply(e) {
            if (!e || !e.detail || e.detail.id !== id) return;
            document.removeEventListener('utilivo-host-reply', onReply);
            resolve(e.detail.payload != null ? e.detail.payload : null);
          }
          document.addEventListener('utilivo-host-reply', onReply);
          UtilivoHost.postMessage(JSON.stringify({ type: 'loadState', id }));
        });
      },
      recordStorageAction() {
        return new Promise((resolve) => {
          const id = String(Math.random()).slice(2);
          function onReply(e) {
            if (!e || !e.detail || e.detail.id !== id) return;
            document.removeEventListener('utilivo-host-reply', onReply);
            resolve(!!e.detail.ok);
          }
          document.addEventListener('utilivo-host-reply', onReply);
          UtilivoHost.postMessage(JSON.stringify({ type: 'recordStorage', id }));
        });
      },
      requestPinHomeShortcut(label) {
        return new Promise((resolve) => {
          const id = String(Math.random()).slice(2);
          function onReply(e) {
            if (!e || !e.detail || e.detail.id !== id) return;
            document.removeEventListener('utilivo-host-reply', onReply);
            resolve(!!e.detail.ok);
          }
          document.addEventListener('utilivo-host-reply', onReply);
          UtilivoHost.postMessage(JSON.stringify({ type: 'pinHomeShortcut', id, label: label || '' }));
        });
      }
    };
  }
})();
''';

    try {
      await webViewController.runJavaScript(script);
    } catch (_) {}
  }

  Future<void> _injectThemeIntoWebView() async {
    final webViewController = _webViewController;
    if (webViewController == null || !mounted) {
      return;
    }

    final payload = AppDesignTokens.webThemePayload(
      Theme.of(context).brightness,
    );
    final encodedPayload = jsonEncode(payload);
    final script =
        '''
(() => {
  const payload = $encodedPayload;
  const root = document.documentElement;
  if (!root || !payload || typeof payload !== 'object') {
    return;
  }

  const mode = payload.mode === 'dark' ? 'dark' : 'light';
  root.setAttribute('data-uv-theme', mode);

  if (payload.tokens && typeof payload.tokens === 'object') {
    Object.entries(payload.tokens).forEach(([key, value]) => {
      if (!key.startsWith('--uv-')) {
        return;
      }
      if (typeof value !== 'string' || value.trim().length === 0) {
        return;
      }
      root.style.setProperty(key, value.trim());
    });
  }

  window.UtilivoUI?.applyThemePayload?.(payload);
})();
''';

    try {
      await webViewController.runJavaScript(script);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: Text(
          _toolName ?? widget.pluginSlug,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                fontSize: 22,
              ),
        ),
        backgroundColor: Theme.of(context).colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        actions: <Widget>[
          if (_previewMode)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Center(
                child: Chip(
                  label: const Text('Preview'),
                  visualDensity: VisualDensity.compact,
                  side: BorderSide.none,
                  backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
                ),
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: AppStateBody(
          state: _viewState,
          loadingBuilder: _buildLoading,
          loadingMessage: _statusMessage,
          errorTitle: 'Could not launch tool',
          errorMessage: _errorMessage ?? 'Unexpected runtime startup failure.',
          onRetry: _prepareAndLoad,
          content: _buildContent(),
        ),
      ),
    );
  }

  Widget _buildLoading(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const CircularProgressIndicator(),
            const SizedBox(height: 12),
            Text(_statusMessage, textAlign: TextAlign.center),
            if (_downloadProgress != null) ...<Widget>[
              const SizedBox(height: 12),
              LinearProgressIndicator(value: _downloadProgress),
              const SizedBox(height: 6),
              Text('${(_downloadProgress! * 100).toStringAsFixed(0)}%'),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    final webViewController = _webViewController;
    if (webViewController == null) {
      return const AppErrorView(
        title: 'Runtime not ready',
        message: 'Web runtime is not initialized.',
      );
    }

    return ColoredBox(
      color: Theme.of(context).colorScheme.surface,
      child: WebViewWidget(controller: webViewController),
    );
  }
}

class _RuntimeLaunchException implements Exception {
  const _RuntimeLaunchException(this.message);

  final String message;
}
