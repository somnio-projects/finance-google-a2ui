import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:genui/genui.dart';

import '../../../config/app_config.dart';
import '../../../primitives.dart';
import '../../../theme/finance_tokens.dart';
import '../bloc/landing_bloc.dart';
import '../bloc/landing_event.dart';
import '../bloc/landing_state.dart';
import '../repository/landing_repository.dart';

/// Placeholder messages shown next to the loading spinner while the agent
/// is busy.
///
/// The same loading screen appears during both the market data phase
/// (after the user submits a query) and the order phase (after the user
/// taps "Place Order"), so messages are kept neutral enough to fit either
/// context — no "loading prices" copy that would look wrong while an order
/// is being confirmed.
const List<String> _loadingTexts = [
  'Checking the market...',
  'Crunching the numbers...',
  'Looking up details...',
  'Working on your request...',
  'Almost there...',
  'Just a moment...',
];

class LandingPage extends StatefulWidget {
  const LandingPage({
    required this.config,
    required this.onToggleTheme,
    this.landingRepository,
    super.key,
  });

  final AppConfig config;
  final VoidCallback onToggleTheme;

  /// Optional [LandingRepository] for testing. When provided, the caller
  /// owns it and is responsible for disposing it.
  final LandingRepository? landingRepository;

  @override
  State<LandingPage> createState() => _LandingPageState();
}

class _LandingPageState extends State<LandingPage> {
  late final LandingRepository _repository;

  @override
  void initState() {
    super.initState();
    _repository =
        widget.landingRepository ??
        LandingRepository(serverUrl: widget.config.backendBaseUrl);
  }

  @override
  void dispose() {
    if (widget.landingRepository == null) _repository.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => LandingBloc(landingRepository: _repository),
      child: LandingView(
        onToggleTheme: widget.onToggleTheme,
        surfaceHost: _repository.surfaceHost,
      ),
    );
  }
}

class LandingView extends StatelessWidget {
  const LandingView({
    required this.onToggleTheme,
    required this.surfaceHost,
    super.key,
  });

  final VoidCallback onToggleTheme;
  final SurfaceHost surfaceHost;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: BlocBuilder<LandingBloc, LandingState>(
                  builder: (context, state) => switch (state.status) {
                    .initial => _LandingForm(error: state.error),
                    .loading => _LandingLoading(
                      textIndex: state.loadingTextIndex,
                    ),
                    .success || .failure => _LandingSurfaces(
                      surfaceHost: surfaceHost,
                      surfaceIds: state.surfaceIds,
                      error: state.error,
                    ),
                  },
                ),
              ),
            ),
            Positioned(
              top: 8,
              right: 16,
              child: ThemeToggleButton(onToggle: onToggleTheme),
            ),
          ],
        ),
      ),
    );
  }
}

class _LandingForm extends StatefulWidget {
  const _LandingForm({required this.error});

  final String? error;

  @override
  State<_LandingForm> createState() => _LandingFormState();
}

class _LandingFormState extends State<_LandingForm> {
  final _textController = TextEditingController(
    text: 'Show me the top 3 cryptocurrencies by market cap.',
  );

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 48, 16, 16),
      child: Column(
        children: [
          Icon(
            Icons.currency_bitcoin,
            size: 80,
            color: FinanceTokens.of(context).brandAccent,
          ),
          const SizedBox(height: 16),
          Text(
            'Crypto Market',
            style: Theme.of(
              context,
            ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 32),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _textController,
                  decoration: InputDecoration(
                    hintText: 'Show me the top 5 gainers in the last 24 hours.',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(32),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 16,
                    ),
                  ),
                  onSubmitted: (_) => _submit(),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _submit,
                style: FilledButton.styleFrom(
                  shape: const CircleBorder(),
                  padding: const EdgeInsets.all(16),
                ),
                child: const Icon(Icons.send),
              ),
            ],
          ),
          if (widget.error case final error?) ...[
            const SizedBox(height: 16),
            ErrorBanner(message: error),
          ],
        ],
      ),
    );
  }

  void _submit() {
    context.read<LandingBloc>().add(LandingMessageSent(_textController.text));
  }
}

class _LandingLoading extends StatelessWidget {
  const _LandingLoading({required this.textIndex});

  final int textIndex;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const CircularProgressIndicator(),
        const SizedBox(height: 16),
        Text(
          _loadingTexts[textIndex % _loadingTexts.length],
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      ],
    );
  }
}

class _LandingSurfaces extends StatelessWidget {
  const _LandingSurfaces({
    required this.surfaceHost,
    required this.surfaceIds,
    required this.error,
  });

  final SurfaceHost surfaceHost;
  final List<String> surfaceIds;
  final String? error;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (error case final error?) ErrorBanner(message: error),
        Expanded(
          child: surfaceIds.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: surfaceIds.length,
                  itemBuilder: (context, i) => Surface(
                    surfaceContext: surfaceHost.contextFor(surfaceIds[i]),
                  ),
                ),
        ),
      ],
    );
  }
}
