# Module 11 — Design System, Theming & Accessibility

A real app needs more than working screens — it needs a *consistent* look and an
*inclusive* one. In this module you'll build a small design system on top of the
**Swift-SwiftUI** template: colors in the asset catalog (driven by the
`AccentColor` colorset that already ships in the template), a typography scale,
spacing constants, and reusable view modifiers and styles that extend the real
`Core/Extensions/View+Extensions.swift`. Then you'll make all of it adapt to
Dark Mode and Dynamic Type, and wire up the accessibility essentials —
VoiceOver labels, traits, grouping, contrast, and reduce-motion — so the app
works for everyone from day one.

Everything here is plain SwiftUI you add to the template. There's nothing to
install. Because CI typechecks the template's Swift sources against the SDK (see
[Module 14 — CI/CD](14-cicd-github-actions.md)), keeping these files compiling
keeps the `Swift-SwiftUI` matrix job green.

**What you'll learn**

- How to define semantic colors in `Assets.xcassets` with light/dark variants,
  building on the existing `AccentColor.colorset`
- How to centralize a typography scale and spacing constants into a `Theme`
- How to grow the real `View+Extensions.swift` with new modifiers like
  `primaryButtonStyle` alongside the existing `cardStyle()` and `.if`
- How to write a reusable `ViewModifier` and a `ButtonStyle`
- How to support Dark Mode and Dynamic Type without per-screen branching
- How to use SF Symbols as scalable, recolorable iconography
- The accessibility essentials: `accessibilityLabel` / `Hint` / `value`, traits,
  element grouping, VoiceOver testing, contrast, larger text, and reduce-motion

**Prerequisites**

- [Module 10 — Concurrency with Swift 6](10-concurrency-swift6.md). We assume you
  have the `Swift-SwiftUI` template building and are comfortable with `@Observable`
  models and Swift 6 strict concurrency.

---

## 1. Where a design system lives

A design system is just a handful of single-source-of-truth definitions plus the
reusable views that consume them. We'll keep design *values* together and design
*behavior* (modifiers/styles) in the existing extensions file:

```
templates/Swift-SwiftUI/
├── Core/
│   ├── DesignSystem/
│   │   ├── Theme.swift            ← typography + spacing + color accessors (new)
│   │   └── Color+Theme.swift      ← named asset-catalog colors (new)
│   └── Extensions/
│       └── View+Extensions.swift  ← extend the existing file (modifiers/styles)
└── Resources/
    └── Assets.xcassets/
        ├── AccentColor.colorset/  ← already in the template
        ├── BrandPrimary.colorset/ ← new
        ├── SurfaceCard.colorset/  ← new
        └── TextSecondary.colorset/← new
```

The template already ships an `AccentColor.colorset` with two appearances —
a light value and a brighter dark-mode value:

`templates/Swift-SwiftUI/Resources/Assets.xcassets/AccentColor.colorset/Contents.json`

```json
{
  "colors" : [
    {
      "color" : { "color-space" : "srgb", "components" :
        { "alpha" : "1.000", "red" : "0.039", "green" : "0.478", "blue" : "0.898" } },
      "idiom" : "universal"
    },
    {
      "appearances" : [ { "appearance" : "luminosity", "value" : "dark" } ],
      "color" : { "color-space" : "srgb", "components" :
        { "alpha" : "1.000", "red" : "0.231", "green" : "0.584", "blue" : "1.000" } },
      "idiom" : "universal"
    }
  ],
  "info" : { "author" : "xcode", "version" : 1 }
}
```

Notice the pattern: one entry with no `appearances` (the default/light value)
and a second entry tagged `"appearance": "dark"`. SwiftUI resolves the right one
automatically. We'll reuse exactly this shape for our own colors.

---

## 2. Add semantic color sets to the asset catalog

Don't scatter raw `Color(red:green:blue:)` calls through your views. Define
*semantic* colors — named for their role, not their hue — in the asset catalog so
each gets a free light/dark variant.

Create three new colorsets under
`templates/Swift-SwiftUI/Resources/Assets.xcassets/`. In Xcode this is
**right-click → New Color Set**; here are the `Contents.json` files so you can
add them directly and keep CI reproducible.

`Resources/Assets.xcassets/BrandPrimary.colorset/Contents.json`

```json
{
  "colors" : [
    {
      "color" : { "color-space" : "srgb", "components" :
        { "alpha" : "1.000", "red" : "0.039", "green" : "0.478", "blue" : "0.898" } },
      "idiom" : "universal"
    },
    {
      "appearances" : [ { "appearance" : "luminosity", "value" : "dark" } ],
      "color" : { "color-space" : "srgb", "components" :
        { "alpha" : "1.000", "red" : "0.231", "green" : "0.584", "blue" : "1.000" } },
      "idiom" : "universal"
    }
  ],
  "info" : { "author" : "xcode", "version" : 1 }
}
```

