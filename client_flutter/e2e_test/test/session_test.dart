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

import 'package:flutter_test/flutter_test.dart';
import 'package:restaurant_finder_client/src/features/landing/bloc/landing_bloc.dart';
import 'package:restaurant_finder_client/src/features/landing/bloc/landing_event.dart';
import 'package:restaurant_finder_client/src/features/landing/bloc/landing_state.dart';
import 'package:restaurant_finder_client/src/features/landing/repository/landing_repository.dart';

import 'test_infra/restaurant_finder.dart';

void main() {
  setUp(() async {
    final restaurantFinderClient = TestRestaurantFinderClient();
    addTearDown(restaurantFinderClient.dispose);
    await restaurantFinderClient.startAndVerify();
  });

  test(
    'LandingBloc can find restaurants and book a reservation.',
    () async {
      final repository = LandingRepository(
        serverUrl: TestRestaurantFinderClient().baseUrl,
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

      // 1. Ask the agent to find restaurants.
      LandingState state = await send(
        'Find me 3 italian restaurants in New York.',
      );

      expect(state.status, LandingStatus.success);
      expect(state.error, isNull);
      expect(
        state.surfaceIds,
        isNotEmpty,
        reason:
            'Agent should respond with at least one surface listing the '
            'restaurants.',
      );

      // 2. Ask the agent to book a table at one of them. This simulates the
      // user tapping "Book Now" — both paths funnel into the same send.
      state = await send(
        'Book a table at the first restaurant on Wednesday, April 29 2026 '
        'at 7:47 PM, for 2 people, dietary requirement: vegan.',
      );

      expect(state.status, LandingStatus.success);
      expect(state.error, isNull);
      expect(
        state.surfaceIds,
        isNotEmpty,
        reason: 'Agent should respond with a booking confirmation surface.',
      );
    },
    timeout: const Timeout(Duration(minutes: 10)),
  );
}
