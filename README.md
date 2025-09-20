# Lang Q Localization

A Flutter localization package that seamlessly integrates with
[Lang Q](https://lang-q.com) to manage your app's translations with type-safe
key generation.

## Features

- 🚀 **Quick Setup** - Get started in just 4 simple steps
- 🤖 **AI-Powered Translation** - Extract hardcoded strings and translate
  automatically
- 🔄 **Automatic Sync** - Push and pull translations seamlessly with Lang Q
  downloads
- 🛡️ **Type-Safe Keys** - Auto-generated keys with required parameters prevent
  runtime errors
- 🔢 **Advanced Pluralization** - Full support for plurals, including nested
  plural forms
- 📦 **Zero Boilerplate** - Minimal configuration required
- 🔄 **Smart Code Replacement** - Automatically replace hardcoded strings with
  function calls

## Installation

Add `langq_localization` to your `pubspec.yaml`:

```yaml
dependencies:
  langq_localization: ^<version>
```

Then run:

```console
flutter pub get
```

## Configure API Key

Create a `.env` file in your project root and add your Lang Q project API key:

```.env
LANGQ_API_KEY=your_project_api_key_here
```

**Note**: Add `.env` to your `.gitignore` to keep your API key secure.

# Setup Guide (Just 4 Steps)

## Step 1: Add Strings and Translate

### Step 1a: One-Command Translation

The fastest way to internationalize your Flutter app is with the `translate`
command:

```console
dart run langq_localization:translate
```

**This single command does everything:**

- ✨ Extracts all hardcoded strings from your code
- 📤 Pushes them to Lang Q for AI translation
- 📥 Pulls the translated content and generates type-safe functions
- 🔄 Replaces your original strings with function calls automatically

**Before:**

```dart
Text('Welcome to our app!')
Text('You have ${count} messages')
```

**After:**

```dart
Text(LangQKey.welcomeMessage())
Text(LangQKey.messageCount(count: count))
```

### Step 1b: Extract, Review, and Translate (Multiple-Command)

For more control over the translation process, you can use individual commands:

**Step-by-Step Approach**

**Step 1: Extract Strings**

```
dart run langq_localization:extract
```

This scans your code and creates `.langq/extracted_strings.json` with all
translatable strings for review.

#### Comparison: Manual vs Automatic

| Method                         | Use Case                              | Commands   | Review Process                       |
| ------------------------------ | ------------------------------------- | ---------- | ------------------------------------ |
| Automatic (translate)          | Fast development, trust AI extraction | 1 command  | None - fully automated               |
| Manual (extract → push → pull) | Review strings before translation     | 3 commands | Review .langq/extracted_strings.json |

### Extraction Configuration

Both methods use the same configuration. The first run creates `langq.yaml`:

```yaml
# This file is auto-generated. Modify as needed.
extraction:
  exclude:
    - "lib/l10n/**" # Always excluded
    - "**/*.g.dart" # Generated files
    - "**/*.freezed.dart" # Freezed files
```

#### Ignoring Strings

Use `@langq-ignore` to exclude specific strings from extraction:

```dart
class DebugPanel extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column([
      Text('Welcome User'),  // This WILL be extracted
      
      // @langq-ignore
      Text('DEBUG: Internal state: $debugValue'),  // This will NOT be extracted
      
      Text('Settings'),  // This WILL be extracted
    ]);
  }
}
```

#### When to Use @langq-ignore

**Should ignore:**

- Debug messages and developer logs
- Internal error codes and technical identifiers
- Temporary placeholder text during development
- Configuration keys that shouldn't be translated

**Should NOT ignore:**

- User-facing error messages
- Button labels and navigation text
- Form labels and input hints
- Dialog content and notifications

### Step 1c: Add Strings Manually via Dashboard (https://app.lang-q.com)

- Log in to the app and add keys in relavant project

**Step 2: Push for Translation**

```
dart run langq_localization:push
```

Sends the extracted strings to Lang Q for AI translation.

## Step 2: Pull Translations

**Skip this step if you use the `translate` command in Step 1a**

Run the following command to download your localization files and generate
type-safe keys and replaces your code (if extracted):

```console
dart run langq_localization:pull
```

This generates keys as functions with required parameters:

```dart
// Generated from: "Hello, {userName}!"
static String welcomeMessage({required String userName}) {
  return LangQ.text('welcome.message', args: {'userName': userName});
}
```

This generates:

```dart
// Generated from: "Hello, {userName}!"
static String get welcomeMessage => 'welcome.message';
```

## Project Structure

After running `dart run langq_localization:pull`, your project will have:

```
your_project/
|
├── .langq/                          # Working files (auto-generated), if extracted from command
│   └── extracted_strings.json       # Extracted strings for review
├── lib/
│   └── l10n/
│       ├── generated/               # Generated code
│       │   ├── langq_key.g.dart    # Translation functions
│       │   └── langq_locales.g.dart # Supported locales
│       └── translations/           # Translation files
│           ├── en-US.json
│           └── fr-CA.json
├── langq.yaml                      # Configuration
└── .gitignore                      # Updated to ignore .langq/
```

### Add translations to assets

Add the translations folder to your `pubspec.yaml`:

```yaml
flutter:
  assets:
    - lib/l10n/translations/
```

## Step 3: Initialize Lang Q

Update your `main.dart`:

```dart
import 'package:<your_package_name>/l10n/generated/langq_locales.g.dart';
import 'package:flutter/material.dart';
import 'package:langq_localization/langq.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Lang Q
  await LangQ.init();
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Wrap MaterialApp with LangQ.builder
    return LangQ.builder(
      builder: (context, langq) {
        return MaterialApp(
          // Required delegates for localization
          localizationsDelegates: langq.localizationsDelegates,
          
          // Current locale
          locale: langq.currentLocale,
          
          // Auto-generated supported locales
          supportedLocales: LangQLocales.supportedLocales,
          
          title: 'Your App',
          home: const HomePage(),
        );
      },
    );
  }
}
```

## Step 4: Using Translations

## Method 1: Function Calls (Recommended)

```dart
import 'package:<your_package_name>/l10n/generated/langq_key.g.dart';

class HomePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Text(
          // Type-safe with required parameters
          LangQKey.welcomeMessage(userName: 'John'),
          style: Theme.of(context).textTheme.headlineMedium,
        ),
      ),
    );
  }
}
```

## Method 2: Extension Method

For a more familiar syntax similar to `easy_localization`:

```dart
import 'package:<your_package_name>/l10n/generated/langq_key.g.dart';

Text(
  LangQKey.welcomeMessage.tr(args: {'userName': 'John'}),
  style: Theme.of(context).textTheme.bodyLarge,
)
```

**Note**: To use the `.tr()` extension method, generate string keys by running:

```console
dart run langq_localization:pull --strings
```

# Built-in Formatting

Lang Q provides built-in formatting extensions powered by `intl` for common data
types. All formatters automatically use the current locale.

## Number Formatting

```dart
Text(
  1234567.numberFormat(),  // Output: 1,234,567 (en) or 1 234 567 (fr)
  style: Theme.of(context).textTheme.bodyLarge,
),
```

## Date Formatting

```dart
Text(
  DateTime.now().dateFormat(),  // Output: Jan 15, 2025 (en) or 15 janv. 2025 (fr)
  style: Theme.of(context).textTheme.bodyLarge,
),
```

## Time Formatting

```dart
Text(
  DateTime.now().timeFormat(),  // Output: 3:45 PM (en) or 15:45 (fr)
  style: Theme.of(context).textTheme.bodyLarge,
),
```

## Percentage Formatting

```dart
Text(
  0.854.percentageFormat(),  // Output: 85.4%
  style: Theme.of(context).textTheme.bodyLarge,
),
```

## Currency Formatting

**Note**: Currency symbols vary by locale. Consider exchange rates for
multi-currency apps.

```dart
Text(
  1234.56.currencyFormat(),  // Output: $1,234.56 (en-US) or 1 234,56 € (fr-FR)
  style: Theme.of(context).textTheme.bodyLarge,
),
```

# Custom Formatting

You can also use `intl` directly for advanced formatting needs:

```dart
import 'package:intl/intl.dart';

// Custom date pattern
final customDate = DateFormat('EEEE, MMMM d, y').format(DateTime.now());
```

# Changing Locale

## Using Generated Locale Constants

```dart
// Type-safe locale switching
await LangQ.setLocale(LangQLocales.frCA);
```

## Using Locale Object

```dart
await LangQ.setLocale(const Locale('fr', 'CA'));
```

## Getting Current Locale

```dart
final currentLocale = LangQ.currentLocale;
print('Current language: ${currentLocale.languageCode}');
```

# Best Practices

1. Keep your `.env` file secure - Never commit API keys to version control
2. Use function keys - They provide compile-time safety for parameters
3. Organize keys hierarchically - Use dot notation for better organization
   (e.g., `auth.login.button`)
4. Use the `translate` command for fastest development
5. Use manual commands when you need to review extracted strings
6. Use `@langq-ignore` for debug messages and technical strings
7. Test locale switching to ensure proper UI layout
8. Keep **.langq/** */ in **.gitignore** to avoid committing working files

# Troubleshooting

## Missing Translations

If a translation is missing, Lang Q will display the key itself as a fallback.

## Build Errors

Ensure you've added translation assets to `pubspec.yaml`.

# Support

📧 Email: team@lang-q.com

# License

This package is licensed under the MIT License. See [LICENSE] for details.
