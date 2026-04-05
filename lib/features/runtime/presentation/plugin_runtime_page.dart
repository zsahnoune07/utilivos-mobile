import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';
import 'dart:math' show Random;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

import '../../../core/config/app_config.dart';
import '../../../core/navigation/app_routes.dart';
import '../../../core/entitlement/entitlement_controller.dart';
import '../../../core/networking/network_exception.dart';
import '../../../core/pro/paywall_coordinator.dart';
import '../../../core/pro/paywall_models.dart';
import '../../../core/pro/pro_analytics.dart';
import '../../../core/pro/pro_capability_service.dart';
import '../../../core/pro/tool_gate.dart';
import '../../../core/pro/tool_session_store.dart';
import '../../../core/sessions/named_tool_session.dart';
import '../../../core/sessions/runtime_state_scope_service.dart';
import '../../../core/sessions/session_snapshot_normalizer.dart';
import '../../../core/sessions/tool_launch_context.dart';
import '../../../core/sessions/tool_session_service.dart';
import '../../../core/sessions/tool_widget_service.dart';
import '../../../core/permissions/tool_permission_coordinator.dart';
import '../../../core/theme/app_design_tokens.dart';
import '../../../core/tool_manifest/tool_manifest_reader.dart';
import '../../../core/versioning/app_version_compare.dart';
import '../../../core/versioning/plugin_version_compare.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/app_state_views.dart';
import '../../installs/application/installed_tools_controller.dart'
    show InstalledToolsController, ToolLaunchPrepared;
import '../../discover/data/catalog_api.dart';
import '../../discover/data/models/catalog_models.dart';
import '../../downloads/application/tool_bundle_download_service.dart';
import '../../downloads/data/download_api.dart';
import '../../downloads/data/models/downloaded_tool_bundle.dart';

class PluginRuntimePage extends StatefulWidget {
  const PluginRuntimePage({
    required this.pluginSlug,
    this.initialToolName,
    required this.launchContext,
    required this.config,
    required this.catalogApi,
    required this.downloadApi,
    required this.toolBundleDownloadService,
    required this.entitlementController,
    required this.proCapabilityService,
    required this.paywallCoordinator,
    required this.toolSessionStore,
    required this.runtimeStateScopeService,
    required this.toolSessionService,
    required this.toolWidgetService,
    required this.proAnalytics,
    required this.installedToolsController,
    super.key,
  });

  final String pluginSlug;
  final String? initialToolName;
  final ToolLaunchContext launchContext;
  final AppConfig config;
  final CatalogApi catalogApi;
  final DownloadApi downloadApi;
  final ToolBundleDownloadService toolBundleDownloadService;
  final EntitlementController entitlementController;
  final ProCapabilityService proCapabilityService;
  final PaywallCoordinator paywallCoordinator;
  final ToolSessionStore toolSessionStore;
  final RuntimeStateScopeService runtimeStateScopeService;
  final ToolSessionService toolSessionService;
  final ToolWidgetService toolWidgetService;
  final ProAnalytics proAnalytics;
  final InstalledToolsController installedToolsController;

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
  DownloadedToolBundle? _loadedBundle;
  CatalogPlugin? _catalogDetail;
  double? _downloadProgress;
  bool _isPreparing = false;
  bool _previewMode = false;
  bool _mandatoryUpdateBlocked = false;
  bool _hostAppUpdateBlocked = false;
  bool _permissionLaunchBlocked = false;
  bool _permissionLaunchPermanent = false;
  bool _clearedSessionStorageForThisLaunch = false;
  String? _namedSessionBarTitle;
  String? _namedSessionBaselineJson;
  bool _namedSessionDirty = false;
  /// When set, user loaded or saved a named session without a route change.
  String? _boundNamedSessionId;
  final Map<String, Completer<bool>> _pendingRestoreCompleters = {};
  final Map<String, Timer> _pendingRestoreTimers = {};
  static const Duration _proOfflineWindow = Duration(hours: 72);
  static const Duration _sessionRestoreAckTimeout = Duration(seconds: 10);
  static const String _sessionLogName = 'SessionRestore';

  @override
  void initState() {
    super.initState();
    _toolName = widget.initialToolName;
    if (widget.launchContext.usesEphemeralPersistence) {
      unawaited(
        widget.toolSessionStore.removeLegacyDiskSnapshotIfExists(
          widget.pluginSlug,
        ),
      );
    }
    unawaited(
      widget.proCapabilityService.recordToolEngagement(widget.pluginSlug),
    );
    if (widget.launchContext.launchMode == ToolLaunchMode.widget &&
        Platform.isAndroid) {
      final wid = widget.launchContext.widgetInstanceId?.trim();
      if (wid != null && wid.isNotEmpty) {
        unawaited(
          widget.toolWidgetService.touchLaunched(
            platform: 'android',
            platformWidgetId: wid,
          ),
        );
      }
    }
    unawaited(_prepareAndLoad());
  }

  @override
  void dispose() {
    for (final Timer t in _pendingRestoreTimers.values) {
      t.cancel();
    }
    _pendingRestoreTimers.clear();
    for (final Completer<bool> c in _pendingRestoreCompleters.values) {
      if (!c.isCompleted) {
        c.complete(false);
      }
    }
    _pendingRestoreCompleters.clear();
    if (widget.launchContext.shouldClearEphemeralOnDispose) {
      unawaited(
        widget.runtimeStateScopeService.clearLaunch(
          widget.launchContext.launchToken,
        ),
      );
    }
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    unawaited(_injectThemeIntoWebView());
  }

  String? _activeNamedSessionId() {
    final String? bound = _boundNamedSessionId?.trim();
    if (bound != null && bound.isNotEmpty) {
      return bound;
    }
    final String? fromRoute = widget.launchContext.sessionId?.trim();
    if (fromRoute != null && fromRoute.isNotEmpty) {
      return fromRoute;
    }
    return null;
  }

  bool get _shouldShowNamedSessionSubBar {
    final String? id = _activeNamedSessionId();
    return id != null && id.isNotEmpty;
  }

  void _sessionRestoreLog(String message, [String? detail]) {
    developer.log(
      detail != null && detail.isNotEmpty ? '$message $detail' : message,
      name: _sessionLogName,
    );
  }

  void _completePendingSessionRestore(String id, bool ok) {
    _pendingRestoreTimers.remove(id)?.cancel();
    final Completer<bool>? c = _pendingRestoreCompleters.remove(id);
    if (c != null && !c.isCompleted) {
      c.complete(ok);
    }
  }

