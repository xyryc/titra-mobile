# Titra – Architecture

## Overview

- **MVVM** with **widget-level (feature)** folder structure
- **Provider** for state management
- **Single API client** used for all network calls
- **Global error/success** via custom snackbar

## Folder structure

```
lib/
├── main.dart                 # Entry, creates navigatorKey and runs TitraApp
├── app.dart                  # MultiProvider + MaterialApp, register global & feature providers
├── core/
│   ├── api/
│   │   ├── api_client.dart   # Single class for all API calls (Dio); use this everywhere
│   │   └── api_exception.dart
│   ├── constants/
│   │   └── api_constants.dart  # baseUrl, timeouts
│   ├── services/
│   │   └── snackbar_service.dart  # Global success/error snackbar
│   ├── theme/
│   │   └── app_theme.dart
│   └── widgets/             # Global reusable components
│       ├── custom_snackbar.dart
│       ├── app_button.dart
│       ├── app_text_field.dart
│       └── loading_overlay.dart
└── features/
    └── <feature_name>/
        ├── data/            # Repositories, models
        ├── presentation/
        │   ├── view/        # Screens
        │   ├── view_models/
        │   └── widgets/     # Feature-specific widgets
```

## API usage

- **All** API calls must go through `ApiClient` (injected via Provider).
- Get it in repositories: `context.read<ApiClient>()` or constructor injection from `app.dart`.
- Errors are shown globally via custom snackbar; for success after mutations call `apiClient.showSuccessMessage('Done')`.

## Adding a new feature

1. Create `features/<name>/data/<name>_repository.dart` (constructor: `ApiClient`).
2. Create `features/<name>/presentation/view_models/<name>_view_model.dart` (extends `ChangeNotifier`, takes repository).
3. Create `features/<name>/presentation/view/<name>_screen.dart` (use `Provider`/`context.read`/`context.watch`).
4. In `app.dart`: add `Provider<YourRepository>` and `ChangeNotifierProvider<YourViewModel>`, and add a route or button to your screen.

## Global snackbar

- `SnackbarService` is provided in `app.dart` and used by `ApiClient` for errors.
- From anywhere with access to the service: `context.read<SnackbarService>().showSuccess('...')` or `showError('...')`.
