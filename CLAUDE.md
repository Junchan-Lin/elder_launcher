# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

Elder Launcher — a Flutter Android launcher app focused on legibility and simplicity for elderly users. Three home tabs: Apps, Contacts, LINE.

## Commands

```bash
flutter pub get                                  # install deps
flutter analyze --no-fatal-infos --no-fatal-warnings  # lint (matches CI)
flutter test                                     # run all tests
flutter test test/data_sources/app_repository_test.dart  # run a single test file
flutter test --plain-name "Loads all apps"       # run a single test by name
flutter run                                      # run on connected device/emulator
```

CI (`.github/workflows/ci.yml`) runs `flutter pub get`, `flutter analyze`, then `flutter test` on every push/PR — always keep both green.

Localized strings live in `lib/l10n/intl_*.arb`; generated Dart output goes to `lib/generated/` (excluded from analyzer, via `flutter_intl`/`intl_utils` — regenerate with `flutter pub run intl_utils:generate` after editing `.arb` files, not by hand).

## Architecture

**Layering:** `data_sources/` (repositories) → `providers/` (ChangeNotifier state) → `ui/pages/` (widgets). Providers are registered once in `MultiProvider` in `lib/main.dart` and injected via `provider`; widgets read them with `context.watch`/`context.read`.

- **`DataRepository` interface** (`lib/models/interfaces/data_repository.dart`): `getAllItems()`, `getFavItems()`, `setFavItems()`. Implemented by `AppRepository`, `ContactRepository`, `LineRepository` — each backs one home tab and normalizes its source data into the shared `Item` model (`id`, `name`, `icon`).
- **Providers** (`lib/providers/`) own loading state, periodic refresh timers, and permission checks; they call into repositories and `NativeMethods`, then `notifyListeners()`. Each provider that owns a `Timer`/`StreamSubscription` cancels it in `dispose()` — follow this pattern for any new provider.
- **`NativeMethods`** (`lib/utils/native_methods.dart`) wraps two `MethodChannel`s defined in `lib/constants/channels.dart` (`channelCore`, `channelContacts`) that talk to the Android side in `android/app/src/main/kotlin/com/code_sky/customlancher/MainActivity.kt`. When adding a new native call, add the Dart method here, the Kotlin handler case in `MainActivity.kt`'s `setMethodCallHandler`, and the channel/method-name constant.
- **`EditService`** (`lib/services/edit_service.dart`) is a transient `ChangeNotifier` created per edit session (not registered globally) — it merges "all items" and "fav items" into one sorted, reorderable list for `EditPage`/`ReorderPage`, tracking favourite positions until the user saves.
- **Routing**: `lib/ui/router.dart`'s `generateRoute` is the single `onGenerateRoute` for `MaterialApp`; route name constants live in `lib/constants/route_names.dart`, and `EditMode` (apps/contacts/line) is passed as route arguments to make `EditPage`/`ReorderPage` generic across the three tabs.
- **Persistence**: all key-value storage goes through the static `SharedPrefs` wrapper (`lib/utils/shared_prefs.dart`) over `shared_preferences`; keys are centralized in `lib/constants/keys.dart`. Don't call `SharedPreferences` directly elsewhere.
- **Default launcher flow**: `AppProvider` checks `canSetDefaultLauncher` on startup and listens for a `setDefaultLauncherFailure` callback from native code (round-trip through `channelCore`) to re-show the "set as default" prompt if the user backs out of the system dialog.

## Testing conventions

- Tests mock platform channels directly (e.g. `MethodChannel('g123k/device_apps').setMockMethodCallHandler(...)`) rather than mocking the Dart plugin API — see `test/utils/set_mock_*.dart` and `test/test_data/fake_*.dart` for reusable fixtures.
- Call `TestWidgetsFlutterBinding.ensureInitialized()` and `SharedPrefs.init()` (with `SharedPreferences.setMockInitialValues` as needed) before exercising repositories/providers that touch prefs.

## Contribution rules (from `docs/CONTRIBUTING.md`)

- Work in a `feature`/`patch` branch, not directly on main.
- Don't touch pubspec files unless a dependency change is actually required.
- Translation-only changes must be a separate PR from feature/bugfix/UI PRs.
- New major features or visual/UX changes should align with the project's legibility/simplicity focus.