  Future<bool> _requestToolApplySessionSnapshot(String stateJson) async {
    final WebViewController? controller = _webViewController;
    if (controller == null) {
      _sessionRestoreLog('restore_skipped_no_webview');
      return false;
    }
    final String id =
        'rs_${DateTime.now().microsecondsSinceEpoch}_${Random().nextInt(1 << 20)}';
    final Completer<bool> completer = Completer<bool>();
    _pendingRestoreCompleters[id] = completer;
    _pendingRestoreTimers[id] = Timer(_sessionRestoreAckTimeout, () {
      _sessionRestoreLog('restore_timeout', 'requestId=$id');
      _completePendingSessionRestore(id, false);
    });

    final String detailJson = jsonEncode(<String, dynamic>{
      'id': id,
      'stateJson': stateJson,
    });

    _sessionRestoreLog('restore_request_dispatched', 'requestId=$id');

    try {
      await controller.runJavaScript(
        '''
(function(){
  try {
    const detail = $detailJson;
    document.dispatchEvent(new CustomEvent('utilivo-restore-request', { detail: detail }));
  } catch (e) {}
})();
''',
      );
    } catch (error, stackTrace) {
      _sessionRestoreLog('restore_dispatch_failed', '$error');
      developer.log(
        'Session restore JS dispatch failed',
        name: 'PluginRuntimePage',
        error: error,
        stackTrace: stackTrace,
      );
      _completePendingSessionRestore(id, false);
      return false;
    }

    return completer.future;
  }

