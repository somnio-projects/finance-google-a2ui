// Copyright 2024 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      https://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

// ignore_for_file: avoid_print

import 'package:finance_a2ui_client/src/features/landing/bloc/landing_bloc.dart';
import 'package:finance_a2ui_client/src/features/landing/bloc/landing_event.dart';
import 'package:finance_a2ui_client/src/features/landing/bloc/landing_state.dart';
import 'package:finance_a2ui_client/src/features/landing/repository/landing_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_infra/crypto_agent.dart';

void main() {
  setUp(() async {
    final cryptoAgentClient = TestCryptoAgentClient();
    addTearDown(cryptoAgentClient.dispose);
    await cryptoAgentClient.startAndVerify();
  });

  test(
    'LandingBloc can list crypto markets and place an order.',
    () async {
      final repository = LandingRepository(
        serverUrl: Uri.parse(TestCryptoAgentClient().baseUrl),
      );
      addTearDown(repository.dispose);
      final bloc = LandingBloc(landingRepository: repository);
      addTearDown(bloc.close);

      expect(bloc.state.status, LandingStatus.initial);
      expect(bloc.state.surfaceIds, isEmpty);

      // Sends a message and waits until the request finishes.
      Future<LandingState> send(String text) {
        final Future<LandingState> done = bloc.stream.firstWhere(
          (state) => state.status == .success || state.status == .failure,
        );
        bloc.add(LandingMessageSent(text));
        return done;
      }

      // 1. Ask the agent for market data.
      LandingState state = await send(
        'Show me the top 3 cryptocurrencies by market cap.',
      );

      expect(state.status, LandingStatus.success);
      expect(state.error, isNull);
      expect(
        state.surfaceIds,
        isNotEmpty,
        reason:
            'Agent should respond with at least one surface listing the '
            'coins.',
      );

      // 2. Ask the agent to place an order for one of them. This simulates
      // the user tapping "Place Order" — both paths funnel into the same send.
      state = await send(
        'Buy 0.5 of the first coin on the list at the current market '
        'price.',
      );

      expect(state.status, LandingStatus.success);
      expect(state.error, isNull);
      expect(
        state.surfaceIds,
        isNotEmpty,
        reason: 'Agent should respond with an order confirmation surface.',
      );
    },
    timeout: const Timeout(Duration(minutes: 10)),
  );
}
