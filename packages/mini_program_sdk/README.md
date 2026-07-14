# mini_program_sdk

Flutter runtime SDK for rendering mini-program UI from static Mp JSON artifacts.

The SDK stays provider-neutral:

- artifact opening uses `MiniProgramEndpoint.public(apiBaseUri: artifactBaseUrl)`
- optional runtime data uses the artifact-owned `publisher_backend.json`
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

```json
{
  "schemaVersion": 1,
  "type": "mini_program_publisher_backend_contract",
  "contractVersion": "1",
  "appId": "coupon_demo",
  "backendBaseUrl": "https://publisher.example.com/api/coupon_demo/",
  "permissionReason": "Load current coupon offers.",
  "healthEndpoint": "health",
  "smokeTests": [
    {
      "id": "health",
      "method": "GET",
      "endpoint": "health",
      "expectedStatus": 200,
      "expectJsonObject": true
    }
  ]
}
```

Artifact tooling validates and packages this file. The generated endpoint sets
`publisherApiPolicy` from host-owned accepted policy. During loading, the SDK
reads the contract, checks that policy, and creates an app-scoped connector.
Denied calls fail with `publisher_api_disabled`.

Runtime APIs are used only by actions such as `Mp.backend.call`,
`Mp.backend.query`, `Mp.lazy.chunk`, search/load-more, and form submit.

## Host Rule

Opening a mini-program requires only `appId + artifactBaseUrl`. The publisher
owns the optional runtime API declaration; the host owns only permission to use
it.
