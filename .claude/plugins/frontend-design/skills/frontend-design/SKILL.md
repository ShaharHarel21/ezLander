---
name: frontend-design
description: Create distinctive, production-grade frontend interfaces with high design quality. Use this skill when the user asks to build web components, pages, or applications. Generates creative, polished code that avoids generic AI aesthetics.
license: Complete terms in LICENSE.txt
---

This skill guides creation of distinctive, production-grade frontend interfaces that avoid generic "AI slop" aesthetics. Implement real working code with exceptional attention to aesthetic details and creative choices.

The user provides frontend requirements: a component, page, application, or interface to build. They may include context about the purpose, audience, or technical constraints.

## Design Thinking

Before coding, understand the context and commit to a BOLD aesthetic direction:
- **Purpose**: What problem does this interface solve? Who uses it?
- **Tone**: Pick an extreme: brutally minimal, maximalist chaos, retro-futuristic, organic/natural, luxury/refined, playful/toy-like, editorial/magazine, brutalist/raw, art deco/geometric, soft/pastel, industrial/utilitarian, etc. There are so many flavors to choose from. Use these for inspiration but design one that is true to the aesthetic direction.
- **Constraints**: Technical requirements (framework, performance, accessibility).
- **Differentiation**: What makes this UNFORGETTABLE? What's the one thing someone will remember?

**CRITICAL**: Choose a clear conceptual direction and execute it with precision. Bold maximalism and refined minimalism both work - the key is intentionality, not intensity.

Then implement working code (HTML/CSS/JS, React, Vue, etc.) that is:
- Production-grade and functional
- Visually striking and memorable
- Cohesive with a clear aesthetic point-of-view
- Meticulously refined in every detail

## Frontend Aesthetics Guidelines

Focus on:
- **Typography**: Choose fonts that are beautiful, unique, and interesting. Avoid generic fonts like Arial and Inter; opt instead for distinctive choices that elevate the frontend's aesthetics; unexpected, characterful font choices. Pair a distinctive display font with a refined body font.
- **Color & Theme**: Commit to a cohesive aesthetic. Use CSS variables for consistency. Dominant colors with sharp accents outperform timid, evenly-distributed palettes.
- **Motion**: Use animations for effects and micro-interactions. Prioritize CSS-only solutions for HTML. Use Motion library for React when available. Focus on high-impact moments: one well-orchestrated page load with staggered reveals (animation-delay) creates more delight than scattered micro-interactions. Use scroll-triggering and hover states that surprise.
- **Spatial Composition**: Unexpected layouts. Asymmetry. Overlap. Diagonal flow. Grid-breaking elements. Generous negative space OR controlled density.
- **Backgrounds & Visual Details**: Create atmosphere and depth rather than defaulting to solid colors. Add contextual effects and textures that match the overall aesthetic. Apply creative forms like gradient meshes, noise textures, geometric patterns, layered transparencies, dramatic shadows, decorative borders, custom cursors, and grain overlays.

NEVER use generic AI-generated aesthetics like overused font families (Inter, Roboto, Arial, system fonts), cliched color schemes (particularly purple gradients on white backgrounds), predictable layouts and component patterns, and cookie-cutter design that lacks context-specific character.

Interpret creatively and make unexpected choices that feel genuinely designed for the context. No design should be the same. Vary between light and dark themes, different fonts, different aesthetics. NEVER converge on common choices (Space Grotesk, for example) across generations.

**IMPORTANT**: Match implementation complexity to the aesthetic vision. Maximalist designs need elaborate code with extensive animations and effects. Minimalist or refined designs need restraint, precision, and careful attention to spacing, typography, and subtle details. Elegance comes from executing the vision well.

Remember: Claude is capable of extraordinary creative work. Don't hold back, show what can truly be created when thinking outside the box and committing fully to a distinctive vision.

## ezLander Project Context

ezLander is a macOS menu bar AI assistant for calendar and email management. The project has two frontend surfaces:

### 1. macOS App (SwiftUI)

The native app uses a warm, modern design system defined in `macos-app/EzLander/Theme.swift`:

**Color Palette:**
| Token | Hex | Usage |
|-------|-----|-------|
| `warmPrimary` | `#FF6B6B` | Coral — buttons, interactive elements, selected states |
| `warmAccent` | `#FFA94D` | Amber — secondary highlights, gradient endpoints |
| `warmHighlight` | `#FFD93D` | Yellow — badges, special elements |
| `warmSoft` | `#FFE8DE` | Peach — subtle backgrounds, hover states |
| `userBubble` | `#FF6B6B` | Coral — user chat message bubbles |
| `eventDot` | `#FF8C5C` | Orange — calendar event indicators |
| `proBadge` | `#FFC233` | Gold — Pro subscription badge |

**Gradient:** `warmGradient` — coral (`#FF6B6B`) to amber (`#FFA94D`), top-leading to bottom-trailing.

**Button Style:** `WarmGradientButtonStyle` — gradient background, white text, 8pt corner radius, 0.85 opacity on press.

**Component Patterns:**
- Spring animations: 0.25–0.32s response, 0.70–0.82 damping fraction
- Border radius: 8–18pt adaptive rounding
- Spacing: 8pt padding increments
- Popover size: 400×500 points
- Font sizes: headline, body, caption, caption2

**Architecture:** MVVM with `@ObservableObject` ViewModels and singleton services. Views live in `macos-app/EzLander/Views/`. Theme management via `ThemeManager.shared` (system/light/dark).

When modifying the macOS app:
- Extend the existing color tokens in `Theme.swift` rather than hardcoding colors
- Use `WarmGradientButtonStyle` for primary actions
- Follow the warm coral-amber palette — avoid introducing clashing hues
- Use SwiftUI spring animations with the established timing parameters
- Maintain the 400×500 popover constraint

### 2. Marketing Website (Next.js + Tailwind)

Located in `website/`. Built with Next.js 14, React 18, TypeScript, Tailwind CSS 3.4+, and Framer Motion 10.16+.

**Tailwind Config:** Custom colors defined in `website/tailwind.config.js` (blue primary, purple accent).

When modifying the website:
- Use Tailwind utility classes and extend the existing config for new tokens
- Use Framer Motion for page transitions and scroll-triggered animations
- Follow the design thinking principles above for any new pages or components
- Ensure the website aesthetic complements but is not identical to the app — the website should sell the experience while the app delivers it
