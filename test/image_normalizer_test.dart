import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image_picker/image_picker.dart';
import 'package:smart_noties/services/image_normalizer.dart';

void main() {
  final heic = Uint8List.fromList([
    0,
    0,
    0,
    24,
    ...'ftypheic'.codeUnits,
    0,
    0,
    0,
    0,
    ...'heicmif1'.codeUnits
  ]);
  final jpeg = Uint8List.fromList([255, 216, 255, 224, 0, 0]);
  test('HEIC preview uses authenticated conversion and receives JPEG',
      () async {
    final client = MockClient((request) async {
      expect(request.url.path, '/api/image/normalize');
      expect(request.headers['Authorization'], 'Bearer token');
      expect(request.bodyBytes, containsAllInOrder('ftypheic'.codeUnits));
      return http.Response.bytes(jpeg, 200,
          headers: {'content-type': 'image/jpeg'});
    });
    final result = await ImageNormalizer(client: client)
        .normalize(XFile.fromData(heic, name: 'photo.HEIC'), token: 'token');
    expect(result, jpeg);
  });
  test('Already converted JPEG with HEIC name does not need a server',
      () async {
    final result = await const ImageNormalizer()
        .normalize(XFile.fromData(jpeg, name: 'photo.HEIC'));
    expect(result, isNull);
  });
  test('HTML response cannot become a preview image', () async {
    final client = MockClient((_) async => http.Response(
        '<html>error</html>', 200,
        headers: {'content-type': 'text/html'}));
    await expectLater(
        ImageNormalizer(client: client).normalize(
            XFile.fromData(heic, name: 'photo.heic'),
            token: 'token'),
        throwsException);
  });
  test('HEIC without a session fails instead of attempting anonymous upload',
      () async {
    await expectLater(
        const ImageNormalizer()
            .normalize(XFile.fromData(heic, name: 'photo.heic')),
        throwsException);
  });
}
