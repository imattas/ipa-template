# Module 13 — Shipping: Build, Sign & Release

You've built a real, multi-platform app on the `Swift-SwiftUI` template — features, networking, state, navigation, persistence, DI, tests, concurrency, design, and platform polish. Now you'll do the thing that turns a project into a *product*: sign it, archive it, and ship it through TestFlight to the App Store.

This module is a practical, end-to-end map of the release path. It is mostly **configuration, certificates, and process**, not code, so we'll be precise about *where* each setting lives (especially in the template's `App/Info.plist`) and *what each gate actually checks*. The goal is that the first time you hit **Distribute App**, nothing surprises you.

**What you'll learn**

- How to enroll in the Apple Developer Program and what it gets you.
- Bundle identifiers, App IDs, and how capabilities/entitlements relate to them.
- Code signing and provisioning profiles — automatic vs. manual signing, and what you must understand about each.
- App icons and launch assets in the template's `Assets.xcassets`, and the icon sizes Apple requires today.
- Versioning: marketing version vs. build number, and exactly where they live in `Info.plist`.
- How to create an App Store Connect record.
- How to archive (Xcode **Product ▸ Archive** or `xcodebuild archive` + `-exportArchive`).
- How to upload and distribute via TestFlight to internal and external testers.
- How to prepare for App Review: privacy nutrition labels, the privacy manifest (`PrivacyInfo.xcprivacy`), App Transport Security, and a demo account.
- A copy-paste release checklist.

**Prerequisites**

- You've completed [Module 12 — Platform Deep Dives](12-platform-deep-dives.md) and have a universal `Swift-SwiftUI` app that builds and runs on a real iPhone (running on a *device*, not just the simulator, is the first thing signing forces you to get right).
- A Mac with **Xcode 16+** and an Apple ID.

> Apple changes the App Store Connect UI, App Review guidelines, and required asset specs regularly. Treat the *concepts* here as durable and verify exact pixel sizes and screen flows against Apple's current documentation when you ship.

---

## The release path at a glance

```
Apple Developer Program
        │  (membership unlocks distribution)
        ▼
App ID  ─────────►  Capabilities / Entitlements
(bundle identifier)
        │
        ▼
Signing certificate + Provisioning profile
        │
        ▼
Archive (.xcarchive)  ──►  Export / Upload (.ipa)
        │
        ▼
App Store Connect record  ──►  TestFlight  ──►  App Review  ──►  Sale
```

Every step below maps to one box in that diagram.

---

## Step 1 — Enroll in the Apple Developer Program

You can build and run on *your own* device with a free Apple ID. To distribute through TestFlight or the App Store you need a paid **Apple Developer Program** membership (currently US$99/year, or a free fee waiver for eligible organizations).

1. Go to [developer.apple.com/programs](https://developer.apple.com/programs/) and enroll as an **Individual/Sole Proprietor** or an **Organization**.
   - Organization enrollment requires a legal entity and a D-U-N-S number; expect it to take longer (identity verification).
   - Individual enrollment is fastest and ships under your own name.
2. Once approved, your Apple ID gains access to:
   - **Certificates, Identifiers & Profiles** (developer.apple.com account portal) — where App IDs, certificates, and profiles live.
   - **App Store Connect** (appstoreconnect.apple.com) — where app records, TestFlight, pricing, and submissions live.
3. In Xcode, add the account under **Settings ▸ Accounts** so Xcode can manage signing on your behalf.

> If you're on a team, your role matters: only **Admin/App Manager** roles can create app records and submit builds. **Developers** can upload builds. Set this up in App Store Connect ▸ **Users and Access**.

---

## Step 2 — Bundle identifier, App IDs, capabilities & entitlements

These four things sound similar and are constantly confused. Here's the precise relationship:

- **Bundle identifier** — the reverse-DNS string that uniquely identifies your app binary, e.g. `com.example.swiftswiftui`. In this template it's set in [`App/Info.plist`](../../templates/Swift-SwiftUI/App/Info.plist) as `CFBundleIdentifier`:

  ```xml
  <key>CFBundleIdentifier</key>
  <string>com.example.swiftswiftui</string>
  ```

  **Change this before you ship.** `com.example.*` is a placeholder; nobody but Apple's reserved examples can ship under it. Use a domain you control reversed, e.g. `net.mattas.fieldnotes`. In Xcode this surfaces as the target's **Bundle Identifier** build setting (`PRODUCT_BUNDLE_IDENTIFIER`), which the Info.plist's `$(PRODUCT_BUNDLE_IDENTIFIER)` can reference — but the template hard-codes the literal, so update it in both the target setting and the plist (or switch the plist to the `$(PRODUCT_BUNDLE_IDENTIFIER)` variable so there's a single source of truth).

