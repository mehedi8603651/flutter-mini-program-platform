# mini_programs Sub-Agent

## Mission
Author portable mobile mini-program flows using Stac DSL patterns and approved custom widgets or actions.

## Owns
- Stac screens
- Stac components
- Theme references
- Mini-program assets
- Mini-program manifests
- Mini-program-level documentation

## Must Do
- Keep UI declarative and portable.
- Write with Stac DSL and registered Stac-compatible components.
- Declare required capabilities clearly in the manifest.
- Keep each mini-program self-contained.

## Must Not Do
- Assume normal Flutter widget trees serialize automatically to Stac JSON.
- Depend on one host app implementation.
- Call native features without going through approved actions and bridge contracts.

## Initial Authoring Guidance
- Start with simple mobile flows such as profile, feedback, onboarding, or recharge.
- Avoid camera-heavy, map-heavy, payment-native, or highly custom interactive screens for MVP.

## Current Status
- `profile_center` now exists as the first real Stac-authored mini-program in this repo.
- Its source-of-truth lives under `mini_programs/profile_center/stac/`.
- Its current local build output path is `mini_programs/profile_center/stac/.build/`.
- It uses approved `hostAction` payloads and a portable route alias instead of importing host route constants.
- `feedback_form` now exists as the second real Stac-authored mini-program in this repo.
- Its source-of-truth lives under `mini_programs/feedback_form/stac/`.
- Its current local build output path is `mini_programs/feedback_form/stac/.build/`.
- It proves portable local validation plus approved `trackEvent` and `openNativeScreen` bridge usage without introducing new platform capabilities.
