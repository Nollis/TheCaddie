# The Caddie Product PRD

## Problem Statement

Golfers need fast, trustworthy help during a round without fiddling with a phone, interpreting yardage tables, or wondering whether a generic AI answer invented the advice. The previous prototype showed that round-aware caddie guidance is useful, but it also showed the risk of making a language model responsible for golf decisions: prompt drift, unwanted speech, connection concerns, quota issues, and recommendations that can feel ungrounded.

The Caddie should solve this by becoming a native iOS caddie companion where the app's deterministic golf engine owns the actual decision, and speech or AI layers only make the experience easier to use and understand.

## Solution

The Caddie will provide grounded shot guidance from structured course, player, shot, and round state. The app will calculate the recommendation locally: club, target, playing distance, risk note, confidence, and fallback guidance. The UI and future voice layers will consume the same recommendation packet.

The intended product arc is:

1. Build a reliable native caddie core that works without network, microphone, or model availability.
2. Add an intuitive on-course UI centered on current hole, distance, recommendation, and simple shot updates.
3. Add Apple Speech and AVSpeechSynthesizer for a native voice loop.
4. Add Apple Foundation Models as an optional explanation/personality layer, not as the decision maker.
5. Expand course intelligence, GPS round state, scoring, post-round analysis, and personalization once the core guidance loop is trusted.

The product should feel like a calm human caddie: short, specific, confident, and useful. It should not expose technical connection states, model status, prompt mechanics, or backend concepts to the golfer.

## User Stories

1. As a golfer, I want to see the current hole and distance quickly, so that I can make a shot decision without searching through the app.
2. As a golfer, I want the app to recommend a club, so that I do not have to mentally adjust for wind, lie, and my stock distances every shot.
3. As a golfer, I want the app to recommend a target, so that I know where to aim rather than only what club to hit.
4. As a golfer, I want a short reason for the recommendation, so that I trust the advice.
5. As a golfer, I want to know the smart miss, so that I avoid expensive mistakes.
6. As a golfer, I want the app to account for my club distances, so that recommendations match my game rather than tour averages.
7. As a golfer, I want the app to account for my strategy preference, so that I can play safe, normal, or aggressive golf intentionally.
8. As a golfer, I want the app to account for wind when available, so that the playing number is more realistic than raw GPS distance.
9. As a golfer, I want missing distance or lie to be shown clearly, so that the app does not fake certainty.
10. As a golfer, I want quick update buttons like Fairway, Rough, and Bunker, so that I can keep the round state current with one tap.
11. As a golfer, I want no "connect" or technical voice controls in the main experience, so that the app feels like a golf tool rather than a developer demo.
12. As a golfer, I want the app to work even when AI features are unavailable, so that I can rely on it on course.
13. As a golfer, I want voice interaction later, so that I can keep my phone away while walking or preparing to hit.
14. As a golfer, I want to ask "What should I hit here?", so that the app can explain the deterministic recommendation naturally.
15. As a golfer, I want to ask "Can I go for it?", so that the app can compare the aggressive play with the safer play.
16. As a golfer, I want the caddie voice to stay quiet unless I ask for help, so that it does not interrupt my round.
17. As a golfer, I want the caddie to avoid saying it is finding GPS position, connecting, or using tools, so that it feels like a real caddie.
18. As a golfer, I want the app to keep the current hole stable unless I intentionally change it or the evidence is strong, so that walking near another hole does not corrupt my round.
19. As a golfer, I want the app to support a simple score/shot history later, so that recommendations can understand where I am in the hole.
20. As a golfer, I want post-round feedback later, so that I can see where I lost shots and what to practice.
21. As a higher-handicap golfer, I want plain-language advice, so that I understand the safe play without golf jargon.
22. As a serious player, I want concise tactical advice, so that the app does not over-explain obvious choices.
23. As a user with an unsupported Apple Intelligence device or region, I want deterministic phrasing fallback, so that the app still works.
24. As a privacy-conscious user, I want the core recommendation to work locally, so that my round does not depend on sending every shot to a remote model.
25. As the product owner, I want one recommendation packet powering UI and voice, so that the product stays consistent across interaction modes.
26. As a developer, I want the golf engine tested in isolation, so that UI or voice changes cannot silently alter recommendation behavior.
27. As a developer, I want AI/provider integrations behind replaceable boundaries, so that the app can adapt to Apple availability or future provider changes.
28. As a developer, I want course and round state represented explicitly, so that missing data becomes a visible state instead of guessed behavior.

## Implementation Decisions

- The deterministic domain engine owns club selection, target selection, wind adjustment, hazard/risk interpretation, confidence, and recommendation status.
- The recommendation packet is the shared contract between domain logic, SwiftUI, deterministic spoken fallback, and future model phrasing.
- The current native core starts with tiny embedded sample data before importing or rebuilding a larger course bundle pipeline.
- The first UI is a focused caddie screen, not an inspector/debug surface.
- The first UI states are ready, no course loaded, missing context, and unavailable recommendation.
- The app should not expose connect/listening/model/provider concepts in the player-facing flow.
- Apple Speech, AVSpeechSynthesizer, and Foundation Models are future layers above the packet.
- Foundation Models may phrase, summarize, explain, or adapt tone, but must not independently decide club, target, hazard carry, wind adjustment, or strategy.
- A deterministic fallback response layer must always exist.
- The iOS app should be native SwiftUI and Swift-first.
- The domain package should remain independently testable from the iOS app shell.
- The app should be designed so real GPS, course detection, scoring, and post-round analysis can be added without changing the packet contract unnecessarily.

## Testing Decisions

- Tests should focus on external behavior: given course, player, shot, and round context, the engine returns the expected packet and status.
- Domain model tests should cover complete sample context, missing distance, missing lie, unknown hole, and no course loaded.
- Recommendation tests should cover normal recommendation, strategy differences, wind differences, missing context, no suitable club, and explicit unavailable statuses.
- Presentation tests should verify deterministic fallback text and view-state mapping without depending on SwiftUI rendering.
- UI logic should be tested through view-state and view-model behavior where possible; full simulator/UI tests can come after the Xcode target is generated and stable.
- Future voice tests should verify intent handling and response gating without requiring live microphone or model calls.
- AI phrasing tests should verify that model output cannot override deterministic packet decisions.

## Out of Scope

- OpenAI realtime/WebRTC implementation.
- Model-driven club or strategy decisions.
- Live voice loop in the first product slice.
- Foundation Models implementation before availability research and core packet stability.
- Full scoring/statistics system in the first product slice.
- Full multi-course publishing pipeline in the first product slice.
- Production GPS hole detection until the manual/sample guidance loop is reliable.
- Competition rules advice unless explicitly designed and legally reviewed later.

## Further Notes

This PRD is the product north star for The Caddie, while the current implementation plan covers the first native caddie core slice. The most important architectural principle is simple: the app knows the golf answer; AI may help say it better.

Current implementation state as of 2026-06-15:

- Native Swift package scaffold exists.
- Minimal domain models and sample round context exist.
- Deterministic recommendation packet and engine exist.
- Deterministic fallback text and view-state mapping exist.
- Minimal SwiftUI app shell source exists.
- Xcode project generation and simulator verification still need macOS/Xcode.
