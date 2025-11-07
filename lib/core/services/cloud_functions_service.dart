import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Service for calling Cloud Functions
class CloudFunctionsService {
  final FirebaseFunctions _functions;

  CloudFunctionsService({FirebaseFunctions? functions})
      : _functions = functions ?? FirebaseFunctions.instanceFor(region: 'asia-southeast1');

  /// Manually generate QR code for a session if auto-generation failed
  Future<Map<String, dynamic>> generateSessionQR(String sessionId) async {
    try {
      final callable = _functions.httpsCallable('generateSessionQR');
      final result = await callable.call<Map<String, dynamic>>({'sessionId': sessionId});
      return result.data;
    } on FirebaseFunctionsException catch (e) {
      throw Exception('Cloud Function error: ${e.code} - ${e.message}');
    } catch (e) {
      throw Exception('Failed to generate session QR: $e');
    }
  }

  /// Validate QR code payload (existing function)
  Future<Map<String, dynamic>> validateQrCode(String payload) async {
    try {
      final callable = _functions.httpsCallable('validateQrCode');
      final result = await callable.call<Map<String, dynamic>>({'payload': payload});
      return result.data;
    } on FirebaseFunctionsException catch (e) {
      throw Exception('Cloud Function error: ${e.code} - ${e.message}');
    } catch (e) {
      throw Exception('Failed to validate QR code: $e');
    }
  }
}

/// Provider for CloudFunctionsService
final cloudFunctionsServiceProvider = Provider<CloudFunctionsService>((ref) {
  return CloudFunctionsService();
});