`Resources/Assets.xcassets/SurfaceCard.colorset/Contents.json`

```json
{
  "colors" : [
    {
      "color" : { "color-space" : "srgb", "components" :
        { "alpha" : "1.000", "red" : "1.000", "green" : "1.000", "blue" : "1.000" } },
      "idiom" : "universal"
    },
    {
      "appearances" : [ { "appearance" : "luminosity", "value" : "dark" } ],
      "color" : { "color-space" : "srgb", "components" :
        { "alpha" : "1.000", "red" : "0.110", "green" : "0.110", "blue" : "0.118" } },
      "idiom" : "universal"
    }
  ],
  "info" : { "author" : "xcode", "version" : 1 }
}
```

`Resources/Assets.xcassets/TextSecondary.colorset/Contents.json`

```json
{
  "colors" : [
    {
      "color" : { "color-space" : "srgb", "components" :
        { "alpha" : "1.000", "red" : "0.235", "green" : "0.235", "blue" : "0.263" } },
      "idiom" : "universal"
    },
    {
      "appearances" : [ { "appearance" : "luminosity", "value" : "dark" } ],
      "color" : { "color-space" : "srgb", "components" :
        { "alpha" : "1.000", "red" : "0.922", "green" : "0.922", "blue" : "0.961" } },
      "idiom" : "universal"
    }
  ],
  "info" : { "author" : "xcode", "version" : 1 }
}
```

> Tip: prefer Apple's system colors (`Color(.systemBackground)`,
> `Color.primary`, `Color.secondary`, `.tint`) wherever they fit — they're
> already adaptive and meet contrast guidance. Define your own colorsets only
> for brand-specific roles the system doesn't cover.

Now expose them to Swift with named accessors so a typo becomes a compile error
instead of a silent fallback to magenta.

`Core/DesignSystem/Color+Theme.swift`

```swift
//
//  Color+Theme.swift
//  Swift-SwiftUI
//
//  Semantic colors backed by named asset-catalog color sets.
//

import SwiftUI

extension Color {
    /// The app's accent/brand color (mirrors `AccentColor`, usable explicitly).
    static let brandPrimary = Color("BrandPrimary", bundle: .main)

    /// Background for grouped "card" content. Pairs with `cardStyle()`.
    static let surfaceCard = Color("SurfaceCard", bundle: .main)

    /// De-emphasized text (captions, metadata).
    static let textSecondary = Color("TextSecondary", bundle: .main)
}
```

---

## 3. Define a typography scale and spacing constants

Hard-coded `.font(.system(size: 17))` and `.padding(13)` are how UIs drift out of
alignment. Centralize them. SwiftUI's built-in text styles (`.title`, `.body`,
`.caption`, …) already scale with Dynamic Type, so build your scale *on top of*
them rather than fixed point sizes.

`Core/DesignSystem/Theme.swift`

```swift
//
//  Theme.swift
//  Swift-SwiftUI
//
//  Single source of truth for typography, spacing, and corner radii.
//

import SwiftUI

enum Theme {
    // MARK: Spacing (a 4-pt scale)

    enum Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
    }

    // MARK: Corner radius (matches the existing cardStyle radius of 12)

    enum Radius {
        static let small: CGFloat = 8
        static let card: CGFloat = 12
        static let large: CGFloat = 20
    }

    // MARK: Typography
    //
    // These resolve to Dynamic Type text styles so they grow with the user's
    // preferred content size. `.rounded` gives the app a consistent voice.

    enum Typography {
        static let screenTitle = Font.system(.largeTitle, design: .rounded).weight(.bold)
        static let sectionTitle = Font.system(.title2, design: .rounded).weight(.semibold)
        static let body = Font.system(.body, design: .rounded)
        static let caption = Font.system(.caption, design: .rounded)
    }
}
```

Now `Theme.Spacing.md` reads better than a bare `16`, and changing the app's
spacing rhythm or font voice is a one-line edit.

---

## 4. Grow `View+Extensions.swift` with reusable modifiers

The template's `Core/Extensions/View+Extensions.swift` already ships
`cardStyle()`, the conditional `.if`, and `redactedWhileLoading(_:)`. We'll
extend the *same file* so design behavior stays in one place.

First, refactor `cardStyle()` to use the design tokens and the new surface color
(the body keeps the existing radius and shadow, just sourced from `Theme`):

```swift
extension View {
    /// Applies a standard "card" appearance: padded, rounded background with a
    /// subtle shadow. Use for grouped content blocks.
    func cardStyle() -> some View {
        self
            .padding(Theme.Spacing.md)
            .background(
                Color.surfaceCard,
                in: RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                    .strokeBorder(.quaternary, lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.08), radius: 6, y: 2)
    }
}
```

