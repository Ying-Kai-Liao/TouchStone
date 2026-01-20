# Daily Flow State Machine

The daily flow is designed around one principle: **"See the plan. Execute. Stop when enough."**

---

## State 0a: Day Preview

**What User Sees:**
```
Today: Monday, Jan 20
━━━━━━━━━━━━━━━━━━━━━━━

YOUR REALITY
• 10am Standup
• 3pm Client call
• 6 hrs free time available

PREVIEW
~5 hrs work · ~4 sessions
All deadlines safe ✓

[ Let's Go ]    [ Not Today ]
```

**Key Elements:**
- Stones (fixed events) shown immediately
- Preview shows estimated work shape (hours, session count)
- Deadline safety calculated upfront
- User knows roughly what they're committing to

**Philosophy**: See enough to decide, without full computation yet.

---

## State 0b: Plan Generated

**Trigger:** User taps "Let's Go"

**System:**
- Liquid Scheduler algorithm runs
- Sessions allocated around stones
- Full day plan generated and persisted
- DayPlan committed to database

**What User Sees:**
```
Today: Monday, Jan 20
━━━━━━━━━━━━━━━━━━━━━━━

YOUR DAY
9:00   Project Alpha (90 min)
10:30  ▧ Standup [Stone]
11:00  Project Beta (90 min)
12:30  ░ Lunch
13:30  Project Alpha (60 min)
15:00  ▧ Client call [Stone]
16:00  Project Beta (60 min)
17:00  ✓ ENOUGH

Deadlines: All safe ✓
```

**Key Elements:**
- Full timeline now visible with specific times
- Sessions assigned to specific projects
- "Enough" marker shows when work day ends
- Plan is now committed — this is today's contract

**Philosophy**: Commitment triggers generation. Once generated, this is the plan to trust.

---

## State 1: Working Day Active

**What User Sees:**
- Full timeline: stones, sessions, meals, breaks
- Current/next session highlighted
- Progress toward "enough" visible
- Quick-touch buttons on each session

**Interactions:**
- Tap session → Log touch (with generous Undo)
- Tap scope icon → Enter Focus Mode
- Sessions completed → Visual checkmark
- Approaching "enough" → Celebration building

---

## State 2: Touch Logged

**Trigger:** User taps to log work

**System:**
- Create TouchLog (project, timestamp, duration)
- Update progress toward "enough"
- Check if "enough" threshold crossed

**UI:**
- Toast: "Logged. [Undo]" (15+ second window)
- Progress bar/counter updates
- If enough reached → Transition to State 4

---

## State 3: Focus Mode (Optional)

**Entry:** User chooses to enter focused container

**What User Sees:**
- Project name + current goal
- Soft timer (~55 min) — informational, not pressuring
- Minimal UI, immersive environment
- "Done" and "Leave" buttons equally prominent

**Exit Options:**
- "Done" → Log touch, return to timeline
- "Leave" → Log touch (whatever duration), return to timeline
- Both are equally valid. No judgment.

---

## State 4: Enough Reached 🎉

**Trigger:** Daily "enough" threshold crossed

**What User Sees:**
```
━━━━━━━━━━━━━━━━━━━━━━━
🎉 WORK COMPLETE FOR TODAY
━━━━━━━━━━━━━━━━━━━━━━━

You accomplished:
• 4 focused sessions
• All deadlines still safe

YOUR TIME NOW:
🏋️ Gym (scheduled 6pm)
📖 Evening free

[ Done for Today ]
```

**Philosophy:**
- Active celebration, not passive absence of tasks
- Explicit permission to stop
- Show what's next (life stuff, not more work)
- This is a MOMENT, not just "no more items"

---

## State 5: Rest Day

**Entry:** User taps "Not Today" from State 0

**What User Sees:**
```
Taking today off.

I've redistributed your sessions:
• 1.5 hrs moved to Tuesday
• 1 hr moved to Wednesday

All deadlines: Still safe ✓

Take care of yourself.

[ Rest Today ]
```

**System:**
- Mark day as rest day
- Redistribute planned sessions across remaining days
- Recalculate deadline feasibility
- Communicate clearly: safe or adjusted

**Philosophy:**
- Zero guilt
- Automatic adaptation
- User knows the system absorbed it
- Permission granted explicitly

---

## State 6: Deadline Pressure Warning

**Trigger:** Pressure calculation shows risk

**What User Sees:**
```
⚠️ Heads up: Project X

Current pace puts deadline at risk.
Options:
• Add 1 hr/day this week → Back on track
• Extend deadline to Feb 3 → Comfortable pace
• Keep current plan → 75% feasibility

[ Adjust Plan ]  [ I'll Push Through ]
```

**Philosophy:**
- Inform, don't alarm
- Provide concrete options
- User chooses response
- No shame for being behind

---

## Transitions Summary

```
┌──────────────────┐
│ State 0a:        │
│ Day Preview      │
│ (stones + est.)  │
└────────┬─────────┘
         │
    ┌────┴────┐
    ▼         ▼
┌──────┐  ┌──────────────────┐
│Rest  │  │ [Let's Go]       │
│Day   │  │ ↓                │
│(S5)  │  │ State 0b:        │
└──────┘  │ Plan Generated   │
          │ (algorithm runs) │
          └────────┬─────────┘
                   │
                   ▼
          ┌──────────────┐
          │ State 1:     │
          │ Working Day  │
          └──────┬───────┘
                 │
            ┌────┴────┐
            ▼         ▼
       ┌────────┐ ┌────────┐
       │Touch   │ │Focus   │
       │Logged  │ │Mode    │
       │(S2)    │ │(S3)    │
       └───┬────┘ └───┬────┘
           │          │
           └────┬─────┘
                ▼
          ┌───────────┐
          │ Enough?   │
          └─────┬─────┘
            Yes │ No
            ▼   └──→ Back to S1
       ┌────────────┐
       │ Enough     │
       │ Reached 🎉 │
       │ (S4)       │
       └────────────┘
```

---

## Design Principles

1. **Plan is pre-made** — User never builds today's schedule
2. **"Enough" is a finish line** — Not a minimum, a real ending
3. **Rest is a valid state** — Not a failure mode
4. **Transitions are celebrated** — Reaching "enough" is a moment
5. **System adapts** — Bad days don't break everything
