# UX Roadmap: ADHD-Friendly Improvements

This checklist captures UX decisions and improvements needed to fully deliver on the "worry-offloading" promise. Based on critical review from an ADHD user perspective.

---

## Priority Legend

- **P0**: Core to the promise — without this, the app doesn't work for target users
- **P1**: High impact — significantly reduces friction or anxiety
- **P2**: Quality of life — nice to have, improves experience
- **P3**: Future consideration — valuable but not urgent

---

## 1. Daily Flow Simplification

### P0: Remove Decision Gate at Day Start

- [ ] **Current**: "Do you want to work today?" requires commitment before seeing plan
- [ ] **Target**: Show today's plan immediately; "Not Today" is an option, not a gate
- [ ] **Why**: Asking for commitment before showing value creates friction

### P1: Show "Enough" Explicitly

- [ ] Add visible "enough" threshold on Flow tab (e.g., "4 hrs today")
- [ ] Show progress toward enough (e.g., "2/4 hrs done")
- [ ] Make it clear when enough is reached (celebration moment)

### P1: One-Tap Quick Capture

- [ ] Add widget for instant task/stone creation from home screen
- [ ] Add Siri shortcut: "Add meeting at 3pm"
- [ ] Add shake-to-add or notification quick action

---

## 2. Project Creation Simplification

### P1: Remove "Quick vs Strategic" Decision

- [ ] **Current**: User must choose between two project types upfront
- [ ] **Target**: Single "Add Project" flow that adapts
- [ ] **Option A**: Start simple, offer "Break this down with AI?" after creation
- [ ] **Option B**: Ask one question: "Is this a big project?" → route accordingly
- [ ] **Why**: Upfront categorization causes analysis paralysis

### P2: API Key Setup Flow

- [ ] **Current**: 5 taps deep to add OpenAI key
- [ ] **Target**: Prompt during first Strategic Project attempt with inline setup
- [ ] Add "Paste from clipboard" auto-detection
- [ ] Show clear value prop before asking for key

---

## 3. Focus Mode Improvements

### P0: Add Visible Timer

- [ ] **Current**: "Soft timer" with no visible countdown
- [ ] **Target**: Optional visible countdown (user can toggle)
- [ ] Show elapsed time at minimum
- [ ] Add gentle audio/haptic at milestones (25 min, 45 min)
- [ ] **Why**: ADHD users need external time awareness

### P1: Add "I Got Distracted" Button

- [ ] Quick tap to log distraction without leaving Focus Mode
- [ ] Optionally note what distracted (for pattern recognition)
- [ ] Gently prompt to refocus, don't shame

### P2: Interruption Recovery

- [ ] When app reopens after backgrounding, show "Resume [Project X]?"
- [ ] Remember what user was doing
- [ ] Reduce "where was I?" friction

---

## 4. Undo & Forgiveness

### P0: Extend Undo Window

- [ ] **Current**: 5-second undo toast
- [ ] **Target**: 15-30 second window minimum
- [ ] Alternative: Undo available in history for recent touches
- [ ] **Why**: ADHD processing delay means 5 seconds isn't enough

### P1: Easy Touch Deletion

- [ ] Swipe-to-delete on recent touches
- [ ] Bulk undo for "oops I tapped the wrong thing 3 times"

---

## 5. Onboarding & Discovery

### P1: Add Optional Onboarding Tour

- [ ] 3-5 screen walkthrough explaining Stone/Water metaphor
- [ ] Show one example day
- [ ] Explain "enough" concept upfront
- [ ] Make skippable but available from Settings

### P1: Surface Hidden Gestures

- [ ] Add visual hints for long-press actions
- [ ] Show "tip" cards occasionally ("Did you know you can...")
- [ ] Or: Add visible buttons alongside gesture shortcuts

### P2: Empty State Guidance

- [ ] When no projects exist, guide user to create first one
- [ ] When no stones exist, explain their importance
- [ ] Reduce "blank canvas paralysis"

---

## 6. Settings & Configuration

### P1: Flatten Settings Hierarchy

- [ ] **Current**: 3-4 levels deep for some settings
- [ ] **Target**: Maximum 2 levels
- [ ] Consider single scrollable preferences screen
- [ ] Group related settings visually, not navigationally

### P2: Quick Settings Access

- [ ] Add common settings to Flow tab header menu
- [ ] Daily goal, working hours adjustable without deep navigation

---

## 7. "Enough" Celebration & Life Mode

### P0: Celebrate "Enough" Moment

- [ ] **Current**: Work just... stops appearing
- [ ] **Target**: Active celebration screen when threshold crossed
- [ ] Show what was accomplished
- [ ] Show what's next (life activities)
- [ ] Make stopping feel like achievement, not abandonment

### P1: Life Mode Transition

