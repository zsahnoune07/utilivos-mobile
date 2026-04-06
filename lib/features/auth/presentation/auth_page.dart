import 'package:flutter/material.dart';

import '../../../core/auth/session_controller.dart';
import '../../../core/networking/network_exception.dart';
import '../../../shared/widgets/app_buttons.dart';
import '../../../shared/widgets/app_input.dart';
import '../../../shared/widgets/app_surface_card.dart';

enum _AuthMode { login, register }

class AuthPage extends StatefulWidget {
  const AuthPage({required this.sessionController, super.key});

  final SessionController sessionController;

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final GlobalKey<FormState> _loginFormKey = GlobalKey<FormState>();
  final GlobalKey<FormState> _registerFormKey = GlobalKey<FormState>();

  final TextEditingController _loginEmailController = TextEditingController();
  final TextEditingController _loginPasswordController =
      TextEditingController();

  final TextEditingController _registerNameController = TextEditingController();
  final TextEditingController _registerEmailController =
      TextEditingController();
  final TextEditingController _registerPasswordController =
      TextEditingController();

  _AuthMode _mode = _AuthMode.login;
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _loginEmailController.dispose();
    _loginPasswordController.dispose();
    _registerNameController.dispose();
    _registerEmailController.dispose();
    _registerPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submitLogin() async {
    final form = _loginFormKey.currentState;
    if (form == null || !form.validate()) {
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      await widget.sessionController.login(
        email: _loginEmailController.text.trim(),
        password: _loginPasswordController.text,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = _formatAuthError(error);
        _isSubmitting = false;
      });
      return;
    }

    if (!mounted) {
      return;
    }
    setState(() {
      _isSubmitting = false;
    });
  }

  Future<void> _submitRegister() async {
    final form = _registerFormKey.currentState;
    if (form == null || !form.validate()) {
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      await widget.sessionController.register(
        email: _registerEmailController.text.trim(),
        password: _registerPasswordController.text,
        displayName: _registerNameController.text.trim(),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = _formatAuthError(error);
        _isSubmitting = false;
      });
      return;
    }

    if (!mounted) {
      return;
    }
    setState(() {
      _isSubmitting = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          'Utilivos Auth',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                fontSize: 22,
              ),
        ),
        backgroundColor: Theme.of(context).colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, kToolbarHeight + 16, 16, 16),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: AppSurfaceCard(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      _mode == _AuthMode.login
                          ? 'Login to Utilivos'
                          : 'Create your account',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Phase 3.1 auth flow is live. '
                      'Use your API credentials to continue.',
                    ),
                    const SizedBox(height: 12),
                    SegmentedButton<_AuthMode>(
                      segments: const <ButtonSegment<_AuthMode>>[
                        ButtonSegment<_AuthMode>(
                          value: _AuthMode.login,
                          label: Text('Login'),
                        ),
                        ButtonSegment<_AuthMode>(
                          value: _AuthMode.register,
                          label: Text('Register'),
                        ),
                      ],
                      selected: <_AuthMode>{_mode},
                      onSelectionChanged: (Set<_AuthMode> selection) {
                        setState(() {
                          _mode = selection.first;
                          _errorMessage = null;
                        });
                      },
                    ),
                    if (_errorMessage != null) ...<Widget>[
                      const SizedBox(height: 12),
                      Text(
                        _errorMessage!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    if (_mode == _AuthMode.login)
                      _buildLoginForm()
                    else
                      _buildRegisterForm(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoginForm() {
    return Form(
      key: _loginFormKey,
      child: Column(
        children: <Widget>[
          AppInput(
            fieldKey: const ValueKey<String>('login-email'),
            labelText: 'Email',
            hintText: 'you@example.com',
            controller: _loginEmailController,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            validator: _validateEmail,
          ),
          const SizedBox(height: 12),
          AppInput(
            fieldKey: const ValueKey<String>('login-password'),
            labelText: 'Password',
            hintText: 'Enter your password',
            controller: _loginPasswordController,
            obscureText: true,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _submitLogin(),
            validator: _validateLoginPassword,
          ),
          const SizedBox(height: 16),
          AppPrimaryButton(
            label: 'Login',
            onPressed: _submitLogin,
            isLoading: _isSubmitting,
          ),
        ],
      ),
    );
  }

  Widget _buildRegisterForm() {
    return Form(
      key: _registerFormKey,
      child: Column(
        children: <Widget>[
          AppInput(
            fieldKey: const ValueKey<String>('register-name'),
            labelText: 'Display Name',
            hintText: 'Jane Doe',
            controller: _registerNameController,
            textInputAction: TextInputAction.next,
            validator: _validateDisplayName,
          ),
          const SizedBox(height: 12),
          AppInput(
            fieldKey: const ValueKey<String>('register-email'),
            labelText: 'Email',
            hintText: 'you@example.com',
            controller: _registerEmailController,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            validator: _validateEmail,
          ),
          const SizedBox(height: 12),
          AppInput(
            fieldKey: const ValueKey<String>('register-password'),
            labelText: 'Password',
            hintText: 'At least 8 characters',
            controller: _registerPasswordController,
            obscureText: true,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _submitRegister(),
            validator: _validateRegisterPassword,
          ),
          const SizedBox(height: 16),
          AppPrimaryButton(
            label: 'Register',
            onPressed: _submitRegister,
            isLoading: _isSubmitting,
          ),
        ],
      ),
    );
  }

  String? _validateEmail(String? value) {
    final input = value?.trim() ?? '';
    if (input.isEmpty) {
      return 'Email is required.';
    }

    final emailPattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
    if (!emailPattern.hasMatch(input)) {
      return 'Enter a valid email address.';
    }
    return null;
  }

  String? _validateLoginPassword(String? value) {
    final input = value ?? '';
    if (input.isEmpty) {
      return 'Password is required.';
    }
    return null;
  }

  String? _validateRegisterPassword(String? value) {
    final input = value ?? '';
    if (input.isEmpty) {
      return 'Password is required.';
    }
    if (input.length < 8) {
      return 'Password must be at least 8 characters.';
    }
    return null;
  }

  String? _validateDisplayName(String? value) {
    final input = value?.trim() ?? '';
    if (input.isEmpty) {
      return 'Display name is required.';
    }
    return null;
  }

  String _formatAuthError(Object error) {
    if (error is NetworkException) {
      if (error.details is List) {
        final details = error.details as List<dynamic>;
        if (details.isNotEmpty && details.first is Map<String, dynamic>) {
          final first = details.first as Map<String, dynamic>;
          final fieldMessage = first['message'] as String?;
          if (fieldMessage != null && fieldMessage.trim().isNotEmpty) {
            return fieldMessage;
          }
        }
      }
      return error.message;
    }
    return 'Authentication request failed. Please try again.';
  }
}