  Future<void> _prepareAndLoad() async {
    if (_isPreparing) {
      return;
    }
    _isPreparing = true;

    setState(() {
      _mandatoryUpdateBlocked = false;
      _hostAppUpdateBlocked = false;
      _permissionLaunchBlocked = false;
      _permissionLaunchPermanent = false;
      _viewState = AppViewState.loading;
      _statusMessage = 'Preparing tool runtime...';
      _errorMessage = null;
      _downloadProgress = null;
      _loadedBundle = null;
      _catalogDetail = null;
      _namedSessionBarTitle = null;
      _namedSessionBaselineJson = null;
      _namedSessionDirty = false;
      _boundNamedSessionId = null;
    });

    final preparedLaunch = await widget.installedToolsController
        .prepareToolLaunch(widget.pluginSlug);
    if (!mounted) {
      _isPreparing = false;
      return;
    }
    switch (preparedLaunch) {
      case ToolLaunchPrepared.mandatoryUpdateRequired:
        setState(() {
          _mandatoryUpdateBlocked = true;
          _isPreparing = false;
        });
        return;
      case ToolLaunchPrepared.notInstalled:
        setState(() {
          _viewState = AppViewState.error;
          _errorMessage =
              'This tool is no longer installed on this device.';
          _isPreparing = false;
        });
        return;
      case ToolLaunchPrepared.missingBundle:
        setState(() {
          _viewState = AppViewState.error;
          _errorMessage =
              'Tool files were removed. Reinstall this tool from the Tool Library.';
          _isPreparing = false;
        });
        return;
      case ToolLaunchPrepared.ok:
        break;
    }

    final l10nBase =
        AppLocalizations.of(context) ?? lookupAppLocalizations(const Locale('en'));

    final localRunnable = await widget.toolBundleDownloadService
        .findRunnableBundle(widget.pluginSlug);
    if (!mounted) {
      _isPreparing = false;
      return;
    }
    if (localRunnable == null) {
      setState(() {
        _viewState = AppViewState.error;
        _errorMessage =
            'Tool files were removed. Reinstall this tool from the Tool Library.';
        _isPreparing = false;
      });
      return;
    }

    try {
      await _assertBundleLaunchAllowed(localRunnable);
    } on _RuntimeLaunchException catch (error) {
      if (!mounted) {
        _isPreparing = false;
        return;
      }
      setState(() {
        _viewState = AppViewState.error;
        _errorMessage = error.message;
        _isPreparing = false;
      });
      return;
    }

    final manifest = await const ToolManifestReader().readForBundle(
      localRunnable,
    );
    final packageInfo = await PackageInfo.fromPlatform();
    if (!mounted) {
      _isPreparing = false;
      return;
    }
    if (isHostAppBelowMinimum(
      currentAppVersion: packageInfo.version,
      minimumVersion: manifest.minAppVersion,
    )) {
      setState(() {
        _hostAppUpdateBlocked = true;
        _isPreparing = false;
      });
      return;
    }

    final permissionOutcome = await ToolPermissionCoordinator()
        .ensureSystemPermissions(
          context: context,
          manifest: manifest,
          l10n: l10nBase,
        );
    if (!mounted) {
      _isPreparing = false;
      return;
    }
    if (permissionOutcome != ToolPermissionFlowResult.granted) {
      setState(() {
        _permissionLaunchBlocked = true;
        _permissionLaunchPermanent =
            permissionOutcome == ToolPermissionFlowResult.permanentlyDenied;
        _isPreparing = false;
      });
      return;
    }

    try {
      String? namedSessionBarTitle;
      String? namedSessionBaselineJson;
      if (widget.launchContext.launchMode == ToolLaunchMode.widget) {
        if (!mounted) {
          return;
        }
        if (!widget.entitlementController.hasProAccess) {
          var allowedFreeWidget = false;
          if (Platform.isAndroid) {
            final wid = widget.launchContext.widgetInstanceId?.trim();
            if (wid != null && wid.isNotEmpty) {
              final rec = await widget.toolWidgetService.findWidget(
                platform: 'android',
                platformWidgetId: wid,
              );
              allowedFreeWidget = rec != null;
            }
          }
          if (!mounted) {
            return;
          }
          if (!allowedFreeWidget) {
            final l10nGate =
                AppLocalizations.of(context) ??
                lookupAppLocalizations(const Locale('en'));
            await widget.paywallCoordinator.show(
              context,
              PaywallRequest(
                trigger: PaywallTrigger.contextualFeature,
                triggerSource: 'home_widget_open',
                blockedFeatureId: 'home_widget',
                contextMessage: l10nGate.runtimeHomeWidgetProRequired,
              ),
            );
            if (!mounted) {
              return;
            }
            if (!widget.entitlementController.hasProAccess) {
              setState(() {
                _viewState = AppViewState.error;
                _errorMessage = l10nGate.runtimeHomeWidgetProRequired;
                _isPreparing = false;
              });
              return;
            }
          }
        }
      }

      final preparedBundle = await _resolveBundle(seed: localRunnable);
      _assertRuntimeContractCompatible(preparedBundle);
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

      final preview =
          CatalogPlugin.tierIsPro(preparedBundle.verifiedTier ?? '') &&
          !widget.entitlementController.hasProAccess;
      _previewMode = preview;
      final surfaceColor = Theme.of(context).colorScheme.surface;

      if (widget.launchContext.launchMode == ToolLaunchMode.namedSession) {
        if (!mounted) {
          return;
        }
        if (!widget.entitlementController.hasProAccess) {
          final l10nGate =
              AppLocalizations.of(context) ??
              lookupAppLocalizations(const Locale('en'));
          await widget.paywallCoordinator.show(
            context,
            PaywallRequest(
              trigger: PaywallTrigger.contextualFeature,
              triggerSource: 'named_session_open',
              blockedFeatureId: 'named_session',
              contextMessage: l10nGate.runtimeSessionProRequired,
            ),
          );
          if (!mounted) {
            return;
          }
          if (!widget.entitlementController.hasProAccess) {
            setState(() {
              _viewState = AppViewState.error;
              _errorMessage = l10nGate.runtimeSessionProRequired;
              _isPreparing = false;
            });
            return;
          }
        }
        try {
          await _seedEphemeralFromNamedSession(context);
        } on _RuntimeLaunchException catch (error) {
          if (!mounted) {
            return;
          }
          setState(() {
            _viewState = AppViewState.error;
            _errorMessage = error.message;
            _isPreparing = false;
          });
          return;
        }
      }

      if (widget.launchContext.launchMode == ToolLaunchMode.namedSession) {
        final sid = widget.launchContext.sessionId?.trim();
        if (sid != null && sid.isNotEmpty) {
          final row = await widget.toolSessionService.getSession(sid);
          namedSessionBarTitle = row?.name;
        }
        final ep = await widget.runtimeStateScopeService.loadEphemeral(
          widget.launchContext.launchToken,
        );
        namedSessionBaselineJson = ep?.stateJson;
      }

      final webViewController = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(surfaceColor)
        ..addJavaScriptChannel(
          'UtilivoHost',
          onMessageReceived: (JavaScriptMessage message) {
            unawaited(_handleHostMessage(message.message));
          },
        );
      await _configureAndroidToolWebViewFileSelector(webViewController);
      await _configureAndroidToolWebViewMediaPermissions(webViewController);
      webViewController.setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) {
            unawaited(
              _onToolDocumentPageFinished(
                webViewController,
                preparedBundle,
              ),
            );
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
      await _disableToolWebViewZoom(webViewController);
      await _clearEphemeralWebKitLocalStorageIfNeeded(webViewController);
      await _configureLocalBundleAccess(webViewController);
      await _loadRuntimeDocument(
        webViewController: webViewController,
        entryFile: entryFile,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _webViewController = webViewController;
        _viewState = AppViewState.content;
        _toolName = preparedBundle.pluginName ?? widget.pluginSlug;
        _loadedBundle = preparedBundle;
        _namedSessionBarTitle = namedSessionBarTitle;
        _namedSessionBaselineJson = namedSessionBaselineJson;
        _namedSessionDirty = false;
      });
      unawaited(_hydrateCatalogDetail());
      // Theme + host bootstrap run in _onToolDocumentPageFinished after the document
      // loads so tool scripts and bridge injection order stay deterministic.
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

  Future<DownloadedToolBundle> _resolveBundle({
    DownloadedToolBundle? seed,
  }) async {
    if (seed != null) {
      await _assertBundleLaunchAllowed(seed);
      if (mounted) {
        setState(() {
          _statusMessage = 'Loading local plugin bundle...';
        });
      }
      return seed;
    }

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
          'launchToken': widget.launchContext.launchToken,
          'clearWebStorage': widget.launchContext.usesEphemeralPersistence,
        },
      );
    } on MissingPluginException {
      // Ignore when the Android bridge is unavailable.
    }
  }

  /// Ephemeral/widget: clear WKWebView disk localStorage before first navigation.
  Future<void> _clearEphemeralWebKitLocalStorageIfNeeded(
    WebViewController controller,
  ) async {
    if (!widget.launchContext.usesEphemeralPersistence) {
      return;
    }
    if (!Platform.isIOS) {
      return;
    }
    final platform = controller.platform;
    if (platform is! WebKitWebViewController) {
      return;
    }
    try {
      await platform.clearLocalStorage();
    } catch (_) {}
  }

  /// After the tool document loads: sessionStorage hygiene, then theme + host bootstrap.
  Future<void> _onToolDocumentPageFinished(
    WebViewController controller,
    DownloadedToolBundle bundle,
  ) async {
    if (!mounted) {
      return;
    }
    if (widget.launchContext.usesEphemeralPersistence &&
        !_clearedSessionStorageForThisLaunch) {
      _clearedSessionStorageForThisLaunch = true;
      try {
        await controller.runJavaScript(
          'try { sessionStorage.clear(); } catch (e) {}',
        );
      } catch (_) {}
    }
    final displayName = bundle.pluginName ?? widget.initialToolName;
    await _injectThemeIntoWebView(controller);
    await _injectHostBootstrap(controller, bundle, displayName);
  }

  /// Android WebView does not open `<input type="file">` without a file chooser handler.
  Future<void> _configureAndroidToolWebViewFileSelector(
    WebViewController controller,
  ) async {
    if (!Platform.isAndroid) {
      return;
    }
    final Object platform = controller.platform;
    if (platform is! AndroidWebViewController) {
      return;
    }
    await platform.setOnShowFileSelector(_onAndroidToolWebViewShowFileSelector);
  }

  Future<List<String>> _onAndroidToolWebViewShowFileSelector(
    FileSelectorParams params,
  ) async {
    if (params.mode == FileSelectorMode.save) {
      return <String>[];
    }
    if (!mounted) {
      return <String>[];
    }
    try {
      final picker = ImagePicker();
      final XFile? file = await picker.pickImage(source: ImageSource.gallery);
      if (file == null || !mounted) {
        return <String>[];
      }
      final String path = file.path;
      if (path.startsWith('content://') || path.startsWith('file://')) {
        return <String>[path];
      }
      return <String>[Uri.file(path).toString()];
    } catch (_) {
      return <String>[];
    }
  }

  /// Without this, Android WebView denies [getUserMedia] even when the app already
  /// has [Permission.camera] — the page must receive [PermissionRequest.grant].
  Future<void> _configureAndroidToolWebViewMediaPermissions(
    WebViewController controller,
  ) async {
    if (!Platform.isAndroid) {
      return;
    }
    final Object platform = controller.platform;
    if (platform is! AndroidWebViewController) {
      return;
    }
    await platform.setOnPlatformPermissionRequest(_onToolWebViewPermissionRequest);
  }

  void _onToolWebViewPermissionRequest(PlatformWebViewPermissionRequest request) {
    unawaited(_handleToolWebViewPermissionRequest(request));
  }

  Future<void> _handleToolWebViewPermissionRequest(
    PlatformWebViewPermissionRequest request,
  ) async {
    if (kDebugMode) {
      developer.log(
        'types=${request.types}',
        name: 'utilivo.tool_webview.permission',
      );
    }
    final wantsCamera =
        request.types.contains(WebViewPermissionResourceType.camera);
    final wantsMic =
        request.types.contains(WebViewPermissionResourceType.microphone);
    if (wantsMic) {
      await request.deny();
      return;
    }
    if (!wantsCamera) {
      await request.deny();
      return;
    }
    if (!mounted) {
      await request.deny();
      return;
    }
    var status = await Permission.camera.status;
    if (kDebugMode) {
      developer.log(
        'camera status=$status',
        name: 'utilivo.tool_webview.permission',
      );
    }
    if (!status.isGranted) {
      status = await Permission.camera.request();
      if (kDebugMode) {
        developer.log(
          'camera after request=$status',
          name: 'utilivo.tool_webview.permission',
        );
      }
    }
    if (status.isGranted) {
      await request.grant();
    } else {
      await request.deny();
    }
  }

  Future<void> _disableToolWebViewZoom(WebViewController controller) async {
    final Object platform = controller.platform;
    if (platform is AndroidWebViewController) {
      await platform.enableZoom(false);
    } else if (platform is WebKitWebViewController) {
      await platform.enableZoom(false);
    }
  }

  Future<void> _loadRuntimeDocument({
    required WebViewController webViewController,
    required File entryFile,
  }) async {
    await webViewController.loadFile(entryFile.path);
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
          if (widget.launchContext.usesEphemeralPersistence) {
            await widget.runtimeStateScopeService.persistEphemeral(
              launchToken: widget.launchContext.launchToken,
              toolId: widget.launchContext.toolId,
              toolSlug: widget.pluginSlug,
              stateJson: payload,
            );
          } else {
            await widget.toolSessionStore.writeStateJson(
              widget.pluginSlug,
              payload,
            );
          }
          _maybeUpdateNamedSessionDirty(payload);
        }
        _emitHostReply(<String, Object?>{'id': id, 'ok': true});
        return;
      case 'loadState':
        final String? json;
        if (widget.launchContext.usesEphemeralPersistence) {
          final row = await widget.runtimeStateScopeService.loadEphemeral(
            widget.launchContext.launchToken,
          );
          json = row?.stateJson;
        } else {
          json = await widget.toolSessionStore.readStateJson(
            widget.pluginSlug,
          );
        }
        _emitHostReply(<String, Object?>{'id': id, 'payload': json});
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
      case 'restoreAck':
        if (id.isEmpty) {
          return;
        }
        final bool ok = data['ok'] == true;
        final String err = data['error']?.toString() ?? '';
        _sessionRestoreLog(
          ok ? 'restore_ack_ok' : 'restore_ack_fail',
          'requestId=$id err=$err',
        );
        _completePendingSessionRestore(id, ok);
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

  void _maybeUpdateNamedSessionDirty(String payload) {
    final String? sid = _activeNamedSessionId();
    if (sid == null || sid.isEmpty) {
      return;
    }
    if (!widget.entitlementController.hasProAccess) {
      return;
    }
    final baseline = _namedSessionBaselineJson;
    if (baseline == null) {
      return;
    }
    final dirty = payload != baseline;
    if (!mounted || dirty == _namedSessionDirty) {
      return;
    }
    setState(() {
      _namedSessionDirty = dirty;
    });
  }

  Future<void> _injectHostBootstrap([
    WebViewController? controllerOverride,
    DownloadedToolBundle? bundleOverride,
    String? manifestDisplayNameOverride,
  ]) async {
    final webViewController = controllerOverride ?? _webViewController;
    if (webViewController == null || !mounted) {
      return;
    }
    final bundle = bundleOverride ?? _loadedBundle;
    if (bundle == null) {
      return;
    }
    final script = _buildHostBootstrapScript(
      bundle: bundle,
      manifestDisplayName: manifestDisplayNameOverride,
    );
    try {
      await webViewController.runJavaScript(script);
    } catch (_) {
      return;
    }
    try {
      await webViewController.runJavaScript(
        r"try { document.dispatchEvent(new CustomEvent('utilivo-host-ready')); } catch (e) {}",
      );
    } catch (_) {}
  }

  String _encodedWebThemePayload() {
    return jsonEncode(
      AppDesignTokens.webThemePayload(Theme.of(context).brightness),
    );
  }

  String _javaScriptApplyWebThemeUsingPayloadConst() {
    return '''
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
''';
  }

  String _buildHostBootstrapScript({
    required DownloadedToolBundle bundle,
    String? manifestDisplayName,
  }) {
    final cap = widget.proCapabilityService;
    final themeMode = Theme.of(context).brightness == Brightness.dark
        ? 'dark'
        : 'light';
    final toolDisplayName =
        manifestDisplayName?.trim().isNotEmpty == true
            ? manifestDisplayName!.trim()
            : (_toolName ?? widget.initialToolName ?? widget.pluginSlug);
    final snapshot = <String, Object?>{
      'previewMode': _previewMode,
      'hasPro': widget.entitlementController.hasProAccess,
      'persistAllowed': cap.canPersistToolState,
      'restoreRequested': widget.launchContext.legacyRestoreRequested ||
          widget.launchContext.launchMode == ToolLaunchMode.namedSession,
      'launchMode': widget.launchContext.launchMode.name,
      'launchToken': widget.launchContext.launchToken,
      'storageRemaining': cap.remainingFreeStorageActionsToday,
      'slug': widget.pluginSlug,
      'canPinShortcut': cap.canAddHomeScreenLaunchers,
      'runtimeMode': bundle.runtimeMode ?? 'bundled',
      'runtimeContractVersion': bundle.runtimeContractVersion,
      'designSystemVersion': bundle.designSystemVersion,
      'sdkVersion': bundle.sdkVersion,
      'debugToolRuntime': kDebugMode,
    };
    final snapshotJson = jsonEncode(snapshot);
    final hostPayloadJson = jsonEncode(<String, Object?>{
      'mode': 'host',
      'manifest': <String, Object?>{
        'slug': widget.pluginSlug,
        'name': toolDisplayName,
        'version': bundle.version,
        'entry': bundle.entryFilePath,
      },
      'runtime': <String, Object?>{
        'mode': 'host',
        'entry_path': bundle.entryFilePath,
        'runtime_contract_version': bundle.runtimeContractVersion,
        'design_system_version': bundle.designSystemVersion,
        'sdk_version': bundle.sdkVersion,
      },
      'theme': <String, Object?>{'requested': themeMode, 'resolved': themeMode},
      'capabilities': snapshot,
    });

    final themePayloadJson = _encodedWebThemePayload();

    final script =
        '''
(() => {
  const payload = $themePayloadJson;
${_javaScriptApplyWebThemeUsingPayloadConst()}
  const snapshot = $snapshotJson;
  const hostPayload = $hostPayloadJson;
  const bridge = (typeof window.UtilivoHost === 'object' && window.UtilivoHost)
    ? window.UtilivoHost
    : {};
  bridge.mode = hostPayload.mode;
  bridge.manifest = hostPayload.manifest;
  bridge.runtime = hostPayload.runtime;
  bridge.theme = hostPayload.theme;
  bridge.capabilities = hostPayload.capabilities;
  window.UtilivoHost = bridge;
  window.__UTILIVO_HOST__ = hostPayload;
  window.__UTILIVO_INITIAL_STATE__ = null;
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
      },
      reportRestoreAck(restoreId, ok, error) {
        UtilivoHost.postMessage(JSON.stringify({
          type: 'restoreAck',
          id: String(restoreId || ''),
          ok: !!ok,
          error: error != null ? String(error) : ''
        }));
      }
    };
  }
  if (window.utilivo && typeof window.utilivo.reportRestoreAck !== 'function') {
    window.utilivo.reportRestoreAck = function(restoreId, ok, error) {
      UtilivoHost.postMessage(JSON.stringify({
        type: 'restoreAck',
        id: String(restoreId || ''),
        ok: !!ok,
        error: error != null ? String(error) : ''
      }));
    };
  }
})();
''';
    return script;
  }

  void _assertRuntimeContractCompatible(DownloadedToolBundle bundle) {
    final mode = (bundle.runtimeMode ?? 'bundled').trim().toLowerCase();
    if (mode != 'bundled' && mode != 'host') {
      throw const _RuntimeLaunchException(
        'Unsupported tool runtime mode. Please update the app.',
      );
    }
    if (mode == 'host') {
      final runtimeContractVersion = bundle.runtimeContractVersion ?? 0;
      if (runtimeContractVersion != 1) {
        throw const _RuntimeLaunchException(
          'This tool requires a newer host runtime contract. Please update the app.',
        );
      }
      final designSystemVersion = bundle.designSystemVersion ?? 1;
      if (designSystemVersion != 1) {
        throw const _RuntimeLaunchException(
          'This tool requires an unsupported design system version.',
        );
      }
    }
  }

  Future<void> _injectThemeIntoWebView([WebViewController? controller]) async {
    final webViewController = controller ?? _webViewController;
    if (webViewController == null || !mounted) {
      return;
    }

    final encodedPayload = _encodedWebThemePayload();
    final script =
        '''
(() => {
  const payload = $encodedPayload;
${_javaScriptApplyWebThemeUsingPayloadConst()}
})();
''';

    try {
      await webViewController.runJavaScript(script);
    } catch (_) {}
  }

  Future<void> _hydrateCatalogDetail() async {
    try {
      final plugin = await widget.catalogApi.getPluginBySlug(widget.pluginSlug);
      if (!mounted) {
        return;
      }
      setState(() {
        _catalogDetail = plugin;
      });
    } catch (error, stackTrace) {
      developer.log(
        'Catalog detail prefetch failed.',
        name: 'PluginRuntimePage',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> _seedEphemeralFromNamedSession(BuildContext context) async {
    final sid = widget.launchContext.sessionId?.trim();
    if (sid == null || sid.isEmpty) {
      throw const _RuntimeLaunchException('Invalid saved session link.');
    }
    final row = await widget.toolSessionService.getSession(sid);
    if (!context.mounted) {
      throw const _RuntimeLaunchException('Launch interrupted.');
    }
    final l10n =
        AppLocalizations.of(context) ?? lookupAppLocalizations(const Locale('en'));
    if (row == null || row.toolId != widget.launchContext.toolId) {
      throw _RuntimeLaunchException(l10n.runtimeSessionNotFound);
    }
    final String stateJson =
        SessionSnapshotNormalizer.ephemeralStateJsonFromNamedSessionRow(
          row.stateJson,
        );
    _sessionRestoreLog(
      'cold_open_session_seeded',
      'sessionId=$sid bytes=${utf8.encode(stateJson).length}',
    );
    await widget.runtimeStateScopeService.persistEphemeral(
      launchToken: widget.launchContext.launchToken,
      toolId: widget.launchContext.toolId,
      toolSlug: widget.pluginSlug,
      stateJson: stateJson,
    );
    await widget.toolSessionService.markSessionOpened(sid);
  }

  Future<void> _restoreNamedSessionInPlace(
    BuildContext context,
    NamedToolSession chosen,
    AppLocalizations l10n,
  ) async {
    if (_viewState != AppViewState.content || _webViewController == null) {
      _sessionRestoreLog('in_place_restore_skipped_not_ready');
      return;
    }
    _sessionRestoreLog(
      'in_place_load_requested',
      'sessionId=${chosen.id} toolId=${widget.launchContext.toolId}',
    );
    final NamedToolSession? row =
        await widget.toolSessionService.getSession(chosen.id);
    if (!context.mounted) {
      return;
    }
    if (row == null || row.toolId != widget.launchContext.toolId) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.runtimeSessionNotFound)),
      );
      return;
    }
    final String stateJson =
        SessionSnapshotNormalizer.ephemeralStateJsonFromNamedSessionRow(
          row.stateJson,
        );
    if (!widget.launchContext.usesEphemeralPersistence) {
      return;
    }
    await widget.runtimeStateScopeService.persistEphemeral(
      launchToken: widget.launchContext.launchToken,
      toolId: widget.launchContext.toolId,
      toolSlug: widget.pluginSlug,
      stateJson: stateJson,
    );
    await widget.toolSessionService.markSessionOpened(chosen.id);
    if (!mounted) {
      return;
    }
    setState(() {
      _boundNamedSessionId = chosen.id;
      _namedSessionBarTitle = row.name;
      _namedSessionBaselineJson = stateJson;
      _namedSessionDirty = false;
    });
    _sessionRestoreLog(
      'in_place_ephemeral_written',
      'bytes=${utf8.encode(stateJson).length} reusingLaunchToken=${widget.launchContext.launchToken}',
    );
    final bool ok = await _requestToolApplySessionSnapshot(stateJson);
    if (!context.mounted) {
      return;
    }
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.runtimeSessionUpdateFailed)),
      );
    } else {
      _sessionRestoreLog('in_place_restore_complete', 'sessionId=${chosen.id}');
    }
  }

  Future<bool> _ensureProForSessions(
    BuildContext context,
    AppLocalizations l10n,
  ) async {
    if (widget.entitlementController.hasProAccess) {
      return true;
    }
    await widget.paywallCoordinator.show(
      context,
      PaywallRequest(
        trigger: PaywallTrigger.contextualFeature,
        triggerSource: 'tool_sessions_menu',
        blockedFeatureId: 'named_sessions',
        contextMessage: l10n.runtimeSessionProRequired,
      ),
    );
    return widget.entitlementController.hasProAccess;
  }

  Future<void> _onSaveNamedSession(BuildContext context) async {
    final l10n =
        AppLocalizations.of(context) ?? lookupAppLocalizations(const Locale('en'));
    if (!await _ensureProForSessions(context, l10n)) {
      return;
    }
    if (!widget.launchContext.usesEphemeralPersistence) {
      return;
    }
    final ephemeral = await widget.runtimeStateScopeService.loadEphemeral(
      widget.launchContext.launchToken,
    );
    final raw = ephemeral?.stateJson;
    if (raw == null || raw.trim().isEmpty) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.runtimeSessionNothingToSave)),
      );
      return;
    }
    if (!context.mounted) {
      return;
    }
    final name = await showDialog<String>(
      context: context,
      builder: (BuildContext dialogContext) {
        return _SaveSessionNameDialog(l10n: l10n);
      },
    );
    if (name == null || name.trim().isEmpty) {
      return;
    }
    final bundle = _loadedBundle;
    _sessionRestoreLog(
      'save_session_requested',
      'bytes=${utf8.encode(raw).length}',
    );
    try {
      final String sessionId = await widget.toolSessionService.saveNamedSession(
        toolId: widget.launchContext.toolId,
        toolSlug: widget.pluginSlug,
        name: name.trim(),
        payload:
            SessionSnapshotNormalizer.payloadMapFromEphemeralStateJson(raw),
        installId: widget.launchContext.installId,
        toolVersion: bundle?.version,
        toolManifestVersion: bundle?.manifestVersion,
      );
      if (!context.mounted) {
        return;
      }
      setState(() {
        _boundNamedSessionId = sessionId;
        _namedSessionBarTitle = name.trim();
        _namedSessionBaselineJson = raw;
        _namedSessionDirty = false;
      });
      _sessionRestoreLog('save_session_bound_in_place', 'sessionId=$sessionId');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.runtimeSessionSaved)),
      );
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save session: $error')),
      );
    }
  }

  Future<void> _onUpdateNamedSession(BuildContext context) async {
    final l10n =
        AppLocalizations.of(context) ?? lookupAppLocalizations(const Locale('en'));
    if (!widget.entitlementController.hasProAccess) {
      return;
    }
    final String? sid = _activeNamedSessionId();
    if (sid == null || sid.isEmpty) {
      return;
    }
    if (!widget.launchContext.usesEphemeralPersistence) {
      return;
    }
    final ephemeral = await widget.runtimeStateScopeService.loadEphemeral(
      widget.launchContext.launchToken,
    );
    final raw = ephemeral?.stateJson;
    if (raw == null || raw.trim().isEmpty) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.runtimeSessionNothingToSave)),
      );
      return;
    }
    final bundle = _loadedBundle;
    try {
      await widget.toolSessionService.updateNamedSessionState(
        id: sid,
        payload:
            SessionSnapshotNormalizer.payloadMapFromEphemeralStateJson(raw),
        toolVersion: bundle?.version,
        toolManifestVersion: bundle?.manifestVersion,
      );
      if (!context.mounted) {
        return;
      }
      setState(() {
        _namedSessionBaselineJson = raw;
        _namedSessionDirty = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.runtimeSessionUpdated)),
      );
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.runtimeSessionUpdateFailed)),
      );
    }
  }

  Future<void> _onLoadNamedSession(BuildContext context) async {
    final l10n =
        AppLocalizations.of(context) ?? lookupAppLocalizations(const Locale('en'));
    if (!await _ensureProForSessions(context, l10n)) {
      return;
    }
    final sessions = await widget.toolSessionService.listSessions(
      widget.launchContext.toolId,
    );
    if (!context.mounted) {
      return;
    }
    final chosen = await showDialog<NamedToolSession>(
      context: context,
      builder: (BuildContext dialogContext) {
        return _LoadSessionPickerDialog(l10n: l10n, sessions: sessions);
      },
    );
    if (chosen == null) {
      return;
    }
    if (!context.mounted) {
      return;
    }
    await _restoreNamedSessionInPlace(context, chosen, l10n);
  }

  Future<void> _onManageNamedSessions(BuildContext context) async {
    final l10n =
        AppLocalizations.of(context) ?? lookupAppLocalizations(const Locale('en'));
    if (!await _ensureProForSessions(context, l10n)) {
      return;
    }
    if (!context.mounted) {
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return _ManageSessionsDialog(
          l10n: l10n,
          toolSessionService: widget.toolSessionService,
          toolId: widget.launchContext.toolId,
        );
      },
    );
  }

  Future<void> _onRuntimeMenuSelected(
    BuildContext context,
    String action,
  ) async {
    switch (action) {
      case 'updates':
        await _showCheckUpdatesDialog(context);
        break;
      case 'details':
        await _showToolDetailsDialog(context);
        break;
      case 'report':
        await _showReportToolDialog(context);
        break;
      case 'save_session':
        await _onSaveNamedSession(context);
        break;
      case 'load_session':
        await _onLoadNamedSession(context);
        break;
      case 'manage_sessions':
        await _onManageNamedSessions(context);
        break;
      default:
        break;
    }
  }

  Future<void> _showCheckUpdatesDialog(BuildContext context) async {
    final l10n =
        AppLocalizations.of(context) ??
        lookupAppLocalizations(const Locale('en'));
    final navigator = Navigator.of(context);
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return PopScope(
          canPop: false,
          child: AlertDialog(
            content: Row(
              children: <Widget>[
                const SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                ),
                const SizedBox(width: 16),
                Expanded(child: Text(l10n.checkingUpdates)),
              ],
            ),
          ),
        );
      },
    );
    try {
      final versions = await widget.catalogApi.listPluginVersions(
        widget.pluginSlug,
        forceRefresh: true,
      );
      if (!context.mounted) {
        return;
      }
      navigator.pop();
      final installed = _loadedBundle?.version;
      final latest = versions.isEmpty ? null : versions.first.version;
      final update = isPluginUpdateAvailable(
        installedVersion: installed,
        latestVersion: latest,
      );
      await showDialog<void>(
        context: context,
        builder: (BuildContext dialogContext) {
          return AlertDialog(
            title: Text(
              update
                  ? l10n.runtimeUpdateAvailableTitle
                  : l10n.runtimeUpToDateTitle,
            ),
            content: Text(
              update &&
                      latest != null &&
                      latest.trim().isNotEmpty &&
                      installed != null &&
                      installed.trim().isNotEmpty
                  ? l10n.runtimeUpdateAvailableBody(
                      latest.trim(),
                      installed.trim(),
                    )
                  : l10n.runtimeUpToDateMessage,
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: Text(l10n.cancel),
              ),
            ],
          );
        },
      );
    } on NetworkException catch (error) {
      if (context.mounted) {
        navigator.pop();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } catch (_) {
      if (context.mounted) {
        navigator.pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not check for updates.')),
        );
      }
    }
  }

  Future<void> _showToolDetailsDialog(BuildContext context) async {
    final l10n =
        AppLocalizations.of(context) ??
        lookupAppLocalizations(const Locale('en'));
    final detail = _catalogDetail;
    final bundle = _loadedBundle;
    final tierLabel =
        detail != null && CatalogPlugin.tierIsPro(detail.pricingType)
        ? 'Pro'
        : 'Free';
    final body = StringBuffer()
      ..writeln('${l10n.category}: ${detail?.categoryName ?? '—'}')
      ..writeln('Slug: ${widget.pluginSlug}')
      ..writeln('Tier: $tierLabel')
      ..writeln('${l10n.installedVersion}: ${bundle?.version ?? '—'}');
    if (detail?.shortDescription != null &&
        detail!.shortDescription!.trim().isNotEmpty) {
      body.writeln();
      body.writeln(detail.shortDescription!.trim());
    }
    if (detail?.longDescription != null &&
        detail!.longDescription!.trim().isNotEmpty &&
        detail.longDescription!.trim() != detail.shortDescription?.trim()) {
      body.writeln();
      body.writeln(detail.longDescription!.trim());
    }
    await showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(l10n.runtimeToolDetailsTitle),
          content: SingleChildScrollView(child: Text(body.toString())),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(l10n.cancel),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showReportToolDialog(BuildContext context) async {
    await showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return _ReportToolDialog(
          config: widget.config,
          pluginSlug: widget.pluginSlug,
          scaffoldMessenger: ScaffoldMessenger.of(context),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n =
        AppLocalizations.of(context) ??
        lookupAppLocalizations(const Locale('en'));
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
                  backgroundColor: Theme.of(
                    context,
                  ).colorScheme.secondaryContainer,
                ),
              ),
            ),
          if (_viewState == AppViewState.content && _loadedBundle != null)
            PopupMenuButton<String>(
              tooltip: 'More',
              onSelected: (String value) {
                unawaited(_onRuntimeMenuSelected(context, value));
              },
              itemBuilder: (BuildContext menuContext) {
                return <PopupMenuEntry<String>>[
                  PopupMenuItem<String>(
                    value: 'updates',
                    child: Text(l10n.runtimeMenuCheckUpdates),
                  ),
                  PopupMenuItem<String>(
                    value: 'details',
                    child: Text(l10n.runtimeMenuDetails),
                  ),
                  PopupMenuItem<String>(
                    value: 'report',
                    child: Text(l10n.runtimeMenuReport),
                  ),
                  if (!_previewMode) ...<PopupMenuEntry<String>>[
                    const PopupMenuDivider(),
                    PopupMenuItem<String>(
                      value: 'save_session',
                      child: Text(l10n.runtimeMenuSaveSession),
                    ),
                    PopupMenuItem<String>(
                      value: 'load_session',
                      child: Text(l10n.runtimeMenuLoadSession),
                    ),
                    PopupMenuItem<String>(
                      value: 'manage_sessions',
                      child: Text(l10n.runtimeMenuManageSessions),
                    ),
                  ],
                ];
              },
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            if (_viewState == AppViewState.content &&
                _shouldShowNamedSessionSubBar)
              _buildNamedSessionSubBar(context, l10n),
            Expanded(
              child: _hostAppUpdateBlocked
                  ? _buildHostAppUpdateGate(context, l10n)
                  : _permissionLaunchBlocked
                  ? _buildPermissionLaunchGate(context, l10n)
                  : _mandatoryUpdateBlocked
                  ? _buildMandatoryUpdateGate(context)
                  : AppStateBody(
                      state: _viewState,
                      loadingBuilder: _buildLoading,
                      loadingMessage: _statusMessage,
                      errorTitle: 'Could not launch tool',
                      errorMessage:
                          _errorMessage ??
                          'Unexpected runtime startup failure.',
                      onRetry: _prepareAndLoad,
                      content: _buildContent(),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMandatoryUpdateGate(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.system_update_rounded,
              size: 48,
              color: colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              'Update required',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'This version of the tool must be updated before you can open it. '
              'Update from your home screen or the Tool Library.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () {
                context.go(AppRoutes.discover);
              },
              icon: const Icon(Icons.apps_outlined),
              label: const Text('Open Tool Library'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => context.pop(),
              child: const Text('Back'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHostAppUpdateGate(BuildContext context, AppLocalizations l10n) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.system_update_rounded,
              size: 48,
              color: colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              l10n.runtimeHostAppUpdateTitle,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              l10n.runtimeHostAppUpdateBody,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => unawaited(_openAppStoreListing(context, l10n)),
              icon: const Icon(Icons.download_outlined),
              label: Text(l10n.runtimeHostAppUpdateCta),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => context.pop(),
              child: Text(l10n.cancel),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openAppStoreListing(
    BuildContext context,
    AppLocalizations l10n,
  ) async {
    final Uri? target = Platform.isIOS
        ? widget.config.iosAppStoreListingUri
        : widget.config.androidPlayStoreListingUri;
    if (target == null) {
      if (context.mounted) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(content: Text(l10n.runtimeHostAppUpdateNoStoreUrl)),
        );
      }
      return;
    }
    try {
      if (await canLaunchUrl(target)) {
        await launchUrl(target, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}
  }

  Widget _buildPermissionLaunchGate(
    BuildContext context,
    AppLocalizations l10n,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.privacy_tip_outlined,
              size: 48,
              color: colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              l10n.runtimePermissionRequiredTitle,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              l10n.runtimePermissionDeniedBody,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            if (_permissionLaunchPermanent) ...<Widget>[
              FilledButton.icon(
                onPressed: () async {
                  await openAppSettings();
                },
                icon: const Icon(Icons.settings_outlined),
                label: Text(l10n.runtimePermissionOpenSettingsCta),
              ),
              const SizedBox(height: 8),
            ],
            FilledButton(
              onPressed: () {
                setState(() {
                  _permissionLaunchBlocked = false;
                  _permissionLaunchPermanent = false;
                });
                unawaited(_prepareAndLoad());
              },
              child: Text(l10n.runtimePermissionRetryCta),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => context.pop(),
              child: Text(l10n.cancel),
            ),
          ],
        ),
      ),
    );
  }

  static const double _namedSessionSubBarHeight = 48;

  Widget _buildNamedSessionSubBar(
    BuildContext context,
    AppLocalizations l10n,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final title =
        _namedSessionBarTitle?.trim().isNotEmpty == true
            ? _namedSessionBarTitle!
            : l10n.runtimeSessionBarFallback;
    return Material(
      color: scheme.surfaceContainerHighest.withValues(alpha: 0.55),
      child: SizedBox(
        height: _namedSessionSubBarHeight,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Row(
            children: <Widget>[
              Icon(Icons.bookmark_outline, size: 20, color: scheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              SizedBox(
                width: 132,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: _namedSessionDirty
                      ? TextButton(
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          onPressed: () =>
                              unawaited(_onUpdateNamedSession(context)),
                          child: Text(l10n.runtimeSessionUpdateButton),
                        )
                      : const SizedBox.shrink(),
                ),
              ),
            ],
          ),
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
        message: 'The tool viewer is not initialized.',
      );
    }

    return ColoredBox(
      color: Theme.of(context).colorScheme.surface,
      child: WebViewWidget(controller: webViewController),
    );
  }
}

