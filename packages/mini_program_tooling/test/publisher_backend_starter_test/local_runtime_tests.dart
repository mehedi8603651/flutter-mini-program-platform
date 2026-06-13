part of '../publisher_backend_starter_test.dart';

void _registerLocalRuntimeTests() {
  test('runs, serves mock routes, reports status, and stops', () async {
    final starter = const PublisherBackendStarter();
    await starter.scaffold(
      PublisherBackendScaffoldRequest(
        miniProgramRootPath: miniProgramRoot.path,
      ),
    );
    runningPort = await _freePort();

    final runResult = await starter.run(
      miniProgramRootPath: miniProgramRoot.path,
      port: runningPort!,
    );
    expect(runResult.alreadyRunning, isFalse);
    expect(runResult.state.port, runningPort);

    final health = await http.get(
      Uri.parse('http://127.0.0.1:$runningPort/health'),
    );
    expect(health.statusCode, 200);
    final home = await http.get(
      Uri.parse('http://127.0.0.1:$runningPort/home/bootstrap'),
    );
    expect(home.statusCode, 200);
    expect(home.body, contains('Coupon App Publisher API mock'));
    final coupons = await http.get(
      Uri.parse('http://127.0.0.1:$runningPort/coupons/list'),
    );
    expect(coupons.statusCode, 200);
    expect(coupons.body, contains('imageUrl'));
    final couponPage = await http.get(
      Uri.parse('http://127.0.0.1:$runningPort/coupons/page?limit=1'),
    );
    expect(couponPage.statusCode, 200);
    final couponPageJson = jsonDecode(couponPage.body) as Map<String, dynamic>;
    expect(couponPageJson['items'], hasLength(1));
    expect(couponPageJson['hasMore'], isTrue);
    expect(couponPageJson['nextCursor'], 'coupon-10');
    final options = await http.Request(
      'OPTIONS',
      Uri.parse('http://127.0.0.1:$runningPort/coupons/list'),
    ).send();
    expect(options.statusCode, HttpStatus.noContent);
    expect(
      options.headers['access-control-allow-headers'],
      contains('x-mini-program-app-id'),
    );
    expect(
      options.headers['access-control-allow-headers'],
      contains('x-mini-program-host-app'),
    );

    final status = await starter.status(
      miniProgramRootPath: miniProgramRoot.path,
    );
    expect(status.hasState, isTrue);
    expect(status.healthy, isTrue);

    final stop = await starter.stop(miniProgramRootPath: miniProgramRoot.path);
    runningPort = null;
    expect(stop.stopped, isTrue);
  });
}