Then add a `ViewModifier` for section headers, and a convenience modifier that
applies it. A `ViewModifier` is the right tool when the styling involves more
than a chained call or needs its own state/environment:

```swift
/// Styles a label as a section header within the design system.
struct SectionHeader: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(Theme.Typography.sectionTitle)
            .foregroundStyle(Color.brandPrimary)
            .padding(.bottom, Theme.Spacing.xs)
            // Headers should be announced as headings by VoiceOver.
            .accessibilityAddTraits(.isHeader)
    }
}

extension View {
    /// Marks this view as a design-system section header.
    func sectionHeaderStyle() -> some View {
        modifier(SectionHeader())
    }
}
```

---

## 5. Build a `ButtonStyle` for the primary action

Buttons are the most-repeated control in an app, so they deserve a dedicated
`ButtonStyle`. Unlike a `ViewModifier`, a `ButtonStyle` gets the
`configuration` — including `isPressed` — so it can react to touch. Add this to
`View+Extensions.swift` too:

```swift
/// The app's primary call-to-action button style: filled with the brand color,
/// rounded, with a subtle press effect and full Dynamic Type support.
struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    // Respect the user's motion preferences for the press animation.
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.Typography.body.weight(.semibold))
            .frame(maxWidth: .infinity)
            .padding(.vertical, Theme.Spacing.sm + Theme.Spacing.xs)
            .padding(.horizontal, Theme.Spacing.md)
            .foregroundStyle(.white)
            .background(
                Color.brandPrimary.opacity(isEnabled ? 1 : 0.4),
                in: RoundedRectangle(cornerRadius: Theme.Radius.small, style: .continuous)
            )
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.97 : 1)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.12),
                       value: configuration.isPressed)
            .contentShape(Rectangle())
    }
}

extension View {
    /// Applies the primary call-to-action button style. Apply to a `Button`.
    func primaryButtonStyle() -> some View {
        buttonStyle(PrimaryButtonStyle())
    }
}
```

Use it anywhere a `Button` appears:

```swift
Button("Save Changes") { await model.save() }
    .primaryButtonStyle()
```

Two accessibility wins are baked in already: the style reads
`@Environment(\.isEnabled)` so a disabled button looks disabled, and it reads
`accessibilityReduceMotion` so it skips the press animation when the user has
asked the system to reduce motion.

---

## 6. SF Symbols for scalable iconography

SF Symbols are vector icons that ship with the OS, align to the text baseline,
recolor with `foregroundStyle`, and — crucially — scale with Dynamic Type when
used in a label. Always pair an icon with a label, and always give a meaningful
accessibility label.

```swift
Label("Favorites", systemImage: "star.fill")
    .font(Theme.Typography.body)
    .foregroundStyle(Color.brandPrimary)
    .symbolRenderingMode(.hierarchical)   // depth without extra assets
```

For an icon-only button — where the visible label is gone — you *must* supply a
spoken label:

```swift
Button {
    model.toggleFavorite()
} label: {
    Image(systemName: model.isFavorite ? "star.fill" : "star")
        .imageScale(.large)
}
.accessibilityLabel(model.isFavorite ? "Remove from favorites" : "Add to favorites")
```

---

## 7. Dark Mode and Dynamic Type, end to end

Because every color came from the asset catalog with a dark variant, and every
font came from a Dynamic Type text style, Dark Mode and larger text *already
work*. The job now is to verify, not to special-case.

Wrap content in containers that reflow rather than truncate. Avoid fixed
heights on anything that holds text:

```swift
struct ProfileCard: View {
    let name: String
    let bio: String

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text(name)
                .font(Theme.Typography.sectionTitle)
            Text(bio)
                .font(Theme.Typography.body)
                .foregroundStyle(Color.textSecondary)
                .fixedSize(horizontal: false, vertical: true) // wrap, don't clip
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }
}
```

Preview every combination so regressions surface at design time:

```swift
#Preview("Light") {
    ProfileCard(name: "Ada Lovelace", bio: "Mathematician and first programmer.")
        .padding()
}

#Preview("Dark") {
    ProfileCard(name: "Ada Lovelace", bio: "Mathematician and first programmer.")
        .padding()
        .preferredColorScheme(.dark)
}

#Preview("Accessibility XXXL") {
    ProfileCard(name: "Ada Lovelace", bio: "Mathematician and first programmer.")
        .padding()
        .environment(\.dynamicTypeSize, .accessibility5)
}
```

If a layout breaks at `.accessibility5`, switch a horizontal `HStack` to a
`ViewThatFits` or to a vertical stack at large sizes:

