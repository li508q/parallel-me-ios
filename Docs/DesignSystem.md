# Design System

ParallelMe on iPhone should feel quiet, private, and deliberate: less dashboard, more held conversation.

## Visual Direction

- Use large readable text, generous vertical rhythm, and restrained controls.
- Keep cards shallow and paper-like, but avoid nesting cards inside cards.
- Make the five voices visually distinct without turning the UI into a rainbow.
- Treat the scribe as a host layer: present, calm, and never louder than the user's own decision.

## Interaction Principles

- The first screen is the actual meeting start, not a marketing landing page.
- Questions use native segmented/card choices plus a free-text escape.
- Roundtable actions are explicit tools: continue, ask one voice, ask the table, and pair two voices.
- Settlement is editable. The user can overwrite the final language.
- Destructive paper actions require a native confirmation step.

## App Icon

The app icon lives in `App/ParallelMe/Assets.xcassets/AppIcon.appiconset`. It uses a dark ink field, a warm paper center, and five colored voice points so the installed iOS app carries the same private-paper and fixed-roundtable identity as the in-app design.

## Token Location

Design primitives live in `Sources/ParallelMeDesign/DesignTokens.swift`.
