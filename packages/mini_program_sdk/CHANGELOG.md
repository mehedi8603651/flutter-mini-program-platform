## 0.5.2

- Give `MiniProgramPage` loaded content a normal scaffold and light surface instead of inheriting a dark/transparent host route background.

## 0.5.1

- Fix Android release builds by using const Material `IconData` values for Mp runtime icons.

## 0.5.0

- Remove artifact credential fields and headers from endpoint/source models.
- Keep static artifact loading provider-neutral through `artifactBaseUrl`.
- Keep optional runtime middle-server connectors for backend actions.
- Rename host-only cache priority to `hostPinned`.
