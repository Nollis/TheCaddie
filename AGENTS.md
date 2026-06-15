# The Caddie Agent Guide

The Caddie is a fresh start from the TrueCaddie prototype. Keep this repo clean, deterministic, and Swift-first.

## Product Direction

- The app is the caddie brain.
- Domain logic owns club, target, risk, wind adjustment, and strategy decisions.
- AI and speech layers may later phrase or explain grounded recommendations, but they must not independently choose golf advice.
- The recommendation packet is the shared contract for UI, deterministic spoken fallback, and future model phrasing.

## Working Rules

- Keep changes surgical and aligned with the current plan.
- Start with the Swift package/domain core before voice or Foundation Models.
- Do not import OpenAI realtime, WebRTC, quota handling, prompt-heavy caddie behavior, or connect/listening UI from the prototype.
- Prefer deterministic fallback behavior over model-dependent behavior.
- Use tests for feature-bearing domain work.
- If Swift or Xcode tooling is unavailable in the active environment, say exactly what could not be run.

## Current Plan

- Requirements: `docs/brainstorms/2026-06-15-native-caddie-core-requirements.md`
- Implementation plan: `docs/plans/2026-06-15-001-feature-native-caddie-core-plan.md`
