# iPhone Duo layout, 13 November 2026

On the iPhone Duo's inner display (iOS 27.1 and later), the attractor and its
controls share a system `ArrangementView` split that follows the fold. Every
other device keeps the original layout. The code is in
[`Attractive/DuoLayout.swift`](../Attractive/DuoLayout.swift).

## What it does

- **Choosing the layout:** `detectsFold` asks the root view for
  `.division` reserved regions, inactive ones included. Only the Duo's inner
  display has one, so it alone gets the split. The outer display, other
  iPhones, iPads and iOS before 27.1 get the original full-screen canvas with
  the bottom control bar.
- **The split:** `ArrangementView` with `.arrangementViewStyle(.split)`. The
  primary pane holds the attractor and its telemetry overlay. The secondary
  pane holds Tune and Math on a segmented control (they were the Tune
  inspector and the Math sheet), the Fold to turn toggle, and Attractor,
  Learn, 2D/3D and Style. The system places the panes: side by side when the
  phone is folded like a book, attractor on top when it stands like a laptop,
  side by side when it's flat open in landscape. Nothing in the app picks the
  direction.
- **Fold clearance:** `foldClearance()` pads the control pane and the
  telemetry overlay away from an active fold that crosses them. Inside the
  panes the system already keeps content off the fold, so in practice it adds
  no padding.
- **Fold to turn:** off by default and stored per device (`duo.hingeTurnsView`).
  When on, `onHingeChange` turns the 3D view two degrees for every degree the
  hinge moves while `status == .partiallyOpen`. The turn adds to drag
  rotation. Apple's guidance is to use the hinge for effects, not layout, and
  this is the only thing the hinge drives.
- **Remembered panel:** the pane reopens on Tune or Math, whichever was used
  last (`duo.panel`).

## Simulator checks (Xcode 27.2, iOS 27.2, "Attractive Duo 20261113")

| Pose | Result | Screenshot |
|------|--------|------------|
| Partially Open, book | Side by side, controls on the trailing side, nothing on the fold | [duo-book-partially-open.jpg](iphone-duo-20261113/duo-book-partially-open.jpg) |
| Partially Open, laptop | Attractor on top, controls below | [duo-laptop-partially-open.jpg](iphone-duo-20261113/duo-laptop-partially-open.jpg) |
| Open (flat), Tune and Math | Side by side | [Tune](iphone-duo-20261113/duo-open-flat-tune.jpg), [Math](iphone-duo-20261113/duo-open-flat-math.jpg) |
| Closed (outer display) | Original layout | [duo-closed-outer.jpg](iphone-duo-20261113/duo-closed-outer.jpg) |
| iPhone 17 Pro, iPad Pro 11-inch (M5) | Original layout | [iPhone](iphone-duo-20261113/iphone-17-pro-unchanged.jpg), [iPad](iphone-duo-20261113/ipad-pro-11-unchanged.jpg) |

- **Hinge readings:** the app's `duo` log showed 0° when closed and 180° when
  flat. Device Hub's Partially Open button sets 133.8°. The status reads
  `.closed` below about 75°.
- **Angle updates:** the Open animation delivered partly-open updates from
  133.8° to 169.9°, which the toggle turns into about 72° of rotation.
- **Sheets:** the attractor picker opened centered across the fold, which is
  how Apple says sheets move.
- **Tests:** `swift test` in `AttractiveCore` passed 26 of 26. The app target
  has no tests.

Device Hub drives the poses by hand: `simctl` and `devicectl` have no hinge
command. Inner-display screenshots come from
`xcrun simctl io <udid> screenshot --display=LCD-1`.

## Limits and open items

- **Fold to turn not seen on screen:** under host load each inner screenshot
  took about 7 seconds, so no frames caught a slow angle drag. The hinge
  readings arrived, but the rotation itself hasn't been watched. Check it on
  the simulator or a phone.
- **Launch flash:** on a cold launch the original layout shows for about half
  a second, until the first reserved-region query reports the fold.
- **Blank equations (predates this change):** the LaTeX "System" lines in
  Math render blank on iOS 27.2. It's the same in the iPhone Math sheet on
  `main` at a477dfe.
- **Not checked:** VoiceOver order across the two panes. Reports say Apple's
  accessibility tools can't read Duo screens in Xcode, so this needs the
  phone.
- **3D camera reset:** switching between the split and the original layout
  (unfolding or closing) rebuilds the 3D view, so its camera angle resets.

## Rollback

Revert the merge commit. The change touches only the app target:
`DuoLayout.swift` (new), `ContentView.swift`, `ParameterPanel.swift`,
`EquationView.swift`, `PhaseSpaceView.swift` and `PhaseSpaceCoordinator.swift`.
There are no project, version or Core changes.