- **App ID** — the *registered* identity in your developer account that the bundle identifier maps to. It can be **explicit** (`net.mattas.fieldnotes`) or a **wildcard** (`net.mattas.*`). With automatic signing, Xcode registers the explicit App ID for you the first time you archive. Wildcard App IDs can't use most capabilities, so prefer explicit.

- **Capabilities** — high-level features you turn on per target in Xcode under **Signing & Capabilities ▸ + Capability** (e.g. Push Notifications, iCloud, Sign in with Apple, App Groups, HealthKit). Turning one on does two things: it updates the App ID's enabled services in your developer account, and it writes the corresponding **entitlements**.

- **Entitlements** — the concrete key/value claims (in a `.entitlements` file) that the system grants your *signed* app, e.g. `aps-environment`, `com.apple.developer.icloud-container-identifiers`. The provisioning profile must authorize every entitlement your binary requests, or signing/validation fails.

> The template ships **no capabilities** by default — it's a clean app, so its entitlements file is empty/absent and it signs trivially. Add capabilities only when a feature needs them; each one you add becomes something App Review may exercise and something your provisioning profile must cover.

---

## Step 3 — Code signing & provisioning profiles

Every app that runs off the simulator must be **code-signed**: a cryptographic signature tying the binary to a certificate Apple issued you, scoped by a **provisioning profile** that says *"this certificate may install this App ID on these devices with these entitlements."*

You have two modes:

### Automatic signing (recommended to start)

In the target's **Signing & Capabilities** tab, check **Automatically manage signing** and pick your **Team**. Xcode then:

- creates/uses a **Development** and **Distribution** signing certificate in your account,
- registers the **App ID** for your bundle identifier,
- generates and downloads matching **provisioning profiles**,
- re-generates them when you add a capability or a new test device.

For a solo developer or a single-app course project, this is the right default. You almost never need to think about certificates.

### Manual signing (for teams, CI, and control)

You explicitly select a certificate and a provisioning profile per configuration. You'll reach for this when:

- a **CI runner** must sign without your interactive Xcode session (see [Module 14 — CI/CD](14-cicd-github-actions.md)) — typically via an **App Store Connect API key** or imported certificate + profile,
- multiple people share signing assets (use **Xcode Cloud** or a tool like **fastlane match** to keep a single source of truth),
- you need a specific, pinned profile for reproducible release builds.

What to know regardless of mode:

- **Two certificate kinds matter:** *Apple Development* (run on devices, test) and *Apple Distribution* (archive for TestFlight/App Store). Distribution is the one that signs your release archive.
- **Profiles expire** (development profiles ~1 year; the certificate ~1 year). Renewing is a click in automatic mode; a re-issue in manual mode.
- **The bundle identifier in the profile must exactly match your app's**, or you'll see *"No profiles for 'X' were found."*
- **Keep your distribution private key safe.** Losing the Mac that holds it means revoking and re-issuing. Export it (`.p12`) and store it securely; CI needs it (or an API key).

---

## Step 4 — App icons & launch assets

The template already contains the catalog you need: [`Resources/Assets.xcassets`](../../templates/Swift-SwiftUI/Resources/Assets.xcassets), with an `AppIcon.appiconset` and an `AccentColor.colorset`. Set the target's **App Icon** build setting (`ASSETCATALOG_COMPILER_APPICON_NAME`) to `AppIcon` and the **Global Accent Color Name** to `AccentColor`.

### App icon

Modern Xcode uses a **single 1024×1024 source image** and renders the smaller sizes for you. The template's `AppIcon.appiconset/Contents.json` is already set up the modern way:

- a **universal iOS** 1024×1024 slot, plus optional **dark** and **tinted** appearance variants (the iOS 18 tintable/dark icon feature),
- the **macOS** ladder (`16` through `512` at `1x`/`2x`) because this is a universal app.

So to brand your app you mostly need to **drop a single 1024×1024 PNG** (no alpha, no transparency, sRGB, square — Apple rejects icons with an alpha channel) into the iOS universal slot, and (optionally) provide the dark/tinted variants and the macOS sizes if you ship on the Mac. If you target only iOS and use the single-size approach, the one 1024 asset is enough; Xcode generates the rest at build time.

