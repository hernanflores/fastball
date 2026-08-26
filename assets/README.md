# FastBall icon assets

## App icon
`AppIcon.iconset/` — drop-in for `iconutil`. From the repo root:

```
iconutil -c icns assets/AppIcon.iconset -o FastBall/AppIcon.icns
```

Then in `Resources-Info.plist` add:
```xml
<key>CFBundleIconFile</key>
<string>AppIcon</string>
```

And in the Makefile's build recipe, after copying `Resources-Info.plist`, add:
```
@iconutil -c icns assets/AppIcon.iconset -o $(CONTENTS)/Resources/AppIcon.icns
```

## Menu bar icon
`MenuBar/MenuBarIcon.png` (18×18) + `MenuBarIcon@2x.png` (36×36) — template images (black shape, alpha-masked), so AppKit auto-tints them for light/dark menu bars.

Copy both into `FastBall/Resources/`, add them to the Makefile's resource-copy step, then swap the `"✎"` title in `StatusItemController.swift` for the image:

```swift
if let button = statusItem.button {
    let icon = NSImage(named: "MenuBarIcon")
    icon?.isTemplate = true
    button.image = icon
    button.imagePosition = .imageOnly
    // remove button.title = "✎"
    ...
}
```
(`NSImage(named:)` resolves `MenuBarIcon.png`/`@2x` automatically once both are in the app bundle's Resources.)