class _SaveSessionNameDialog extends StatefulWidget {
  const _SaveSessionNameDialog({required this.l10n});

  final AppLocalizations l10n;

  @override
  State<_SaveSessionNameDialog> createState() =>
      _SaveSessionNameDialogState();
}

class _SaveSessionNameDialogState extends State<_SaveSessionNameDialog> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = widget.l10n;
    return AlertDialog(
      title: Text(l10n.runtimeSessionSaveTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            l10n.runtimeSessionSaveHint,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            decoration: InputDecoration(
              labelText: l10n.runtimeSessionNameLabel,
            ),
            autofocus: true,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submit(),
          ),
        ],
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(l10n.runtimeSessionSaveConfirm),
        ),
      ],
    );
  }

  void _submit() {
    final v = _controller.text.trim();
    Navigator.of(context).pop<String>(v.isEmpty ? null : v);
  }
}

class _LoadSessionPickerDialog extends StatelessWidget {
  const _LoadSessionPickerDialog({
    required this.l10n,
    required this.sessions,
  });

  final AppLocalizations l10n;
  final List<NamedToolSession> sessions;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(l10n.runtimeSessionLoadTitle),
      content: SizedBox(
        width: double.maxFinite,
        child: sessions.isEmpty
            ? Text(l10n.runtimeSessionNoSaved)
            : ListView.builder(
                shrinkWrap: true,
                itemCount: sessions.length,
                itemBuilder: (BuildContext context, int i) {
                  final s = sessions[i];
                  return ListTile(
                    title: Text(s.name),
                    subtitle: Text(
                      MaterialLocalizations.of(context).formatShortDate(
                        s.updatedAt.toLocal(),
                      ),
                    ),
                    onTap: () =>
                        Navigator.of(context).pop<NamedToolSession>(s),
                  );
                },
              ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
      ],
    );
  }
}

