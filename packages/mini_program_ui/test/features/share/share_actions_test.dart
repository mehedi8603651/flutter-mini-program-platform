import 'package:mini_program_ui/mini_program_ui.dart';
import 'package:test/test.dart';

void main() {
  test('share open serializes text, URL, media, and state options', () {
    expect(
      Mp.share
          .open(
            title: 'Send photo',
            text: 'Captured from the mini-program',
            url: 'https://example.com/photo',
            mediaRefs: const <String>['{{state.photo.media_ref}}'],
            targetState: 'share.result',
            statusState: 'share.status',
            errorState: 'share.error',
            requestId: 'share-photo',
          )
          .toJson(),
      <String, Object?>{
        'type': 'share.open',
        'props': <String, Object?>{
          'title': 'Send photo',
          'text': 'Captured from the mini-program',
          'url': 'https://example.com/photo',
          'mediaRefs': <String>['{{state.photo.media_ref}}'],
          'targetState': 'share.result',
          'statusState': 'share.status',
          'errorState': 'share.error',
          'requestId': 'share-photo',
        },
      },
    );
  });

  test('share accepts a bound media list and fire-and-forget text', () {
    expect(
      Mp.share.open(mediaRefs: '{{state.photos}}').toJson(),
      <String, Object?>{
        'type': 'share.open',
        'props': <String, Object?>{'mediaRefs': '{{state.photos}}'},
      },
    );
    expect(Mp.share.open(text: 'Hello').toJson(), isNotEmpty);
  });

  test('share rejects absent content, unsafe URLs, and oversized media', () {
    expect(() => Mp.share.open(title: 'Only a title'), throwsArgumentError);
    expect(() => Mp.share.open(url: 'http://example.com'), throwsArgumentError);
    expect(
      () => Mp.share.open(mediaRefs: List<String>.filled(11, 'media')),
      throwsArgumentError,
    );
    expect(
      () => Mp.share.open(text: 'Hello', targetState: 'share..result'),
      throwsArgumentError,
    );
  });
}
