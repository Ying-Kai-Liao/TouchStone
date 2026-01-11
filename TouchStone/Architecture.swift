import Foundation

// MARK: - TouchStone Architecture Overview
//
// Philosophy: "Acknowledging reality, not managing it"
//
// The app uses a Stone & Water metaphor:
// - STONE: Fixed, immovable events (meetings, appointments, commitments)
// - WATER: Flexible work that flows around stones (projects to touch)
//
// ┌─────────────────────────────────────────────────────────────┐
// │                      TODAY VIEW                              │
// │  ┌─────────────────────────────────────────────────────┐    │
// │  │  REALITY (Stones)                                    │    │
// │  │  ┌──────────┐  ┌──────────┐                         │    │
// │  │  │ 10:00 AM │  │ 2:00 PM  │     Evening is open     │    │
// │  │  │Team Sync │  │Client Cal│                         │    │
// │  │  └──────────┘  └──────────┘                         │    │
// │  └─────────────────────────────────────────────────────┘    │
// │                                                              │
// │  "The schedule is light. You have space to think."          │
// │                                                              │
// │  ┌─────────────────────────────────────────────────────┐    │
// │  │  THINGS WORTH TOUCHING (Water)                       │    │
// │  │  ┌────────────────────────────────────────────┐     │    │
// │  │  │ Q4 Strategy          [Touched once]        │     │    │
// │  │  │ Discovery Phase                            │     │    │
// │  │  └────────────────────────────────────────────┘     │    │
// │  └─────────────────────────────────────────────────────┘    │
// │                                                              │
// └─────────────────────────────────────────────────────────────┘
//
// MARK: - App State Flow
//
// ┌──────────────┐     ┌──────────────┐     ┌──────────────┐
// │  SwiftData   │────▶│  AppState    │────▶│    Views     │
// │  (Storage)   │     │  (Derived)   │     │  (Display)   │
// └──────────────┘     └──────────────┘     └──────────────┘
//        │                    │                    │
//        │              Computed from:            │
//        │              - Today's stones          │
//        │              - Active projects         │
//        │              - Touch counts            │
//        │              - Free time slots         │
//        │                    │                    │
//        ▼                    ▼                    ▼
// ┌──────────────────────────────────────────────────────────┐
// │                    USER ACTIONS                           │
// │  • Add stone event (fixed commitment)                    │
// │  • Create project (work to touch)                        │
// │  • Log touch (acknowledge work done)                     │
// │  • Start focus session (optional timer)                  │
// └──────────────────────────────────────────────────────────┘
//
// MARK: - Data Models
//
// StoneEvent: Fixed time blocks that cannot move
// - title, startTime, endTime, recurrence
// - These are "reality" - meetings, appointments, etc.
//
// Project: Long-running work to touch
// - title, currentPhase, softDeadline
// - No scheduling - just acknowledgment of effort
//
// TouchLog: Record of touching a project
// - timestamp, duration (approximate), note
// - Links to project
//
// FocusSession: Active focus timer (optional)
// - startTime, targetDuration, project
// - Creates TouchLog when completed
//
// MARK: - Stone & Water Algorithm
//
// 1. Collect today's StoneEvents → these are fixed
// 2. Calculate free time slots between stones
// 3. Show projects as "things worth touching" in free time
// 4. When user touches project → create TouchLog
// 5. No auto-scheduling, just gentle suggestions
//
// The key insight: Stones are reality, water flows around them.
// We don't try to optimize or schedule water - we just show
// what's available and let the user acknowledge their work.