> If you ever import an *old* asset catalog that lists every legacy size individually (20pt @2x/@3x, 29, 40, 60, 76, 83.5, etc.), Xcode will still accept it — but you don't need that anymore. The single-size catalog the template ships is the current best practice.

### Launch screen

iOS requires a launch screen; the template provides a minimal one via `Info.plist`:

```xml
<key>UILaunchScreen</key>
<dict/>
```

An empty `UILaunchScreen` dictionary gives you a blank, system-colored launch screen that adapts to light/dark — perfectly acceptable, and it dodges the legacy launch-storyboard requirement. To customize it, add keys inside that dict (e.g. `UIColorName` pointing at a color set, or `UIImageName`). Don't render real content here — the launch screen is a static placeholder shown *before* your SwiftUI hierarchy loads.

### Store assets (not in the binary)

App Store Connect also needs, per device family you support, at least one **screenshot** (e.g. 6.9" iPhone, 13" iPad, and Mac sizes) and a **1024×1024 store icon**. These are uploaded in App Store Connect, not bundled in the app. Generate screenshots from the simulator (**⌘S** captures one) or Xcode's screenshot tooling.

---

## Step 5 — Versioning: marketing version vs. build number

Two numbers travel with every build, and confusing them is the #1 cause of *"this build number has already been used"* upload rejections.

| Concept | Info.plist key | Template value | Who sees it | Rule |
| --- | --- | --- | --- | --- |
| **Marketing version** | `CFBundleShortVersionString` | `1.0.0` | Users, on the store | Semantic, e.g. `1.2.0`. Bump when you release user-facing changes. |
| **Build number** | `CFBundleVersion` | `1` | Apple / TestFlight | Must be **unique and increasing** *within a marketing version*. Bump every upload. |

In the template's [`App/Info.plist`](../../templates/Swift-SwiftUI/App/Info.plist):

```xml
<key>CFBundleShortVersionString</key>
<string>1.0.0</string>
<key>CFBundleVersion</key>
<string>1</string>
```

Practical workflow:

- Keep `CFBundleShortVersionString` = your public version (`1.0.0`).
- Increment `CFBundleVersion` on **every** archive you upload (`1`, `2`, `3`, …), even when the marketing version doesn't change. Many teams script this in CI (set `CFBundleVersion` to the CI run number or commit count). In Xcode you can also use **Agvtool** or the **Generic Versioning** build settings (`CURRENT_PROJECT_VERSION`, `MARKETING_VERSION`) and reference them as `$(CURRENT_PROJECT_VERSION)` / `$(MARKETING_VERSION)` in the plist for a single source of truth.

> When you submit a *new* marketing version, the build number can reset to `1` again — uniqueness is scoped per marketing version. But it's simpler to just keep build numbers monotonically increasing forever.

---

## Step 6 — Create the App Store Connect record

Before you can upload, an app record must exist so the binary has somewhere to land.

