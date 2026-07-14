# mini_program_sdk

Flutter runtime SDK for rendering mini-program UI from static Mp JSON artifacts.

The SDK stays provider-neutral:

- artifact opening uses `MiniProgramEndpoint.public(apiBaseUri: artifactBaseUrl)`
- optional runtime data uses `MiniProgramBackendEndpoint(baseUri: middleServerApiUrl)`
- provider SDKs, database clients, payment clients, secrets, and business rules stay outside the host app

## Static Opening

```dart
final config = MiniProgramConfig(
  source: EndpointRoutingMiniProgramSource(
    endpoints: {
      'coupon_demo': MiniProgramEndpoint.public(
        apiBaseUri: Uri.parse('https://static.example.com/coupon_demo/'),
      ),
    },
  ),
);
```

The host fetches manifest and screen/static artifact JSON from the artifact base URL. No runtime API URL is required to open the mini-program.

Artifact-local JSON resources are loaded through the optional
`MiniProgramJsonAssetSource` capability. `HttpMiniProgramSource` and
`EndpointRoutingMiniProgramSource` implement it for immutable files at
`artifacts/<appId>/<version>/assets/<path>`. Resources are constrained by the
host-accepted `data` cache policy and are never copied wholesale into live
state.

## Optional Runtime API

```dart
final config = MiniProgramConfig(
  source: EndpointRoutingMiniProgramSource(
    endpoints: {
      'coupon_demo': MiniProgramEndpoint.public(
        apiBaseUri: Uri.parse('https://static.example.com/coupon_demo/'),
        backend: MiniProgramBackendEndpoint(
          baseUri: Uri.parse('https://publisher.example.com/api/'),
        ),
      ),
    },
  ),
  backendConnector: buildEndpointRoutingBackendConnector(
    endpoints: {
      'coupon_demo': MiniProgramEndpoint.public(
        apiBaseUri: Uri.parse('https://static.example.com/coupon_demo/'),
        backend: MiniProgramBackendEndpoint(
          baseUri: Uri.parse('https://publisher.example.com/api/'),
        ),
      ),
    },
    deliveryContext: deliveryContext,
  ),
);
```

Runtime APIs are used only by actions such as `Mp.backend.call`, `Mp.backend.query`, `Mp.lazy.chunk`, search/load-more, and form submit.

## Host Rule

Opening a mini-program should require only `appId + artifactBaseUrl`. Runtime API config is optional and belongs to runtime behavior, not the host opening contract.
