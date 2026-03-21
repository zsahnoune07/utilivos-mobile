import 'package:flutter/material.dart';

import '../../../core/auth/models/auth_user.dart';
import '../../../core/auth/session_controller.dart';
import '../../../core/networking/network_exception.dart';
import '../../../shared/widgets/app_buttons.dart';
import '../../../shared/widgets/app_info_tile.dart';
import '../../../shared/widgets/app_state_views.dart';
import '../../../shared/widgets/app_surface_card.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({required this.sessionController, super.key});

  final SessionController sessionController;

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  bool _isSigningOut = false;
  AppViewState _profileState = AppViewState.loading;
  AuthUser? _user;
  String _errorMessage = 'Unable to load profile.';

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() {
      _profileState = AppViewState.loading;
      _errorMessage = 'Loading profile...';
    });

    try {
      final user = await widget.sessionController.fetchCurrentUser();
      if (!mounted) {
        return;
      }
      setState(() {
        _user = user;
        _profileState = AppViewState.content;
      });
    } on NetworkException catch (error) {
      if (!mounted) {
        return;
      }

      if (error.kind == NetworkExceptionKind.unauthorized) {
        await widget.sessionController.signOut();
        return;
      }

      setState(() {
        _profileState = AppViewState.error;
        _errorMessage = error.message;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _profileState = AppViewState.error;
        _errorMessage = 'Unexpected profile loading error.';
      });
    }
  }

  Future<void> _signOut() async {
    setState(() {
      _isSigningOut = true;
    });

    await widget.sessionController.signOut();
    if (!mounted) {
      return;
    }

    setState(() {
      _isSigningOut = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        Text('Profile', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 8),
        const Text('Basic user data is loaded from `GET /v1/me`.'),
        const SizedBox(height: 12),
        ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 320),
          child: AppStateBody(
            state: _profileState,
            loadingMessage: 'Loading profile...',
            emptyTitle: 'No user profile data',
            emptyMessage: 'Sign in again to fetch your account profile.',
            errorTitle: 'Failed to load profile',
            errorMessage: _errorMessage,
            onRetry: _loadProfile,
            content: _buildProfileContent(),
          ),
        ),
      ],
    );
  }

  Widget _buildProfileContent() {
    final user = _user;
    if (user == null) {
      return const AppEmptyView(
        title: 'No profile loaded',
        message: 'Use retry to fetch profile details.',
      );
    }

    return AppSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const AppInfoTile(
            leading: Icons.account_circle_outlined,
            title: 'Account',
            subtitle: 'Profile data from utilivo-api',
          ),
          const Divider(),
          AppInfoTile(
            leading: Icons.badge_outlined,
            title: 'Display Name',
            subtitle: user.displayName,
          ),
          AppInfoTile(
            leading: Icons.email_outlined,
            title: 'Email',
            subtitle: user.email,
          ),
          AppInfoTile(
            leading: Icons.fingerprint,
            title: 'User ID',
            subtitle: user.id,
          ),
          AppInfoTile(
            leading: Icons.verified_user_outlined,
            title: 'Status',
            subtitle: user.status,
          ),
          AppInfoTile(
            leading: Icons.shield_outlined,
            title: 'Auth Provider',
            subtitle: user.authProvider,
          ),
          const SizedBox(height: 12),
          AppSecondaryButton(
            label: 'Sign Out',
            onPressed: _isSigningOut ? null : _signOut,
            expand: true,
          ),
        ],
      ),
    );
  }
}