- [ ] When work is done, switch UI focus to non-work
- [ ] Show scheduled habits prominently
- [ ] Hide work suggestions until tomorrow
- [ ] Consider different color scheme for "life mode"

---

## 8. Habits Feature (Planned)

### P1: Habits as First-Class Citizens

- [ ] Add Habit entity (title, frequency, preferred times)
- [ ] Auto-schedule into available slots (e.g., "Gym 3x/week")
- [ ] Show habits in Flow timeline like work sessions
- [ ] Track habit completion without guilt mechanics

### P2: Habit Flexibility

- [ ] "Not feeling Tuesday's gym" → Auto-reschedule to Wednesday
- [ ] Weekly check-in: "You've done 2/3 gym sessions. Protect Saturday?"
- [ ] Missed habits redistribute, don't accumulate guilt

---

## 9. Bad Day Handling

### P0: Rest Day Redistribution Messaging

- [ ] **Current**: Rest day may exist but redistribution unclear
- [ ] **Target**: Explicit "I've moved X hours to Tue/Wed"
- [ ] Show updated deadline feasibility after rest day
- [ ] Reassure: "All deadlines still safe"

### P1: Partial Bad Days

- [ ] Support "I can only do 2 hours today" adjustment
- [ ] Redistribute the difference
- [ ] Don't require full rest vs full work binary

### P2: Energy/Capacity Tracking

- [ ] Optional end-of-day check-in: "How do you feel?"
- [ ] Adjust tomorrow's "enough" based on energy patterns
- [ ] Learn user's sustainable pace over time

---

## 10. Accountability & Motivation (Carefully)

### P2: Optional Body Doubling

- [ ] Integration with Focusmate or similar
- [ ] Or: Simple "someone else is working now" indicator
- [ ] External presence helps ADHD focus

### P2: Optional Stakes

- [ ] Integration with Beeminder (money on the line)
- [ ] Or: Donate to charity-you-hate if goal missed
- [ ] Must be opt-in, never default

### P3: Gentle Notifications

- [ ] "You said you'd start at 2pm. It's 2pm." (opt-in)
- [ ] Follow-up nudge if not started in 10 min
- [ ] Easy snooze/dismiss, no guilt

---

## 11. Visual & Feedback Polish

### P2: Haptic Feedback

- [ ] Subtle haptic on touch logging
- [ ] Stronger haptic on "enough" reached
- [ ] Feedback for gestures (swipe, long-press)

### P2: Loading States

- [ ] Show loading indicator during AI calls
- [ ] Skeleton screens for slow data loads
- [ ] Never leave user wondering "is it working?"

### P3: Sound Design

- [ ] Optional completion sounds
- [ ] Focus Mode ambient option
- [ ] All audio opt-in, off by default

---

## 12. Trust & Transparency

### P1: Verifiable Math

- [ ] Tap deadline to see calculation breakdown
- [ ] "Why is this scheduled today?" explainer
- [ ] Available on demand, not always visible

### P2: Schedule Explanation

- [ ] "Why Project A before Project B?"
- [ ] Show priority logic when asked
- [ ] Build trust through transparency

---

## Implementation Phases

### Phase 1: Core Promise (P0 items)
1. Remove decision gate at day start
2. Add visible timer to Focus Mode
3. Extend undo window to 15+ seconds
4. Add "Enough" celebration moment
5. Rest day redistribution messaging

### Phase 2: Friction Reduction (P1 items)
1. Simplify project creation flow
2. Show progress toward "enough"
3. Add onboarding tour
4. Flatten settings hierarchy
5. "I got distracted" button
6. Life mode transition

### Phase 3: Habits & Polish (P1-P2 items)
1. Habits feature implementation
2. Quick capture (widget, Siri)
3. Haptic feedback
4. Verifiable math displays

### Phase 4: Advanced Features (P2-P3 items)
1. Body doubling / accountability options
2. Energy tracking
3. Partial bad day support
4. Sound design

---

## Decision Log

Track key UX decisions and their rationale here.

| Date | Decision | Rationale | Status |
|------|----------|-----------|--------|
| 2025-01-19 | Adopt "worry-offloading" as core value prop | ADHD users need anxiety reduction, not optimization | Active |
| 2025-01-19 | "Enough" as explicit daily target | External definition removes guilt about stopping | Active |
| 2025-01-19 | Bad days redistribute, don't accumulate | Prevents all-or-nothing spirals | Active |
| | | | |

---

## Success Metrics

How do we know these changes are working?

1. **Time to first action**: User starts working within 30 seconds of opening app
2. **Rest day usage**: Users take rest days without uninstalling afterward
3. **"Enough" respect**: Users stop when enough is reached (not 2 hours later)
4. **Return rate**: Users open app daily without prompting
5. **Completion feel**: Users report feeling "done" not "guilty" at day end

---

*Last updated: January 2025*