```swift
@Environment(\.dynamicTypeSize) private var dynamicTypeSize

var body: some View {
    let isLarge = dynamicTypeSize.isAccessibilitySize
    AnyLayout(isLarge ? VStackLayout(spacing: Theme.Spacing.sm)
                      : HStackLayout(spacing: Theme.Spacing.md)) {
        icon
        label
    }
}
```

---

## 8. Accessibility essentials

VoiceOver reads the *accessibility tree*, not your pixels. The defaults are good,
but composite views and custom controls need help.

**Labels, values, and hints.** A label says *what* an element is; a value says
its *current state*; a hint says *what happens* on activation:

```swift
Slider(value: $volume, in: 0...1)
    .accessibilityLabel("Volume")
    .accessibilityValue("\(Int(volume * 100)) percent")
    .accessibilityHint("Adjusts playback volume")
```

**Traits** tell VoiceOver how to treat an element — as a button, header, image,
selected item, etc.:

```swift
Text("Now Playing")
    .font(Theme.Typography.sectionTitle)
    .accessibilityAddTraits(.isHeader)   // already baked into sectionHeaderStyle()
```

**Grouping.** A card made of several `Text`s is announced as several separate
swipes by default. Combine them into one element with a single readable label:

```swift
VStack(alignment: .leading) {
    Text(track.title).font(Theme.Typography.body)
    Text(track.artist).font(Theme.Typography.caption)
        .foregroundStyle(Color.textSecondary)
}
.accessibilityElement(children: .combine)   // one swipe, "Title, Artist"
```

Use `.ignore` plus an explicit label when you want to fully control the spoken
text, and `.contain` for a container whose children should remain individually
navigable.

**Contrast.** Adaptive colors help, but verify. The `BrandPrimary` color must
have a contrast ratio of at least 4.5:1 against text placed on it (3:1 for large
text). Support **Increase Contrast** by bumping borders/weights when the
environment flag is set:

```swift
@Environment(\.colorSchemeContrast) private var contrast

var border: Color { contrast == .increased ? .primary : .quaternary }
```

**Larger text** is covered by §7 — just never cap a text view's size with a
fixed frame.

**Reduce motion.** We already read `accessibilityReduceMotion` in
`PrimaryButtonStyle`. Apply the same guard to any decorative animation:

```swift
@Environment(\.accessibilityReduceMotion) private var reduceMotion

withAnimation(reduceMotion ? nil : .spring) {
    isExpanded.toggle()
}
```

**Test with VoiceOver.** On a device or simulator, enable **Settings →
Accessibility → VoiceOver** (or triple-click the side button if you've set the
shortcut). Swipe right to move through elements and listen: every interactive
element should announce a clear label, its role, and — for stateful controls —
its value. In Xcode, the **Accessibility Inspector** (Xcode → Open Developer
Tool → Accessibility Inspector) lets you audit a running app and run an
automated audit that flags missing labels and contrast issues.

---

## Try it yourself

1. Add a `SurfaceElevated.colorset` (a slightly lighter card for modals) and a
   `Color.surfaceElevated` accessor, then make a `sheetCardStyle()` modifier that
   uses it.
2. Add a `secondaryButtonStyle()` (outlined, brand-colored text on a clear
   background) next to `PrimaryButtonStyle`, respecting `isEnabled` and
   `reduceMotion` the same way.
3. Take one feature screen and run it through all three previews from §7. Fix
   anything that truncates at `.accessibility5`.
4. Add `accessibilityElement(children: .combine)` and a spoken label to one
   composite row, then verify the change with the Accessibility Inspector's
   audit.
5. Add an `@Environment(\.colorSchemeContrast)`-driven border to `cardStyle()`
   so cards gain a stronger edge under Increase Contrast.

---

## Recap

- Semantic colors live in `Assets.xcassets` with light/dark variants, following
  the same two-appearance shape as the template's existing `AccentColor`, and are
  exposed through typed `Color` accessors so typos fail at compile time.
- A `Theme` enum centralizes spacing, corner radii, and a typography scale built
  on Dynamic Type text styles — change the rhythm or voice in one place.
- Design *behavior* extends the real `Core/Extensions/View+Extensions.swift`:
  `cardStyle()` now uses the tokens, a `SectionHeader` `ViewModifier` and a
  `PrimaryButtonStyle` `ButtonStyle` give you reusable, accessible building
  blocks.
- Dark Mode and Dynamic Type come for free when you source colors from the asset
  catalog and fonts from text styles; verify with multi-trait previews and
  `ViewThatFits`/`AnyLayout` for accessibility sizes.
- Accessibility essentials — labels, values, hints, traits, grouping, contrast,
  larger text, and reduce-motion — turn a working UI into an inclusive one.
  Test with VoiceOver and the Accessibility Inspector.

**Next:** [Module 12 — Platform Deep Dives](12-platform-deep-dives.md)
