# Attractive: Educational Reframing Implementation Plan

**Date:** June 16, 2026  
**Project:** Attractive (iOS/iPadOS strange-attractor visualizer)  
**Owner:** Luke Steuber  
**Status:** Design phase (not code)

---

## Executive Summary

Transform Attractive from a passive ambient visualizer into an **explicit educational tool** that teaches the mathematics of strange attractors. The app will guide users from "what is chaos?" to Lyapunov exponents and fractal dimension, with each attractor serving as a concrete exemplar. The current architecture (AttractiveCore + minimal app UI) is sound; the reframing is primarily about layering learning content, interactive exploration, and mathematical transparency into the existing trajectory engine.

---

## Scope

### What Changes

1. **Equation transparency layer** — every attractor displays its ODE system (LaTeX-rendered), parameter meanings, and historical origin
2. **Interactive parameter tuning** — sliders for each constant with **live re-integration** (users drag σ and see the attractor reshape in real time)
3. **Numerics education** — choose integrator (Euler vs RK4), observe step-size artifacts, compare trajectories
4. **Observable chaos** — sensitive dependence (two nearby initial conditions diverging), Lyapunov exponent visualization, attractor dimension hints
5. **Guided curriculum** — progressive lessons anchored to specific attractors (e.g., "fixed points" via Thomas, "bifurcation" via Lorenz)
6. **Touch-native interaction** — tap to set initial conditions, pinch/rotate 3D space, long-press to inspect state vectors

### What Does Not Change

- The six starter attractors (Lorenz, Rössler, Aizawa, Thomas, Halvorsen, Chen) remain the core
- AttractiveCore stays pure Swift, no UI dependency
- Dark-mode aesthetic (ambient visuals are retained as a *view mode*, not the primary mode)
- Performance targets (30 fps on iPhone 12+, smooth trajectory at 60 fps when education UI is minimal)

### Acceptance Criteria (MVP)

- [ ] At least 3 attractors have full educational metadata (equation, parameters, origin, bifurcation markers)
- [ ] Parameter sliders re-integrate smoothly without perceptible lag (<16ms latency)
- [ ] Two integrators (Euler, RK4) can be swapped; visual difference is clear
- [ ] A "sensitive dependence" mode shows two trajectories with nearby initial conditions; divergence is obvious within 5–10 seconds
- [ ] A guided lesson ("Chaos in Lorenz") walks the user from fixed-point explanation to parameter sweep
- [ ] Touch interaction works: tap to move attractor, pinch to zoom, long-press shows state (x, y, z)
- [ ] No regressions in ambient rendering; dark mode still looks beautiful when education layer is hidden

---

## Four Educational Pillars & Design

### Pillar 1: Equation Transparency

**Goal:** Users see the actual mathematics — not as a scary blackbox, but as readable, inspectable, and *correct*.

#### What to Build

1. **LaTeX equation rendering**
   - Use **LatexKit** (Swift package, handles Markdown→LaTeX on iOS) or **MathJax in WebView** (lower maintenance, slower)
   - Recommendation: **MathJax in a transparent `WKWebView`** docked below the canvas or in a modal. MathJax is battle-tested, renders beautifully, and lets us reuse web educational materials.
   - Fallback: ASCII + metadata (e.g., "dx/dt = σ(y - x)" as Text + explanation) if performance is a blocker.

2. **Metadata per attractor**
   - Struct `EquationMetadata: Codable` containing:
     - Canonical form: `dx/dt = f(x, y, z; σ, ρ, β)` (as LaTeX string)
     - Parameter definitions: `σ = "Prandtl number (fluid viscosity ratio)"`; `ρ = "Rayleigh number (temperature ratio)"`; `β = "geometric factor"`
     - Origin story: "Lorenz (1963) simplified convection in the atmosphere; smallest system exhibiting chaos."
     - Physical units (e.g., "x, y, z: temperature perturbations [K], t: dimensionless time")
     - Suggested range for each parameter (e.g., `ρ ∈ [0, 400]` with bifurcation at `ρ ≈ 24.74`)
     - Known limit cycles & fixed points (e.g., at `ρ = 1`, all trajectories → origin; at `ρ = 24.74`, 2-attractor bifurcation)
   - Store as JSON in AttractiveCore; app hydrates into views.

3. **Presentation**
   - Tap a small info button (ℹ️) → bottom sheet or modal showing:
     - Large LaTeX equation (centered, readable)
     - English prose explanation (2–3 sentences)
     - Parameter table (name, current value, range, meaning)
     - Origin & context (1–2 lines)
   - Slide-over (iPad) vs bottom sheet (iPhone) for better UX.

#### Where It Lives

- **AttractiveCore:** Add `EquationMetadata` struct and extend `AttractorRegistry` to include metadata for each system.
- **App:** New `EquationInfoView` (SwiftUI) that displays metadata, wired to a tap gesture on a floating info button.

#### Sequencing

1. *Phase 1a:* Define `EquationMetadata` struct and hardcode metadata for Lorenz + Rössler (fastest wins; covers 2/6 systems).
2. *Phase 1b:* Build `MathJaxWebView` component (wraps WKWebView, renders LaTeX to PNG or HTML-based display).
3. *Phase 1c:* Add `EquationInfoView` modal + integrate into ContentView.
4. *Phase 2:* Extend metadata to Chen, Aizawa, Thomas, Halvorsen.

#### Risks & Mitigations