1. Sign in to [App Store Connect](https://appstoreconnect.apple.com) ▸ **Apps ▸ + ▸ New App**.
2. Fill in:
   - **Platforms** (iOS, macOS — match what your universal app ships),
   - **Name** (your store-facing app name, must be unique across the store),
   - **Primary language**,
   - **Bundle ID** — pick the one you registered in Step 2 (`net.mattas.fieldnotes`),
   - **SKU** — any internal string you choose (e.g. `fieldnotes-001`).
3. The record is now created in the **Prepare for Submission** state. You can fill in metadata (description, keywords, support URL, screenshots, age rating, pricing) now or after your first build uploads. TestFlight does **not** require the store metadata to be complete — you can start testing immediately after a build is processed.

---

## Step 7 — Archive the app

An **archive** is a release-configuration build packaged with its dSYMs (symbol files for crash symbolication). You can't upload a normal debug build.

### In Xcode

1. Select the **Any iOS Device (arm64)** destination (you cannot archive against a simulator).
2. Make sure the scheme's **Run/Archive** build configuration is **Release**.
3. **Product ▸ Archive.** When it finishes, the **Organizer** opens with your `.xcarchive`.

### From the command line

The template has no `.xcodeproj` (you generate one — see [docs/SETUP.md](../../templates/Swift-SwiftUI/docs/SETUP.md)); once you have a project or workspace, archiving is:

```bash
# 1) Build the archive (Release, device).
xcodebuild archive \
  -scheme Swift-SwiftUI \
  -destination 'generic/platform=iOS' \
  -archivePath build/Swift-SwiftUI.xcarchive \
  -configuration Release

# 2) Export a signed .ipa from the archive using an export options plist.
xcodebuild -exportArchive \
  -archivePath build/Swift-SwiftUI.xcarchive \
  -exportPath build/export \
  -exportOptionsPlist ExportOptions.plist
```

A minimal `ExportOptions.plist` for App Store distribution with automatic signing:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>app-store-connect</string>
    <key>teamID</key>
    <string>YOUR_TEAM_ID</string>
    <key>signingStyle</key>
    <string>automatic</string>
    <key>uploadSymbols</key>
    <true/>
</dict>
</plist>
```

> `method` values you'll encounter: `app-store-connect` (TestFlight/App Store), `release-testing` (ad-hoc, registered devices), `enterprise`, and `debugging` (development). For CI, switch `signingStyle` to `manual` and add `provisioningProfiles` mapping your bundle id to a profile name. We wire this into GitHub Actions in [Module 14 — CI/CD](14-cicd-github-actions.md).

---

## Step 8 — Upload and distribute via TestFlight

### Upload

- **From Xcode Organizer:** select the archive ▸ **Distribute App ▸ App Store Connect ▸ Upload.** Xcode validates, signs with a distribution profile, and uploads.
- **From the command line:** after `-exportArchive`, push the `.ipa` with:

  ```bash
  xcrun altool --upload-app -f build/export/Swift-SwiftUI.ipa \
    -t ios --apiKey "$KEY_ID" --apiIssuer "$ISSUER_ID"
  # or the newer:
  xcrun notarytool / xcrun stapler  # (macOS notarization, see below)
  ```

  The modern, recommended uploader is **`xcrun altool`** being superseded by App Store Connect API keys; many teams use **fastlane `pilot`/`deliver`** or **Transporter.app** instead.

After upload, App Store Connect **processes** the build (a few minutes to ~an hour): it re-signs, extracts symbols, runs automated checks, and computes export-compliance prompts.

### Distribute to testers

In App Store Connect ▸ your app ▸ **TestFlight**:

- **Internal testers** — up to 100 members of your team (anyone with an App Store Connect role on the app). They get builds **immediately**, with **no App Review**. This is your fast feedback loop.
- **External testers** — up to 10,000 people via email invite or a **public TestFlight link**. The *first* external build of each version requires a lightweight **Beta App Review** (usually faster and looser than full App Review). You also fill in **Test Information**: what to test, a feedback email, and beta app description.

Add a build to a group, supply the **export compliance** answer (most apps using only HTTPS/standard crypto qualify for the exemption), and testers receive it in the TestFlight app.

> **macOS note:** a Mac build distributed *outside* the App Store must be **notarized** (`xcrun notarytool submit` then `xcrun stapler staple`). TestFlight and App Store delivery for the Mac app handle this through the standard upload — but if you also ship a direct `.dmg`/`.app`, notarization is mandatory or Gatekeeper blocks it.

---

## Step 9 — Prepare for App Review

Full App Review (for the App Store, not internal TestFlight) checks technical *and* policy items. The four that trip people up most:

### Privacy nutrition labels

In App Store Connect ▸ **App Privacy**, you declare every category of data your app **collects** and how it's **used** (and whether it's linked to identity or used for tracking). This is a *self-report* and must be truthful — it's shown on your store page. The template app collects nothing by default; if you added analytics, networking that sends user content, or crash reporting, declare it. Be honest: mismatches are a common rejection and an FTC risk.

### Privacy manifest (`PrivacyInfo.xcprivacy`)

Apple now requires a **privacy manifest** for apps (and many third-party SDKs) that declares:

- the **data types** the app collects,
- **tracking domains**,
- and **reasons for using "required-reason" APIs** (e.g. `UserDefaults`, file timestamps, disk space, system boot time).

This matters for the template directly: it uses **`UserDefaults`** via [`Core/Storage/AppStorage+Keys.swift`](../../templates/Swift-SwiftUI/Core/Storage/AppStorage+Keys.swift) (`@AppStorage`), which is a *required-reason API*. So you should add a `PrivacyInfo.xcprivacy` resource to the app target declaring that reason. Create it via **File ▸ New ▸ File ▸ App Privacy** (or add the plist by hand):

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>NSPrivacyTracking</key>
    <false/>
    <key>NSPrivacyTrackingDomains</key>
    <array/>
    <key>NSPrivacyCollectedDataTypes</key>
    <array/>
    <key>NSPrivacyAccessedAPITypes</key>
    <array>
        <dict>
            <key>NSPrivacyAccessedAPIType</key>
            <string>NSPrivacyAccessedAPICategoryUserDefaults</string>
            <key>NSPrivacyAccessedAPITypeReasons</key>
            <array>
                <!-- "Access info from same app, per documentation." -->
                <string>CA92.1</string>
            </array>
        </dict>
    </array>
</dict>
</plist>
```

Add the file to the app target's **Copy Bundle Resources**. If you adopt any SDK, check that *it* ships its own privacy manifest — Apple aggregates them at submission.

### App Transport Security (ATS)

ATS forces secure (HTTPS, TLS 1.2+) connections by default. The template already sets the secure default in [`App/Info.plist`](../../templates/Swift-SwiftUI/App/Info.plist):

```xml
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsArbitraryLoads</key>
    <false/>
</dict>
```

Keep it `false`. If a specific backend genuinely can't do HTTPS (rare, and you should fix the backend), add a **scoped exception** under `NSExceptionDomains` for *that domain only* — never flip `NSAllowsArbitraryLoads` to `true` globally, which invites a review rejection and requires written justification. Since the template's `APIClient` talks to an `https://` base URL, you need no exceptions.

### Demo account & review notes

If any part of your app is behind a login or a paywall, App Review **must** be able to get in. In App Store Connect ▸ **App Review Information**:

- provide a working **demo account** username/password (or a way to bypass auth for review),
- add **notes** explaining anything non-obvious (how to trigger a feature, what hardware it needs, why a permission is requested),
- supply a **contact** in case the reviewer has questions.

Reviewers reject builds they can't fully exercise. A 30-second note often saves a multi-day rejection loop.

---

## Try it yourself

1. **Rebrand the bundle identifier.** Change `CFBundleIdentifier` in `App/Info.plist` (and the target's `PRODUCT_BUNDLE_IDENTIFIER`) from `com.example.swiftswiftui` to a domain you control, then archive and confirm automatic signing registers the new explicit App ID.
2. **Drop in a real icon.** Export a 1024×1024 PNG (no alpha) and place it in the iOS universal slot of `Resources/Assets.xcassets/AppIcon.appiconset`. Build and verify the icon renders on a device and in Settings.
3. **Bump the build number and re-upload.** Increment `CFBundleVersion` to `2`, archive, and upload a second TestFlight build. Watch it appear alongside build `1` under the same marketing version.
4. **Author the privacy manifest.** Add a `PrivacyInfo.xcprivacy` declaring the `UserDefaults` required-reason API (the template uses `@AppStorage`), add it to the app target, and re-archive. Confirm the archive's validation passes.
5. **Script an export.** Write an `ExportOptions.plist` and run `xcodebuild -exportArchive` to produce a signed `.ipa` from a local archive — the same two commands CI will run in the next module.

---

## Recap

- A paid **Apple Developer Program** membership unlocks distribution; set the account up in Xcode and assign roles in App Store Connect.
- The **bundle identifier** (`CFBundleIdentifier`, currently `com.example.swiftswiftui` — change it) maps to a registered **App ID**, which gates **capabilities** and the **entitlements** your signed binary may claim.
- **Code signing** ties the binary to a certificate scoped by a **provisioning profile**; **automatic** signing is the right default, **manual** signing is for teams and CI.
- The template's `Assets.xcassets` ships a modern **single-1024 app icon** (plus dark/tinted and macOS sizes) and an empty `UILaunchScreen`; supply your own 1024 art and store screenshots.
- **Marketing version** (`CFBundleShortVersionString`) is for users; **build number** (`CFBundleVersion`) must increase on every upload.
- **Archive** (Xcode or `xcodebuild archive` + `-exportArchive`), then **upload** and ship through **TestFlight** — internal testers instantly, external testers after a Beta App Review.
- App Review readiness = honest **privacy labels**, a **`PrivacyInfo.xcprivacy`** (the template needs one for `UserDefaults`), **secure ATS** (already set), and a **demo account** plus review notes.

**Next:** [Module 14 — CI/CD: Extending the Pipeline](14-cicd-github-actions.md)
