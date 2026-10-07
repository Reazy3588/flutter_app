import 'package:dio/dio.dart';
import '../models/address_model.dart';
import 'api_service.dart';

class AddressService {
  final Dio _dio = ApiService().dio;

  /// GET /api/accounts/addresses/
  Future<List<AddressModel>> getAddresses() async {
    final res = await _dio.get('/accounts/addresses/');
    final data = res.data;
    final List results =
        (data is List) ? data : (data['results'] as List? ?? []);
    return results.map((json) => AddressModel.fromJson(json)).toList();
  }

  /// POST /api/accounts/addresses/
  Future<AddressModel> createAddress(AddressModel address) async {
    final res = await _dio.post('/accounts/addresses/', data: address.toJson());
    return AddressModel.fromJson(res.data);
  }

  /// PUT /api/accounts/addresses/<id>/
  Future<AddressModel> updateAddress(int id, AddressModel address) async {
    final res =
        await _dio.put('/accounts/addresses/$id/', data: address.toJson());
    return AddressModel.fromJson(res.data);
  }

  /// DELETE /api/accounts/addresses/<id>/
  Future<void> deleteAddress(int id) async {
    await _dio.delete('/accounts/addresses/$id/');
  }
}
