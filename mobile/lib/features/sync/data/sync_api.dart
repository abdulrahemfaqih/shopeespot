import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../domain/sync_models.dart';

abstract class ISyncApi {
  Future<SyncResponseDto> sync(SyncRequestDto request);
}

class SyncApi implements ISyncApi {
  final Dio _dio;

  SyncApi(this._dio);

  @override
  Future<SyncResponseDto> sync(SyncRequestDto request) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/v1/sync',
      data: request.toJson(),
    );

    if (response.data == null) {
      throw Exception('Format respon sync kosong dari server.');
    }

    return SyncResponseDto.fromJson(response.data!);
  }
}

final syncApiProvider = Provider<ISyncApi>((ref) {
  final dio = ref.watch(dioProvider);
  return SyncApi(dio);
});
