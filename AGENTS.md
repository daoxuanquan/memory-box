# AGENTS.md — MemoryBox

Instructions for Cursor, Codex, and other coding agents working in this repo.

## Product

MemoryBox is an iOS couple journal: shared memories, love messages, special days, profiles. Stack: **SwiftUI**, **Core Data**, **CloudKit** (private + shared stores).

## Critical docs

| Doc | When to read |
|-----|----------------|
| [`docs/onboarding-couple-share-flow.md`](docs/onboarding-couple-share-flow.md) | Any onboarding, invite link, CKShare, join/leave couple space work |
| [`.cursor/rules/karpathy-guidelines.mdc`](.cursor/rules/karpathy-guidelines.mdc) | Always — small, intentional diffs |
| [`.cursor/rules/swiftui-mvvm.mdc`](.cursor/rules/swiftui-mvvm.mdc) | New SwiftUI features |
| [`.cursor/rules/file-splitting.mdc`](.cursor/rules/file-splitting.mdc) | Creating/editing Swift files |
| [`.cursor/rules/onboarding-share.mdc`](.cursor/rules/onboarding-share.mdc) | Files under Onboarding / Share |

## Architecture (required for new code)

```
View (SwiftUI) → ViewModel (@MainActor, @Observable) → Service/Store → Core Data / CloudKit
```

- **Views** do not call `MemoryStore` / CloudKit directly for new flows.
- **ViewModels** own screen state and intents.
- **Services** own persistence and sharing (`CoupleShareService`, `OnboardingStore`, existing `MemoryStore` during migration).
- Split files: one screen per file; subviews get their own file when large; no new god-files.

### Target folders

```
MemoryBox/
  Views/<Feature>/
  ViewModels/<Feature>/
  Services/
  Models/
  Persistence/          # legacy — avoid adding feature APIs here
```

## Onboarding & share — non-negotiables

1. First launch is gated by onboarding (Create / Join / Solo), not raw Home.
2. Share accept always shows success or failure UI.
3. User picks `myRole` explicitly (first/second).
4. Invite partner is part of Create onboarding + Settings, not Settings-only.
5. No silent accept. No `UICloudSharingController` as primary invite UI.
6. Private vs shared conflict → `ShareConflictView` (no auto-merge in MVP).

Implement in the order listed in the onboarding doc §13.

## UI conventions

- Horizontal padding **24pt** on onboarding; primary CTA height **52**.
- Vietnamese copy from the onboarding spec.
- Reuse `AnimatedLoveBackdrop`, pink tint, `AppTheme` adaptive colors.

## Git / hygiene

- Author for this machine should be user-configured (`quandx` / personal email).
- Do not commit `xcuserdata`, `.DS_Store`, or secrets.
- Do not force-push unless explicitly requested.
- Prefer small commits; do not mix unrelated refactors with feature work.

## Legacy reality check

Much of the app still has Views calling `MemoryStore` from `ContentView`. When you touch a screen non-trivially, extract a ViewModel. Do **not** rewrite the entire app unprompted.

## Definition of done (feature work)

- [ ] Matches the relevant doc/spec
- [ ] ViewModel owns logic for new screens
- [ ] Files stay focused and under ~250–300 lines when practical
- [ ] Build-safe against deployment target (currently iOS 17.6 — no iOS 26-only APIs without availability + fallback)
- [ ] Share/onboarding changes include success/failure UX