class _ManageSessionsDialog extends StatefulWidget {
  const _ManageSessionsDialog({
    required this.l10n,
    required this.toolSessionService,
    required this.toolId,
  });

  final AppLocalizations l10n;
  final ToolSessionService toolSessionService;
  final String toolId;

  @override
  State<_ManageSessionsDialog> createState() => _ManageSessionsDialogState();
}

class _ManageSessionsDialogState extends State<_ManageSessionsDialog> {
  late Future<List<NamedToolSession>> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.toolSessionService.listSessions(widget.toolId);
  }

  void _reload() {
    setState(() {
      _future = widget.toolSessionService.listSessions(widget.toolId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = widget.l10n;
    return AlertDialog(
      title: Text(l10n.runtimeSessionManageTitle),
      content: SizedBox(
        width: double.maxFinite,
        child: FutureBuilder<List<NamedToolSession>>(
          future: _future,
          builder:
              (BuildContext context, AsyncSnapshot<List<NamedToolSession>> snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(),
                ),
              );
            }
            final list = snap.data ?? <NamedToolSession>[];
            if (list.isEmpty) {
              return Text(l10n.runtimeSessionNoSaved);
            }
            return SizedBox(
              height: 320,
              child: ListView.builder(
                itemCount: list.length,
                itemBuilder: (BuildContext context, int i) {
                  final s = list[i];
                  return ListTile(
                    title: Text(s.name),
                    trailing: PopupMenuButton<String>(
                      onSelected: (String action) async {
                        if (action == 'delete') {
                          final ok = await showDialog<bool>(
                            context: context,
                            builder: (BuildContext ctx) {
                              return AlertDialog(
                                title: Text(
                                  l10n.runtimeSessionDeleteConfirmTitle,
                                ),
                                content: Text(
                                  l10n.runtimeSessionDeleteConfirmMessage(
                                    s.name,
                                  ),
                                ),
                                actions: <Widget>[
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.of(ctx).pop(false),
                                    child: Text(l10n.cancel),
                                  ),
                                  FilledButton(
                                    onPressed: () =>
                                        Navigator.of(ctx).pop(true),
                                    child: Text(l10n.delete),
                                  ),
                                ],
                              );
                            },
                          );
                          if (ok == true && context.mounted) {
                            await widget.toolSessionService.deleteSession(s.id);
                            _reload();
                          }
                        } else if (action == 'rename') {
                          final controller =
                              TextEditingController(text: s.name);
                          final newName = await showDialog<String>(
                            context: context,
                            builder: (BuildContext ctx) {
                              return AlertDialog(
                                title: Text(l10n.runtimeSessionRenameTitle),
                                content: TextField(
                                  controller: controller,
                                  decoration: InputDecoration(
                                    labelText: l10n.runtimeSessionNameLabel,
                                  ),
                                  autofocus: true,
                                ),
                                actions: <Widget>[
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.of(ctx).pop(),
                                    child: Text(l10n.cancel),
                                  ),
                                  FilledButton(
                                    onPressed: () {
                                      Navigator.of(ctx).pop(
                                        controller.text.trim(),
                                      );
                                    },
                                    child: Text(l10n.runtimeSessionSaveConfirm),
                                  ),
                                ],
                              );
                            },
                          );
                          if (newName != null &&
                              newName.isNotEmpty &&
                              newName != s.name &&
                              context.mounted) {
                            await widget.toolSessionService.renameSession(
                              id: s.id,
                              newName: newName,
                            );
                            _reload();
                          }
                        }
                      },
                      itemBuilder: (BuildContext ctx) {
                        return <PopupMenuEntry<String>>[
                          PopupMenuItem<String>(
                            value: 'rename',
                            child: Text(l10n.runtimeSessionRename),
                          ),
                          PopupMenuItem<String>(
                            value: 'delete',
                            child: Text(l10n.runtimeSessionDelete),
                          ),
                        ];
                      },
                    ),
                  );
                },
              ),
            );
          },
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
      ],
    );
  }
}

