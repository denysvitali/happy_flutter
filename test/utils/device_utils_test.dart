import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:happy_flutter/core/utils/device_utils.dart';

void main() {
  group('DeviceDimensions', () {
    test('stores dimensions', () {
      const dims = DeviceDimensions(
        widthInches: 2.5,
        heightInches: 5.0,
        diagonalInches: 5.59,
      );
      expect(dims.widthInches, 2.5);
      expect(dims.heightInches, 5.0);
      expect(dims.diagonalInches, 5.59);
    });
  });

  group('calculateDeviceDimensions', () {
    test('calculates correct inches for Android density', () {
      final result = calculateDeviceDimensions(
        widthPoints: 360,
        heightPoints: 800,
        pointsPerInch: 160,
      );
      expect(result.widthInches, closeTo(2.25, 0.01));
      expect(result.heightInches, closeTo(5.0, 0.01));
    });

    test('calculates correct inches for iOS density', () {
      final result = calculateDeviceDimensions(
        widthPoints: 375,
        heightPoints: 812,
        pointsPerInch: 163,
      );
      expect(result.widthInches, closeTo(2.3, 0.01));
      expect(result.heightInches, closeTo(4.98, 0.01));
    });

    test('calculates diagonal using Pythagorean theorem', () {
      final result = calculateDeviceDimensions(
        widthPoints: 320,
        heightPoints: 480,
        pointsPerInch: 160,
      );
      final expectedDiagonal = math.sqrt(2.0 * 2.0 + 3.0 * 3.0);
      expect(result.diagonalInches, closeTo(expectedDiagonal, 0.01));
    });

    test('defaults to 160 ppi', () {
      final result = calculateDeviceDimensions(
        widthPoints: 320,
        heightPoints: 640,
      );
      expect(result.widthInches, 2.0);
      expect(result.heightInches, 4.0);
    });

    test('square device has diagonal of side * sqrt(2)', () {
      final result = calculateDeviceDimensions(
        widthPoints: 320,
        heightPoints: 320,
        pointsPerInch: 160,
      );
      expect(result.widthInches, 2.0);
      expect(result.heightInches, 2.0);
      expect(result.diagonalInches, closeTo(2.0 * math.sqrt2, 0.01));
    });
  });

  group('DeviceType enum', () {
    test('has phone and tablet', () {
      expect(DeviceType.values.length, 2);
      expect(DeviceType.values, contains(DeviceType.phone));
      expect(DeviceType.values, contains(DeviceType.tablet));
    });
  });

  group('determineDeviceType', () {
    test('returns phone for small diagonal', () {
      final result = determineDeviceType(
        diagonalInches: 6.5,
        platform: 'android',
      );
      expect(result, DeviceType.phone);
    });

    test('returns tablet for large diagonal', () {
      final result = determineDeviceType(
        diagonalInches: 10.0,
        platform: 'android',
      );
      expect(result, DeviceType.tablet);
    });

    test('uses custom threshold', () {
      final result = determineDeviceType(
        diagonalInches: 8.0,
        platform: 'android',
        tabletThresholdInches: 7,
      );
      expect(result, DeviceType.tablet);
    });

    test('threshold boundary returns tablet', () {
      final result = determineDeviceType(
        diagonalInches: 9.0,
        platform: 'android',
      );
      expect(result, DeviceType.tablet);
    });

    test('just below threshold returns phone', () {
      final result = determineDeviceType(
        diagonalInches: 8.99,
        platform: 'android',
      );
      expect(result, DeviceType.phone);
    });

    test('iPad with large diagonal is tablet', () {
      final result = determineDeviceType(
        diagonalInches: 10.5,
        platform: 'ios',
        isPad: true,
      );
      expect(result, DeviceType.tablet);
    });

    test('iPad mini treated as phone', () {
      final result = determineDeviceType(
        diagonalInches: 8.3,
        platform: 'ios',
        isPad: true,
      );
      expect(result, DeviceType.phone);
    });

    test('non-iPad uses general threshold', () {
      final result = determineDeviceType(
        diagonalInches: 10.5,
        platform: 'ios',
        isPad: false,
      );
      expect(result, DeviceType.tablet);
    });

    test('small non-iPad is phone', () {
      final result = determineDeviceType(
        diagonalInches: 6.1,
        platform: 'ios',
        isPad: false,
      );
      expect(result, DeviceType.phone);
    });

    test('foldable phone treated as phone', () {
      final result = determineDeviceType(
        diagonalInches: 7.6,
        platform: 'android',
      );
      expect(result, DeviceType.phone);
    });
  });

  group('calculateHeaderHeight', () {
    test('Mac Catalyst returns 56', () {
      final result = calculateHeaderHeight(
        platform: 'mac',
        isLandscape: false,
        isMacCatalyst: true,
      );
      expect(result, 56);
    });

    test('web returns 56', () {
      final result = calculateHeaderHeight(
        platform: 'web',
        isLandscape: false,
      );
      expect(result, 56);
    });

    test('Android phone portrait returns 56', () {
      final result = calculateHeaderHeight(
        platform: 'android',
        isLandscape: false,
        deviceType: DeviceType.phone,
      );
      expect(result, 56);
    });

    test('Android phone landscape returns 48', () {
      final result = calculateHeaderHeight(
        platform: 'android',
        isLandscape: true,
        deviceType: DeviceType.phone,
      );
      expect(result, 48);
    });

    test('Android tablet returns 64', () {
      final result = calculateHeaderHeight(
        platform: 'android',
        isLandscape: false,
        deviceType: DeviceType.tablet,
      );
      expect(result, 64);
    });

    test('Android without deviceType defaults to tablet height', () {
      final result = calculateHeaderHeight(
        platform: 'android',
        isLandscape: false,
      );
      expect(result, 64);
    });

    test('iPad returns 50', () {
      final result = calculateHeaderHeight(
        platform: 'ios',
        isLandscape: false,
        isPad: true,
      );
      expect(result, 50);
    });

    test('iPhone returns 44', () {
      final result = calculateHeaderHeight(
        platform: 'ios',
        isLandscape: false,
        isPad: false,
      );
      expect(result, 44);
    });

    test('iPhone landscape still returns 44', () {
      final result = calculateHeaderHeight(
        platform: 'ios',
        isLandscape: true,
        isPad: false,
      );
      expect(result, 44);
    });

    test('isMacCatalyst takes priority over platform', () {
      final result = calculateHeaderHeight(
        platform: 'ios',
        isLandscape: false,
        isMacCatalyst: true,
      );
      expect(result, 56);
    });
  });
}