| Risk | Severity | Mitigation |
|------|----------|-----------|
| WKWebView latency (black flash on open) | High | Lazy-load webview; use MathJax's fast-render mode. Test on iPhone 12 minimum. |
| LaTeX rendering bugs (missing symbols) | Medium | Vet equations against published papers (e.g., Lorenz's original 1963 paper, Chen 2013). Use simple LaTeX subset (no custom macros). |
| Metadata bloat in AttractiveCore | Low | Keep metadata separate (JSON file loaded at app startup, not binary-compiled). |

---

### Pillar 2: Interactive Parameters

**Goal:** Users manipulate constants (σ, ρ, β) with sliders and **see the attractor reshape in real time**. This is the visceral "aha!" moment.

#### What to Build

1. **Parameter sliders**
   - SwiftUI `Slider` for each of p1, p2, p3, with:
     - Min/max bounds from `EquationMetadata`
     - Current value display (e.g., "σ = 10.5")
     - Optional bifurcation marker (e.g., "⚡ Bifurcation at ρ = 24.74")
   - Sliders in a collapsible side panel (iPad landscape) or bottom-dismissible sheet (iPhone).

2. **Live re-integration**
   - When user drags a slider, AttractiveEngine re-integrates with the new parameter *without* stopping the animation.
   - Key: `AttractiveEngine.regenerate(...)` already supports mid-flight config updates. But we need to **avoid stuttering**:
     - Only update config every ~50ms (coalesce slider events).
     - Keep the trail visible while re-integrating (don't flush `points`); append new points under the new parameter.
   - Acceptance: <16ms latency between slider change and visual attractor update (imperceptible to the eye).

3. **Bifurcation markers**
   - For Lorenz: mark `ρ = 1` (chaotic → fixed point), `ρ ≈ 24.74` (first bifurcation), `ρ ≈ 99.5` (chaos re-onset).
   - Render as faint vertical lines on the slider or as a legend below.
   - Tapping a marker snaps the parameter to that value (quick navigation for learners).

4. **Undo/reset**
   - Button to reset all parameters to defaults (restore registry values).
   - Optional: breadcrumb trail of recent parameter sets (limited history, e.g., last 5 configurations).

#### Where It Lives

- **AttractiveCore:** Add to `EquationMetadata`:
  ```swift
  struct ParameterMeta {
    name: String        // "σ (sigma)"
    value: Double       // current value
    min, max: Double    // slider bounds
    bifurcationPoints: [Double]  // e.g., [24.74, 99.5]
    hint: String        // "Prandtl number"
  }
  ```
- **App:** New `ParameterControlPanel` (SwiftUI, state-driven). Feeds into `AttractiveCanvas` → `AttractiveEngine`.

#### Sequencing

1. *Phase 2a:* Extend `AttractorConfig` with parameter metadata (min/max, hints).
2. *Phase 2b:* Build `ParameterControlPanel` UI component.
3. *Phase 2c:* Wire slider → `AttractiveEngine.config` updates; test re-integration latency.
4. *Phase 2d:* Add bifurcation markers + tap-to-snap behavior.

#### Risks & Mitigations

| Risk | Severity | Mitigation |
|------|----------|-----------|
| Slider events cause stutter/missed frames | **Critical** | Coalesce events (50ms debounce). Measure frame time; use Instruments (Core Animation tool). Test on iPhone 12 base model. |
| Numerical instability at boundary parameters | High | Clamp parameters to safe ranges; unit-test edge cases (ρ=0.1, ρ=400). Avoid division by zero in integrator. |
| Trail reuse causes garbage in canvas | Medium | Clear trail when user resets; keep a "new config" flag to purge old points. |

---

### Pillar 3: The Math Made Visible

**Goal:** Show the *machinery* of integration and chaos. Learners see how Runge–Kutta differs from Euler, how sensitive dependence emerges, and what Lyapunov exponents measure.

#### 3A: Integrator Choice (Euler vs RK4)

**What to Build:**

1. Add a **RK4 (4th-order Runge–Kutta) integrator** to AttractiveCore.
   - Implement alongside the existing Euler step in `AttractorConfig.step(...)`.
   - Use a new `enum IntegratorType { case euler, rk4 }` flag in `AttractiveConfig`.
   - RK4 overhead: ~4x more function evaluations, but negligible on modern phones (easy to measure).

2. **Visual comparison mode**
   - Two sub-windows on the canvas:
     - Left: Euler integration (labeled, faint tint—e.g., red overlay)
     - Right: RK4 integration (labeled, blue overlay)
   - Both start from the same initial condition; user can observe the *difference* in trajectory shape (RK4 is smoother, stays on the attractor longer before errors accumulate).
   - Or: single canvas, toggle between Euler/RK4 with a button. Less educational but simpler.

3. **Time-step effects**
   - Slider for `baseDt` (integration timestep, currently fixed at 0.005).
   - Users can watch the attractor *break* (explode or become noise) when `dt` is too large, or become overly smooth when `dt` is tiny.
   - Mark "stable range" (e.g., 0.001–0.01 for Lorenz).

#### 3B: Sensitive Dependence (Butterfly Effect)

**What to Build:**

1. **Dual-trajectory mode**
   - Engine renders two trajectories simultaneously, with initial conditions separated by a tiny ε (e.g., `x = 0.1` vs `x = 0.10001`).
   - Each trajectory is rendered in its own color (e.g., red and cyan), edge-to-edge.
   - As time progresses (real time: 5–10 seconds), the two curves diverge visibly.

2. **Divergence meter**
   - Show the Euclidean distance between the two current points on screen:
     - Distance(t=0) ≈ 0.00001 (barely visible)
     - Distance(t=300 steps) ≈ 10–20 (half the attractor span)
   - Graph as a line or bar (y-axis: distance; x-axis: time steps).
   - Include exponent: "Divergence rate ≈ 10x every N steps" (approximation of Lyapunov exponent).

3. **Initial condition picker**
   - Tap on the canvas to set the "primary" trajectory; second trajectory is auto-set to (x+ε, y, z).
   - Or: use the existing state-inspector UI to manually set (x, y, z) for trajectory 1, then (x+ε, y, z) for trajectory 2.

#### 3C: Lyapunov Exponent Visualization

**What to Build:**

1. **Numerical computation**
   - In `AttractiveEngine`, maintain a "shadow" trajectory offset by ε; compute the divergence rate every N steps.
   - Lyapunov exponent λ = (1/N) Σ log(divergence_rate_i).
   - Approximate λ in real time (update every 100 steps or so).

2. **Display**
   - On the HUD (heads-up display), show:
     - Current λ (e.g., "λ ≈ 0.89 bits/step" for Lorenz).
     - Interpretation: "λ > 0 → chaos; λ ≈ 0 → bifurcation boundary; λ < 0 → stable."
   - Color-code the value (red for high chaos, yellow for moderate, green for stable).
   - Graph λ vs time (optional: shows when system transitions from stable to chaotic).

3. **Known values reference**
   - In `EquationMetadata`, include a "canonical Lyapunov exponent" (e.g., Lorenz at default params: λ ≈ 0.906).
   - User's measured λ should be close (within measurement noise).

#### 3D: Fractal Dimension

**What to Build:**

1. **Box-counting dimension**
   - Divide the 2D projection into a grid of boxes; count how many boxes contain trail points.
   - Repeat for finer grids (half the box size, quarter size, etc.).
   - Fractal dimension D = log(count_ratio) / log(size_ratio).
   - Compute on-demand (expensive; only when user opens a "dimension inspector" tool).

2. **Display**
   - Show D as a single number (e.g., "D ≈ 2.06" for Lorenz attractor).
   - Interpretation: "D < 3 and D > 2 → strange attractor; D = 2 → a surface; D → integer means we're not on a fractal."
   - Compare to known values (include in `EquationMetadata`).

3. **Visual hint**
   - Optionally: color-code the trail by local density (hotter colors = more visited regions). This gives a *visual* sense of the fractal structure without computing D.

#### Where It Lives

- **AttractiveCore:**
  - `enum IntegratorType { case euler, rk4 }`
  - Implement RK4 step function
  - Add `Lyapunov` struct to track dual trajectory + divergence
  - Add `FractalDimension` struct for box-counting

- **App:**
  - `IntegratorPickerView` (radio buttons: Euler / RK4)
  - `SensitiveDepedenceMode` view (dual trajectories)
  - `LyapunovHUD` (real-time λ display)
  - `DimensionInspectorSheet` (modal with D computation + interpretation)

#### Sequencing

1. *Phase 3a:* Implement RK4 integrator in AttractiveCore. Test correctness against Lorenz paper.
2. *Phase 3b:* Build `IntegratorPickerView` + toggle between Euler/RK4 on canvas. Measure performance.
3. *Phase 3c:* Implement dual-trajectory engine + `SensitiveDepedenceMode`. Verify divergence is visible within 10 seconds.
4. *Phase 3d:* Add Lyapunov computation + `LyapunovHUD`. Validate λ values against literature.
5. *Phase 3e:* Implement box-counting dimension + `DimensionInspectorSheet`. Accept slower compute (it's on-demand).
6. *Phase 3f:* (Optional) Density coloring of trail for fractal visualization.

#### Risks & Mitigations

| Risk | Severity | Mitigation |
|------|----------|-----------|
| RK4 performance overhead too high | High | Measure: toggle Euler/RK4 with 1000s of points on iPhone 12. If frame time >16ms, optimize or move to background thread. |
| Lyapunov exponent compute unstable | Medium | Use long integration window (1000+ steps); filter noise with moving average. Validate against published values before shipping. |
| Fractal dimension box-counting is slow | Medium | Only compute on-demand (not real-time). Limit grid resolution (e.g., 32×32 or 64×64 boxes). Use background thread. |
| User misinterprets λ or D | Low | Add inline help text, link to definition. Use color coding (red = chaotic, green = stable). |

---

### Pillar 4: Guided Lessons & Progression

**Goal:** A *curriculum* path that takes users from "what is a dynamical system?" to "why are attractors strange?" Each lesson anchors to a specific attractor and uses the app as a virtual lab.

#### What to Build

1. **Lesson structure**
   - `Lesson: Codable` struct:
     ```swift
     struct Lesson {
       id: String                    // "chaos-in-lorenz"
       title: String                 // "Chaos in the Lorenz System"
       description: String           // multi-paragraph explanation
       attractorID: AttractorID      // which system to load
       initialParameters: AttractorConfig  // suggested defaults
       steps: [LessonStep]           // sequence of interactive steps
       objectives: [String]          // learning goals
     }
     
     struct LessonStep {
       title: String                 // "1. Observe the Fixed Point"
       instructions: String          // narrative + interactive directions
       highlightParameters: [String] // e.g., ["ρ"]
       targetValues: [Double]        // e.g., [1.0] (fixed-point regime)
       successCriteria: String       // "The attractor collapses to a single point."
       hint: String?                 // if user gets stuck
     }
     ```

2. **Curriculum outline** (sample; expand as needed)

   **Lesson 1: "What is a Dynamical System?"**
   - Attractor: Thomas (simplest visually)
   - Steps:
     1. Observe the attractor as a *path* (emphasize: continuous 3D curve)
     2. Tap a point → show (x, y, z) coordinates; explain "state vector"
     3. Pause the animation; tap again; resume → trajectory continues from your point
     4. Conclusion: "The system's future is determined by its current state."

   **Lesson 2: "Fixed Points & Equilibria"**
   - Attractor: Lorenz (ρ = 1, parameters set so system goes to origin)
   - Steps:
     1. Observe the trajectory spiral inward to a point
     2. Show that point's coordinates (origin, or one of the symmetric fixed points at high ρ)
     3. Measure: "Distance to fixed point = ... mm. Getting smaller? → stable."
     4. Adjust ρ to 28 → fixed point becomes unstable; trajectory spirals away

   **Lesson 3: "Bifurcations & Transitions"**
   - Attractor: Lorenz (sweep ρ from 0 → 400)
   - Steps:
     1. Start at ρ = 1 (fixed point stable)
     2. Slowly drag ρ slider → watch the fixed point become unstable around ρ ≈ 1.3
     3. Continue to ρ ≈ 24.74 (period-doubling bifurcation)
     4. Continue to ρ ≈ 99.5 (onset of chaos)
     5. Conclude: "One parameter controls the entire *qualitative behavior* of the system."

   **Lesson 4: "Sensitive Dependence (Butterfly Effect)"**
   - Attractor: Lorenz (ρ = 28, "two close trajectories" mode)
   - Steps:
     1. Tap point A; system computes trajectory from A and A+ε simultaneously
     2. Watch the two curves (red/cyan) travel closely for ~2 seconds
     3. Then visibly diverge; they're on different sides of the attractor loop
     4. Show divergence meter: "0.00001 → 20 in ~300 steps"
     5. Conclude: "Tiny differences grow exponentially. Weather predictions break down."

   **Lesson 5: "Lyapunov Exponents & Predictability"**
   - Attractor: Lorenz (ρ = 28)
   - Steps:
     1. Enable "Lyapunov HUD"
     2. Watch λ ≈ 0.906 stabilize over time
     3. Reduce ρ to 10 (stable) → λ → negative
     4. Increase to 200 (very chaotic) → λ increases
     5. Conclusion: "λ measures how fast errors grow. λ > 0 = chaos."

   **Lesson 6: "Strange Attractors & Fractals"**
   - Attractor: Rössler (ρ ~ default, accumulate a large trail)
   - Steps:
     1. Show the full attractor with thousands of points
     2. Compute box-counting dimension → D ≈ 2.1
     3. Zoom in on a section → self-similar structure
     4. Conclusion: "The attractor is a *fractal*: not a smooth curve, not a solid surface."

3. **Lesson UI**
   - Tab or NavigationStack in the app to access lessons.
   - Tapping a lesson:
     - Load attractor + parameters
     - Show full-screen lesson flow (narrative + canvas side-by-side or stacked)
     - Highlight relevant UI elements (e.g., ρ slider during "Bifurcations" lesson)
     - Next/back buttons to navigate steps
     - Checkmarks for completed steps

4. **Progress tracking**
   - `UserDefaults` to track which lessons are completed.
   - Optional: unlock new lessons based on prerequisites (e.g., "Lyapunov Exponents" only after "Bifurcations").

#### Where It Lives

- **AttractiveCore:**
  - `Lesson` and `LessonStep` Codable structs
  - `LessonRegistry` (static array of all lessons, loaded from JSON or hardcoded)

- **App:**
  - `LessonView` (displays a single lesson + step-by-step flow)
  - `LessonListView` (tab or sheet showing all available lessons + progress)
  - `LessonHighlightModifier` (visual highlight for relevant sliders/buttons during lesson)

#### Sequencing

1. *Phase 4a:* Define `Lesson` and `LessonStep` structures. Hardcode 2–3 lessons (Thomas, Lorenz fixed point, Bifurcations).
2. *Phase 4b:* Build `LessonListView` + `LessonView` UI components.
3. *Phase 4c:* Integrate lesson flow into main app (new tab or modal).
4. *Phase 4d:* Add progress tracking (UserDefaults).
5. *Phase 4e:* Expand to full 6-lesson curriculum.
6. *Phase 4f:* (Optional) Add prerequisites & unlock logic.

#### Risks & Mitigations

| Risk | Severity | Mitigation |
|------|----------|-----------|
| Lessons are boring or too technical | High | **Field-test with a real student** (or a non-CS friend). Get feedback on clarity; iterate. Include interactivity (tap, drag) in every step. |
| Lesson metadata bloat in bundle | Low | Keep lessons in separate JSON files (one per lesson) or a single JSON array. Load lazily. |
| User gets stuck mid-lesson | Medium | Provide hints (pop-up or always-visible). Show success criteria clearly. Add a "skip" button (don't block progress). |

---

### Pillar 5: Touch-Native Interaction

**Goal:** Tactile, intuitive controls that fit iOS. Users don't *read* instructions; they *touch* and *discover*.

#### What to Build

1. **Tap to set initial condition**
   - Long-press on the canvas → attractor resets to that point (x, y from 2D projection; z inferred from nearest 3D point on the attractor).
   - Visual feedback: small circle at tap location, then fade in the new trajectory.

2. **Pinch to zoom**
   - Standard pinch gesture on the canvas scales the zoom factor.
   - Binds to `AttractiveEngine.zoom`.

3. **Two-finger rotation** (optional, phase 2)
   - Two-finger twist rotates the 3D phase space around the vertical axis.
   - Binds to `AttractiveEngine.rotation`.

4. **Tap for state inspection**
   - Single tap (not long-press) → show a popover with (x, y, z) and time.
   - Swipe down to dismiss.

5. **Swipe for attractor picker** (alternative to modal)
   - Swipe up from the bottom → attractor list (or swipe left/right to cycle).
   - Simpler than the existing "tap to open sheet" UX; more discoverable.

6. **Accessibility**
   - All interactive gestures have an alternative: buttons in the control bar.
   - VoiceOver labels for every gesture.

#### Where It Lives

- **App:** Enhance `AttractiveCanvas` with `GestureRecognizer` modifiers:
  ```swift
  .onTapGesture(perform: showStateInspector)
  .onLongPressGesture(perform: setInitialCondition)
  .gesture(MagnificationGesture().onChanged(setZoom))
  .gesture(RotationGesture().onChanged(setRotation))
  ```

#### Sequencing

1. *Phase 5a:* Add long-press to set initial condition (quick win, ~2h).
2. *Phase 5b:* Add pinch zoom (reuses existing zoom slider logic).
3. *Phase 5c:* Add state inspector popover (single tap).
4. *Phase 5d:* (Optional) Two-finger rotation.
5. *Phase 5e:* Accessibility pass (VoiceOver labels).

#### Risks & Mitigations

| Risk | Severity | Mitigation |
|------|----------|-----------|
| Gesture conflicts (long-press + swipe) | Medium | Vet on real device. Use standard iOS gesture recognizer patterns. Document which gesture does what in onboarding. |
| Initial condition pick is unintuitive (which z?) | Low | Show a crosshair + preview of (x, y, z) before confirming. Allow manual z adjustment if user wants. |
| State inspector blocks the canvas | Low | Use a translucent popover, not a full modal. Auto-dismiss after 3 seconds or on swipe down. |

---

## Phased Implementation Sequence

### Phase 1: Foundation (Weeks 1–2)
**Goal:** Establish the educational information layer and equation transparency.

| Task | Effort | Dependencies | Owner |
|------|--------|--------------|-------|
| Define `EquationMetadata` struct | 2h | — | Core |
| Add metadata for Lorenz + Rössler | 3h | Metadata struct | Core |
| Build `MathJaxWebView` (LaTeX renderer) | 4h | — | App |
| Create `EquationInfoView` modal | 2h | MathJaxWebView | App |
| Integrate info button into ContentView | 1h | EquationInfoView | App |
| **Phase 1 subtotal** | **12h** | | |

### Phase 2: Interactive Parameters (Weeks 2–3)
**Goal:** Parameter sliders with live re-integration and bifurcation markers.

| Task | Effort | Dependencies | Owner |
|------|--------|--------------|-------|
| Extend `AttractorConfig` with parameter metadata | 2h | Phase 1 metadata | Core |
| Build `ParameterControlPanel` UI | 3h | Metadata extension | App |
| Wire slider → re-integration | 3h | ParameterControlPanel, Engine | App |
| Test latency (<16ms) | 2h | Slider wiring | QA |
| Add bifurcation markers + snap logic | 2h | Parameter metadata | App |
| Extend metadata to all 6 attractors | 4h | Phase 1 metadata struct | Core |
| **Phase 2 subtotal** | **16h** | | |

### Phase 3: Numerics & Chaos (Weeks 4–5)
**Goal:** Integrator choice, sensitive dependence, Lyapunov, fractal dimension.

| Task | Effort | Dependencies | Owner |
|------|--------|--------------|-------|
| Implement RK4 integrator | 4h | — | Core |
| Build `IntegratorPickerView` + toggle | 2h | RK4 implementation | App |
| Implement dual-trajectory engine | 3h | AttractiveEngine | Core |
| Build `SensitiveDepedenceMode` view | 3h | Dual-trajectory engine | App |
| Implement Lyapunov exponent tracking | 4h | Dual-trajectory engine | Core |
| Build `LyapunovHUD` display | 2h | Lyapunov tracking | App |
| Test Lyapunov values vs. literature | 2h | LyapunovHUD | QA |
| Implement box-counting fractal dimension | 4h | AttractiveEngine, geometry | Core |
| Build `DimensionInspectorSheet` | 2h | Box-counting dimension | App |
| **Phase 3 subtotal** | **26h** | | |

### Phase 4: Lessons & Curriculum (Weeks 5–6)
**Goal:** Structured learning paths anchored to attractors.

| Task | Effort | Dependencies | Owner |
|------|--------|--------------|-------|
| Define `Lesson` and `LessonStep` structures | 2h | — | Core |
| Implement lesson registry (6 lessons) | 6h | Lesson structures | Core |
| Build `LessonListView` + `LessonView` UI | 5h | Lesson structures | App |
| Implement lesson step-by-step flow | 3h | LessonView | App |
| Add progress tracking (UserDefaults) | 2h | LessonView | App |
| Create onboarding lesson (getting started) | 2h | Lesson structures | Content |
| Field-test with a non-technical user | 2h | Full app | UX |
| Iterate on lessons based on feedback | 3h | Field test results | Content |
| **Phase 4 subtotal** | **25h** | | |

### Phase 5: Touch Interaction & UX Polish (Weeks 6–7)
**Goal:** Tactile, discoverable controls; refinement and accessibility.

| Task | Effort | Dependencies | Owner |
|------|--------|--------------|-------|
| Add long-press to set initial condition | 2h | AttractiveCanvas | App |
| Add pinch zoom gesture | 1h | AttractiveCanvas | App |
| Add state inspector popover | 2h | AttractiveCanvas | App |
| Add two-finger rotation (optional) | 2h | AttractiveCanvas | App |
| Accessibility pass (VoiceOver, labels) | 3h | All UI | QA |
| Dark mode refinement (ensure it still looks great) | 2h | Visual polish | Design |
| Beta test on iPad (landscape layout) | 2h | All features | QA |
| **Phase 5 subtotal** | **14h** | | |

### Phase 6: Polish & Release (Week 7–8)
**Goal:** Performance optimization, bug fixes, App Store readiness.

| Task | Effort | Dependencies | Owner |
|------|--------|--------------|-------|
| Performance profiling (Instruments: Core Animation, Memory) | 3h | All features | QA |
| Optimize integrator (if frame drops) | 2h | Performance data | Core |
| Bug fixes & edge cases | 4h | All features | QA |
| Update README & in-app help text | 2h | All features | Content |
| Screenshots for App Store (6 variants) | 2h | Polish | Marketing |
| Create Release Notes | 1h | All changes | Marketing |
| Final QA on iOS 17+ (iPhone 12, 15, iPad) | 2h | All features | QA |
| **Phase 6 subtotal** | **16h** | | |

**Total estimate: ~109 hours of work (~6–8 weeks with one developer).**

---

## Architecture & Code Organization

### AttractiveCore (pure Swift)

#### New modules/files:

1. **`EquationMetadata.swift`**
   ```swift
   struct ParameterDefinition: Codable {
       let name: String          // "σ (sigma)"
       let meaning: String       // "Prandtl number"
       let min, max: Double
       let bifurcationPoints: [Double]?
   }
   
   struct EquationMetadata: Codable {
       let equation: String      // LaTeX: "dx/dt = \\sigma(y - x)"
       let parameters: [ParameterDefinition]
       let origin: String        // "Lorenz (1963): atmospheric convection model"
       let physicalUnits: String // "x, y, z: temperature perturbations [K]; t: dimensionless"
       let canonicalLyapunov: Double?
       let canonicalDimension: Double?
   }
   ```

2. **`IntegratorType.swift`**
   ```swift
   enum IntegratorType: Codable {
       case euler
       case rk4
   }
   
   // Extend AttractiveEngine or create IntegratorProtocol
   protocol DynamicalSystemIntegrator {
       func step(_ x: Double, _ y: Double, _ z: Double, dt: Double) -> (Double, Double, Double)
   }
   ```

3. **`LyapunovTracker.swift`**
   ```swift
   struct LyapunovTracker {
       var shadowX, shadowY, shadowZ: Double  // offset trajectory
       var exponent: Double = 0
       var sampleCount: Int = 0
       
       mutating func advance(_ x: Double, _ y: Double, _ z: Double,
                            config: AttractorConfig, dt: Double)
   }
   ```

4. **`FractalDimension.swift`**
   ```swift
   struct BoxCountingDimension {
       func compute(points: [CGPoint], gridResolution: Int = 32) -> Double
   }
   ```

5. **`Lesson.swift`**
   ```swift
   struct LessonStep: Codable {
       let title: String
       let instructions: String
       let highlightParameters: [String]?
       let targetValues: [Double]?
       let successCriteria: String
       let hint: String?
   }
   
   struct Lesson: Codable, Identifiable {
       let id: String
       let title: String
       let description: String
       let attractorID: AttractorID
       let initialConfig: AttractorConfig
       let steps: [LessonStep]
       let objectives: [String]
   }
   
   enum LessonRegistry {
       static let allLessons: [Lesson] = [ ... ]
   }
   ```

6. **Extend existing:**
   - `AttractorConfig`: add `metadata: EquationMetadata?` field; extend registry
   - `AttractiveEngine`: add dual-trajectory tracking, Lyapunov computation, fractal dimension field

### App Layer (SwiftUI)

#### New views/files:

1. **`MathJaxWebView.swift`**
   - Wraps `WKWebView` to render LaTeX strings to images or HTML.

2. **`EquationInfoView.swift`**
   - Modal showing equation, parameters, origin, bifurcation hints.

3. **`ParameterControlPanel.swift`**
   - Sliders for p1, p2, p3; bifurcation markers; reset button.

4. **`IntegratorPickerView.swift`**
   - Radio buttons (Euler / RK4); optional side-by-side comparison.

5. **`SensitiveDepedenceMode.swift`**
   - Dual-trajectory canvas + divergence meter.

6. **`LyapunovHUD.swift`**
   - Real-time λ display; color-coded interpretation.

7. **`DimensionInspectorSheet.swift`**
   - Modal to compute and display fractal dimension.

8. **`LessonListView.swift`**
   - Tab or sheet showing all lessons; progress tracking.

9. **`LessonView.swift`**
   - Full-screen lesson flow; step-by-step guidance.

10. **Extend existing:**
    - `AttractiveCanvas`: add gesture recognizers (long-press, pinch, tap)
    - `ContentView`: add tabs for "Visualize" vs. "Learn"; integrate info button

---

## Critical Technical Risks & Mitigation

### Risk 1: Live Parameter Re-Integration Performance

**Problem:** Dragging a parameter slider triggers immediate re-integration (6–240 substeps). If coalescing is poor or the integrator is slow, the canvas stutters (sub-30fps).

**Severity:** Critical. This is the core interaction; it must feel *responsive*.

**Mitigation:**
- Implement event coalescing: only update config every 50ms (even if slider events fire at 120Hz).
- Profile on iPhone 12 (base model, not Pro) with Instruments (Core Animation tool).
- Measure: if frame time > 16ms, consider:
  - Reducing substeps per tick during parameter drag (e.g., 3 instead of 6).
  - Moving integration to a background thread (GCD, careful with data races).
  - Profiling the integrator itself (RK4 is slower; fallback to Euler during drag, switch to RK4 when released).

### Risk 2: LaTeX Rendering on iOS

**Problem:** MathJax in WKWebView is slow to load (black flash, 500ms–2s latency). Equations might fail to render (missing glyphs, malformed LaTeX).

**Severity:** High. Users expect instant, beautiful equations.

**Mitigation:**
- **Pre-render:** Generate equation PNGs at app build time (use a build script + MathJax CLI on the dev machine). Embed as `@2x` and `@3x` assets. Zero runtime latency.
- **Fallback:** If pre-rendering is not feasible, lazy-load the WebView (user taps info → WebView loads in background; show spinner; render equations when ready).
- **Validation:** Test all 6 equations on a real device before shipping. Vet LaTeX against original papers.

### Risk 3: Lyapunov Exponent Numerical Stability

**Problem:** Computing λ from a shadow trajectory is sensitive to integration errors, floating-point noise, and the choice of ε. Different ε values yield wildly different λ estimates.

**Severity:** High (correctness issue). If λ is visibly wrong, it breaks credibility.

**Mitigation:**
- Use a **well-established ε** (e.g., 1e-8 relative to attractor scale). Document this choice.
- **Smooth the exponent:** use a moving average (e.g., 50-step window) to reduce noise.
- **Validate against literature:** before shipping, compare measured λ to published values (e.g., Lorenz: λ ≈ 0.906 at ρ = 28, σ = 10, β = 2.667). Accept ±5% error.
- **Only compute during integration:** don't compute λ at the start (too noisy); require at least 500 steps before displaying a value.

### Risk 4: Fractal Dimension Box-Counting Complexity

**Problem:** Box-counting is O(n²) in the number of trail points and grid resolution. Computing dimension in real time (every frame) is infeasible. Off-screen computation (background thread) introduces synchronization complexity.

**Severity:** Medium. Dimension is nice-to-have, not critical for MVP.

**Mitigation:**
- Make it **on-demand only:** button to "compute dimension" opens a sheet; show a spinner; compute in background.
- **Limit trail size:** use the first 5000 points (or downsample) to speed computation.
- **Limit grid resolution:** start at 32×32 or 64×64 boxes; offer a "high-precision" toggle for 128×128 (slower).
- **Cache the result:** if the config hasn't changed, reuse the cached dimension (no re-compute).

### Risk 5: Lesson Engagement & Clarity

**Problem:** Educational content is easy to get wrong. Lessons might be too verbose, too technical, or not interactive enough. Users give up mid-lesson.

**Severity:** Medium (product/UX issue, not technical).

**Mitigation:**
- **Field-test with a non-technical user early** (weeks 3–4, after phase 2). Have them go through a draft lesson; observe where they get stuck.
- **Keep lessons short:** 3–5 steps, each <1 minute of interaction.
- **Emphasize discovery:** let users tap and drag; don't just lecture.
- **Provide hints:** every lesson step has a hint button. If user is stuck after 1 minute, hint is visible.
- **Add a "skip" button:** allow users to skip a step and proceed. Don't block progress.

---

## Acceptance Criteria (MVP)

For the app to ship as an "educational strange-attractor visualizer," the following must be true:

1. **Equation transparency** ✓
   - At least 3 attractors (Lorenz, Rössler, Thomas) display their equation, parameter meanings, and origin in a modal.
   - LaTeX equations are rendered correctly (tested on iPhone 12 + iPad).
   - No black flash or >1s latency when opening the info modal.

2. **Interactive parameters** ✓
   - Sliders for p1, p2, p3 are visible and draggable.
   - Parameter changes re-integrate the attractor visibly within 16ms (imperceptible to user).
   - At least one bifurcation marker is shown (e.g., Lorenz ρ ≈ 24.74).

3. **Integrator choice** ✓
   - User can toggle between Euler and RK4 integration.
   - Visual difference between Euler and RK4 is observable (Euler drifts, RK4 is smoother) after 30 seconds of integration.

4. **Sensitive dependence** ✓
   - "Two nearby trajectories" mode renders two curves starting from (x, y, z) and (x+ε, y, z).
   - Divergence is obvious within 5–10 seconds of integration.
   - Divergence meter shows distance growing (e.g., "0.00001 → 10").

5. **Lyapunov exponent** ✓
   - Real-time λ estimate is computed and displayed on HUD.
   - Measured λ for Lorenz (σ=10, ρ=28, β=2.667) is within ±5% of canonical λ ≈ 0.906.
   - Color coding (red=chaotic, green=stable) is correct.

6. **Lesson framework** ✓
   - At least one complete lesson (e.g., "Chaos in Lorenz") exists and is playable.
   - Lesson guides the user through 3–5 steps, each with success criteria.
   - Progress tracking persists across app launches.

7. **Touch interaction** ✓
   - Long-press on canvas resets trajectory to that point.
   - Pinch gesture zooms the attractor.
   - Single tap shows state (x, y, z) in a popover.
   - All interactions have accessibility labels for VoiceOver.

8. **No performance regressions** ✓
   - Ambient rendering (no education UI visible) still runs at 60 fps on iPhone 12.
   - With all education UI visible, frame rate ≥ 30 fps.

---

## Assumptions & Open Questions

### Assumptions

1. **Luke ships the app to the App Store** as a paid app ($4.99–$14.99) or free with IAP. Educational framing improves discoverability and justifies higher price.

2. **Target audience:** high school / early undergraduate students, curious adults, STEM educators. Not day-1 users (too technical); word-of-mouth + education blogs.

3. **Scope: six attractors only.** Adding new systems is easy (new `AttractorID` case + registry entry), but curriculum is built around these six. Future versions can extend.

4. **iPad is a secondary target** (support landscape, slides, bigger canvas). iPhone is primary.

5. **Offline app:** all lesson content, metadata, and math is bundled. No server calls.

6. **Accessibility is required:** WCAG 2.1 AA for color contrast, buttons, VoiceOver labels.

### Open Questions

1. **MathJax vs. pre-rendered images?**
   - Decision point: phase 1a. MathJax is flexible (scale equations dynamically); pre-rendering is faster. Recommend **pre-rendering for MVP** (speed), with **future MathJax upgrade** if equations need to be user-editable.

2. **How many lessons in MVP?**
   - Plan is 6 lessons (one per attractor). Phase 4 can reduce to 3–4 if time is tight.

3. **Lyapunov computation: real-time or on-demand?**
   - Plan is real-time (updated every frame). If that's too slow, make it on-demand (toggle, compute in background). Requires testing.

4. **Dual-trajectory: side-by-side sub-windows or single canvas with both curves?**
   - Plan is single canvas (cleaner, less clutter). If hard to distinguish, fallback to radio button toggle (show Euler, then RK4; not simultaneously).

5. **Lessons: built-in or served from a website?**
   - Plan is built-in (JSON embedded in app). Allows offline use; no server complexity.

6. **Are we committed to RK4, or is Euler-only acceptable for MVP?**
   - Plan is to ship both. If RK4 performance is a blocker, reduce to Euler + a note in the lesson ("this app uses Euler; more advanced integrators exist").

---

## Summary Table: Scope vs. Risk vs. Effort

| Pillar | Scope (MVP) | Risk | Effort | Mitigations |
|--------|-------------|------|--------|-------------|
| **Equation transparency** | 3–6 attractors with LaTeX, origin, parameters | Medium (rendering latency) | 12h | Pre-render equations; lazy-load webview |
| **Interactive parameters** | Sliders for all 3 parameters; bifurcation markers | Critical (performance) | 16h | Coalesce events; profile frame time; reduce substeps if needed |
| **Integrator choice** | Euler + RK4; visible difference | Medium (numerical stability) | 8h | Validate λ against literature; profile RK4 overhead |
| **Sensitive dependence** | Dual trajectory + divergence meter | Low | 8h | Ensure ε is appropriate; smooth divergence display |
| **Lyapunov exponent** | Real-time λ with color coding | High (numerical stability) | 6h | Use moving average; require 500+ steps before display; validate values |
| **Fractal dimension** | Box-counting on-demand | Medium (complexity) | 6h | Limit grid resolution; cache result; compute in background |
| **Lessons & curriculum** | 3–6 lessons (1 per attractor) | High (engagement/clarity) | 25h | Field-test early; keep steps short; emphasize discovery |
| **Touch interaction** | Long-press, pinch, tap | Low | 14h | Standard iOS patterns; test on device |
| **Polish & release** | Performance optimization, bug fixes, App Store readiness | Medium | 16h | Profile with Instruments; comprehensive QA |
| | **TOTAL** | | ~109h | Plan phases; mitigate critical risks early |

---

## Next Steps

1. **Confirm scope & sequencing** with Luke (Luke reviews this plan; discuss trade-offs).
2. **Lock visual design** (colors, layout, gesture affordances).
3. **Build phase 1** (foundation: metadata, LaTeX rendering, info modal).
4. **Prototype parameter slider interaction** (critical path; measure latency early).
5. **Field-test lesson with a non-technical user** (week 3–4).
6. **Refine based on feedback** and iteratively ship.

---

## Appendices

### A. Attractor Metadata Examples

**Lorenz (1963):**
```
Equation: dx/dt = σ(y - x), dy/dt = x(ρ - z) - y, dz/dt = xy - βz
Parameters:
  σ (sigma) = Prandtl number (fluid viscosity); range [0.1, 30]; typical 10
  ρ (rho) = Rayleigh number (temperature); range [0, 400]; bifurcation at ~24.74
  β (beta) = geometric factor; range [0.1, 5]; typical 2.667
Origin: Lorenz (1963) simplified atmospheric convection model; smallest chaotic system (3 vars)
Physical units: x, y, z: temperature perturbations [K]; t: dimensionless time
Canonical Lyapunov (σ=10, ρ=28, β=2.667): λ ≈ 0.906
Canonical fractal dimension: D ≈ 2.05
```

**Rössler:**
```
Equation: dx/dt = -y - z, dy/dt = x + ay, dz/dt = b + z(x - c)
Parameters:
  a (p1) = coupling; range [0, 0.5]; typical 0.2
  b (p2) = forcing; range [0, 0.5]; typical 0.2
  c (p3) = feedback; range [0, 10]; typical 5.7
Origin: Rössler (1976) chemical oscillator; simpler than Lorenz; 2D attractor
Physical units: x, y, z: concentrations or abstract state; t: dimensionless time
Canonical Lyapunov (a=0.2, b=0.2, c=5.7): λ ≈ 0.07
Canonical fractal dimension: D ≈ 2.01
```

### B. Sample Lesson: "Chaos in Lorenz"

```json
{
  "id": "chaos-in-lorenz",
  "title": "Chaos in the Lorenz System",
  "description": "Discover how the smallest chaotic system exhibits sensitive dependence and learns the role of the Rayleigh number (ρ).",
  "attractorID": "lorenz",
  "initialConfig": {
    "id": "lorenz",
    "p1": 10,
    "p2": 28,
    "p3": 2.667,
    "scale": 8,
    "initPos": [0.1, 0, 0],
    "recommendedSpeed": 3.0,
    "recommendedZoom": 1.0
  },
  "steps": [
    {
      "title": "1. Observe the Attractor",
      "instructions": "Watch the trajectory draw a butterfly-like shape. This is the Lorenz attractor—a strange attractor with a fractal structure.",
      "successCriteria": "You see a clear loop-like 3D curve."
    },
    {
      "title": "2. Adjust the Rayleigh Number",
      "instructions": "Drag the ρ (rho) slider from 28 to 50. Watch how the attractor changes: the butterfly opens up, becomes more chaotic.",
      "highlightParameters": ["ρ"],
      "targetValues": [50],
      "successCriteria": "You see the attractor grow and become more spread out."
    },
    {
      "title": "3. Return to Chaos",
      "instructions": "Drag ρ back to 28. This is the classic chaotic regime (λ > 0).",
      "highlightParameters": ["ρ"],
      "targetValues": [28],
      "successCriteria": "You see the familiar butterfly shape again."
    },
    {
      "title": "4. Sensitive Dependence",
      "instructions": "Tap 'Sensitive Dependence' to enable dual-trajectory mode. You'll see two curves starting from nearly the same point. Watch them diverge.",
      "successCriteria": "Two curves visibly separate over 5–10 seconds."
    },
    {
      "title": "5. The Lyapunov Exponent",
      "instructions": "Look at the λ value on the HUD. It shows ~0.9 bits/step, meaning errors grow ~10× every 10 steps. This is chaos.",
      "successCriteria": "You understand that λ > 0 means 'chaotic' and λ < 0 means 'stable'."
    }
  ],
  "objectives": [
    "Recognize the Lorenz attractor shape.",
    "Understand that a single parameter (ρ) controls the system's behavior.",
    "Observe sensitive dependence (butterfly effect) firsthand.",
    "Interpret the Lyapunov exponent as a measure of chaos."
  ]
}
```

---

**End of Plan**