class _ReportToolDialog extends StatefulWidget {
  const _ReportToolDialog({
    required this.config,
    required this.pluginSlug,
    required this.scaffoldMessenger,
  });

  final AppConfig config;
  final String pluginSlug;
  final ScaffoldMessengerState scaffoldMessenger;

  @override
  State<_ReportToolDialog> createState() => _ReportToolDialogState();
}

class _ReportToolDialogState extends State<_ReportToolDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  String? _reasonKey;
  final TextEditingController _detailsController = TextEditingController();

  @override
  void dispose() {
    _detailsController.dispose();
    super.dispose();
  }

  void _submit(BuildContext outerContext) {
    final l10n =
        AppLocalizations.of(outerContext) ??
        lookupAppLocalizations(const Locale('en'));
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    final endpoint = widget.config.toolReportSubmitUrl?.trim() ?? '';
    developer.log(
      'Tool report (stub): slug=${widget.pluginSlug} reason=$_reasonKey '
      'details=${_detailsController.text.trim()} endpoint=${endpoint.isEmpty ? '(none)' : endpoint}',
      name: 'PluginRuntimePage',
    );
    Navigator.of(context).pop();
    widget.scaffoldMessenger.showSnackBar(
      SnackBar(content: Text(l10n.runtimeReportQueued)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n =
        AppLocalizations.of(context) ??
        lookupAppLocalizations(const Locale('en'));
    final theme = Theme.of(context);
    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      titlePadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      title: Text(l10n.runtimeReportTitle, style: theme.textTheme.titleMedium),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              DropdownButtonFormField<String>(
                // ignore: deprecated_member_use
                value: _reasonKey,
                decoration: InputDecoration(
                  labelText: l10n.runtimeReportReasonLabel,
                ),
                items: <DropdownMenuItem<String>>[
                  DropdownMenuItem<String>(
                    value: 'not_working',
                    child: Text(l10n.reportReasonNotWorking),
                  ),
                  DropdownMenuItem<String>(
                    value: 'incorrect',
                    child: Text(l10n.reportReasonIncorrect),
                  ),
                  DropdownMenuItem<String>(
                    value: 'other',
                    child: Text(l10n.reportReasonOther),
                  ),
                ],
                onChanged: (String? v) => setState(() => _reasonKey = v),
                validator: (String? v) {
                  if (v == null || v.isEmpty) {
                    return l10n.runtimeReportSelectReason;
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _detailsController,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: l10n.runtimeReportDetailsLabel,
                  alignLabelWithHint: true,
                ),
                maxLines: 4,
                minLines: 4,
                validator: (String? v) {
                  if (v == null || v.trim().length < 4) {
                    return l10n.reportDetailsTooShort;
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: () => _submit(context),
          child: Text(l10n.runtimeReportSubmit),
        ),
      ],
    );
  }
}

class _RuntimeLaunchException implements Exception {
  const _RuntimeLaunchException(this.message);

  final String message;
}
