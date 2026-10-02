import 'package:finance_app/components/attribution_driver/attribution_driver_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const tile = DriverTile(
    label: 'Price move',
    figure: '+4.20%',
    caption: r'+$48.56',
    trend: DriverTrend.up,
  );

  AttributionDriverData data(String contribution) => AttributionDriverData(
    symbol: 'BTC',
    name: 'NVIDIA Corp',
    caption: 'Top contributor today',
    contributionDisplay: contribution,
    trend: DriverTrend.up,
    tiles: const <DriverTile>[tile],
  );

  group(DriverTile, () {
    test('is equal to a tile carrying the same strings and trend', () {
      expect(
        tile,
        equals(
          const DriverTile(
            label: 'Price move',
            figure: '+4.20%',
            caption: r'+$48.56',
            trend: DriverTrend.up,
          ),
        ),
      );
    });

    test('differs when the trend differs, because the trend is the colour', () {
      expect(
        tile,
        isNot(
          equals(
            const DriverTile(
              label: 'Price move',
              figure: '+4.20%',
              caption: r'+$48.56',
              trend: DriverTrend.down,
            ),
          ),
        ),
      );
    });
  });

  group(AttributionDriverData, () {
    test('is equal to a model over the same strings and tiles', () {
      expect(data(r'+$4,370.40'), equals(data(r'+$4,370.40')));
    });

    test('differs when a display string differs', () {
      // The figures are part of what the card *is*.
      expect(data(r'+$4,370.40'), isNot(equals(data(r'+$4,370.41'))));
    });
  });
}
