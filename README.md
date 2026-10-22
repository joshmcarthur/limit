# Limit

A small, open-source iOS app that shows the posted speed limit for the road you are on in Aotearoa New Zealand, next to your GPS speed. Limits come from the NZTA National Speed Limit Register, downloaded and kept in sync on the device. Design: see the Limit design system (colours, sign, readout, driving rules).

## Layout

- `Sources/LimitCore` – platform-independent logic (Foundation only; builds on Linux).
- `Tests/LimitCoreTests` – unit tests for the core.

## Develop

```sh
swift build
swift test
```
