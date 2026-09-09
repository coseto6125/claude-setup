# Motion Craft

Component-level motion: how one control feels under a finger or a cursor.

Boundary against `data/motion.csv`: that CSV holds 16 GSAP snippets for
page-level choreography, indexed by category (hover, scroll reveal, stagger,
page transition, parallax, skeleton) and by intensity tier. Query it with
`--domain gsap`. This file covers the layer beneath it, which is the physics and
the timing of a single component, and it stays framework-agnostic.

Sources: beUI motion guide, Fluid Functionalism. Endpoints in `local/sources.md`.

## Decide before you animate

Answer four questions. An animation that fails any of them is decoration.

1. **How often does this fire?** A repeated action feels almost instant.
   Expressive motion belongs to rare moments.
2. **What does the motion say?** It explains space, confirms input, shows
   state, or softens a change. Name which one.
3. **Which physics?** A spring for anything the user drags, presses, or can
   interrupt. An eased duration for everything else, per `local/anti-patterns.md`.
4. **What happens under reduced motion?** Design that state, do not delete the
   feedback.

## Durations and easing

`local/anti-patterns.md` § Motion is the authority: the 100/300/500 rule, the exit-at-75%
ratio, the per-direction easing defaults, the stagger cap, and the 80ms instant threshold.
Read it there. This file adds only what a duration table cannot express.

One number it does not carry: beUI puts a modal or drawer at 200-500ms, wider than the
300-500ms band, because a drawer that explains space may open faster than one that
interrupts. Treat 200ms as the floor for a surface the user summoned.

## Four motion tokens

Define these once per project and reference them everywhere. Named tokens keep
a codebase consistent in a way per-component numbers never do.

| Token | Applies to |
|---|---|
| `EASE_OUT` | Entrances and exits that respond at once, then settle |
| `EASE_IN_OUT` | An on-screen object moving between two positions |
| `SPRING_PRESS` | Fast weighted feedback on a pressable surface |
| `SPRING_LAYOUT` | Shared surfaces and indicators that keep spatial continuity |

Read the numeric constants off the reference implementation rather than
inventing them. Fetch `https://beui.dev/r/{slug}/raw` for a component whose feel
matches the target, and lift its spring configuration.

## Why a spring, not a duration

A duration animation cannot be interrupted honestly. Reverse a 300ms slide
halfway and it either snaps or replays. A spring carries its current velocity
into the new target, so an interrupted gesture stays continuous. Use a spring
wherever the user can change their mind mid-animation: drag, swipe, toggle,
press, an open panel the user closes again.

## Named interaction patterns

Reach for one of these by name instead of describing an effect.

| Pattern | What it does | Use when |
|---|---|---|
| Shared layout | One surface stays visible while its footprint changes | A trigger grows into its own panel, or an indicator slides between tabs |
| Morph | The old shape becomes the new shape, not a crossfade | Modal from a button; select panel unfolding out of its trigger |
| Proximity hover | Highlight tracks the cursor before it lands | Dense targets: docks, toolbars, menu rows |
| Magnetic | The control leans toward the cursor | One hero CTA, never a whole page of them |
| Press scale | Small scale down on press, spring back | Every button. This is the cheapest signal a page is built, not assembled |
| Font-weight transition | Weight shifts on hover or on active state | Text navigation where color alone is too weak |
| Content swap | Old content leaves faster than new arrives | Small view changes; keep travel to a few pixels |
| Stagger reveal | Children enter in sequence | A list arriving once, not on every scroll |

Order matters in shared layout and morph. Move the shape first, then bring in
its label. A label that travels with the box reads as a slide, not a morph.

## Progress states for AI product surfaces

An agent that searches, reads, thinks, then generates has four distinct states.
One spinner reports none of them, and the user cannot tell a working agent from
a hung one.

- **Thinking indicator**: the surface is busy and the wait is short. A pulse or
  a shimmer, no step names.
- **Thinking steps**: the wait is long enough that the user needs the reason.
  Name the current step, keep finished steps visible, do not fake progress the
  system cannot measure.
- Reserve a determinate progress bar for work with a real denominator. A bar
  that fills on a timer is a lie the user catches.

Fluid Functionalism ships both as components. See `local/sources.md`.

## Reduced motion is a designed state

`local/anti-patterns.md` § Motion states the requirement. This is the removal list it
implies: drop travel, parallax, large transforms, repeated scale, spring overshoot, and
autoplaying background motion. Keep opacity, color, and instant state changes, so the
feedback survives.

```tsx
const reduce = useReducedMotion();

const hidden = { opacity: 0, transform: reduce ? "none" : "translateY(8px)" };
const visible = { opacity: 1, transform: "translateY(0px)" };
```

Gate decorative hover motion behind pointer capability as well. On a touch device a hover
effect fires on tap and delays the real action.

## What to check before shipping motion

`local/anti-patterns.md` § Motion covers the property, the reduced-motion media query,
and the stagger cap. Two checks are specific to this layer:

- Interrupting an animation mid-flight leaves no broken state. Reverse it halfway and look.
- Focus order and focus rings survive the animation.
