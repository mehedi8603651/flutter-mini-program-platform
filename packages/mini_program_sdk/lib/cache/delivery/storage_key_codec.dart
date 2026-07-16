import 'dart:convert';

String encodeDeliveryCacheKey(String value) {
  return base64Url.encode(utf8.encode(value));
}
