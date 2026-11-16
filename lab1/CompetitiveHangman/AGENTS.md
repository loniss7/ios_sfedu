# Project notes

- This repository contains a macOS Swift Playground for a console-only game.
- Keep the implementation compatible with a standard Xcode Playground and Foundation.
- Shared implementation belongs in `CompetitiveHangman.playground/Sources`; the page entry point and runnable self-checks belong in `Contents.swift`.
- Do not add an iOS application target, UI frameworks, package dependencies, or keyboard input.
- Keep the game engine free of direct console output. Emit `GameEvent` values and let observers handle presentation and statistics.
- The random generator must remain seedable so the sample session and checks are reproducible.
