# TouchStone Documentation

## Overview

TouchStone is a **worry-offloading system** for iOS. Instead of asking you to plan, prioritize, and optimize, TouchStone does the thinking for you — then tells you exactly what "enough" looks like today.

**The core promise**: Follow today's plan, and your future is safe. Stop carrying the mental load. Trust the system.

---

## Core Philosophy

### The Problem We Solve

Every morning, most people wake up with a storm of questions:
- "What should I do first?"
- "Am I behind? How behind?"
- "If I rest today, will I miss my deadline?"
- "What's actually urgent vs. what just feels urgent?"

These questions create **planning anxiety** — the exhausting mental work of figuring out what to do before you can actually do it.

TouchStone eliminates planning anxiety by answering all these questions for you, mathematically, before you even open the app.

### The "Enough" Philosophy

Most productivity systems implicitly say: "More is better. Optimize. Don't waste time."

TouchStone says: **There is a number called "enough." When you hit it, stop.**

- "Enough" is calculated from your deadlines, your projects, and your stated capacity
- "Enough" includes buffer for bad days and unexpected things
- When you hit "enough," the app tells you to stop — and means it
- Time after "enough" is for life: exercise, hobbies, rest, people

### The Stone & Water Metaphor

- **Stones** = Fixed, immovable events (meetings, appointments). Reality that cannot change.
- **Water** = Flexible work that flows around stones. Projects sized to fit available gaps.

The app "pours" your project work into available time slots, automatically, so you never have to decide "what fits here?"

### Trust the Plan

Each day, TouchStone presents a complete schedule:
- Work sessions allocated to fit your free time
- Breaks built in
- Deadlines accounted for with buffer
- "Enough" clearly marked

Your job is simple: **follow the plan.** Not re-plan it. Not second-guess it. Just execute.

If you follow today's plan, your deadlines are safe. The app did the math.

### Bad Days Are Survivable

When you can't work — sickness, emergency, just can't today — the system adapts:
1. No guilt, no shame messaging
2. Automatic redistribution across remaining days
3. Clear answer: "You're still on track" or "Here's the adjusted plan"

Rest days aren't failures. They're built into the model.

---

## Main Features

### 1. Flow Tab (Your Daily Plan)

The Flow tab answers the question: **"What does 'enough' look like today?"**

When you open the app, you see today's complete schedule — no decisions required.

**What You See:**
- **Today's Timeline**: Stones (fixed events) and work sessions in chronological order
- **"Enough" Marker**: Clear indication of when your work day is complete
- **Progress Toward Enough**: Visual sense of how much you've done vs. how much remains
- **Life Activities**: Habits and personal time shown alongside work

**Key Interactions:**
- **Quick Touch**: Tap a project to log work — fast and frictionless
- **Focus Mode**: Optional deep work container (~55 min) for concentrated sessions
- **Undo Support**: Mistakes are reversible with one tap
- **Rest Day Option**: Some days you can't work. The system adapts.

**The Goal**: Open the app, see exactly what to do, do it, stop when "enough" is reached.

### 2. Plan Tab (Project Setup)

This is where you tell TouchStone what you're working on. Once set up, the app handles the daily planning.

**Simple Projects**
- Quick creation: just a title and optional deadline
- Good for straightforward work that doesn't need decomposition
- The app tracks hours toward deadline automatically

**Strategic Projects** (AI-Powered)
- For complex work that benefits from structure
- AI breaks your goal into phases and sessions
- Each session is 60-90 minutes with a specific goal
- You don't have to figure out "what's the next step" — it's pre-planned

**Project Archetypes:**

| Archetype | Best For | Example |
|-----------|----------|---------|
| **LAB** | Creative/Research | "Design a new landing page" |
| **HUNT** | Administrative | "Organize tax documents" |
| **SPIRAL** | Learning | "Learn basic Spanish" |
| **BUILD** | Technical/Engineering | "Build user authentication" |

**Why This Matters**: Once a project is set up with sessions, you never have to think "what should I work on next?" The app knows. It schedules. You execute.

### 3. Calendar Tab

See your month at a glance. Understand where the pressure is. Add fixed events.

**Features:**
- **Month View**: All your stones visualized
- **Pressure Heatmap**: Color-coded days showing workload intensity
- **Add Stones**: Voice input or form — however is fastest for you
- **Day Detail**: Tap any day to see/edit what's scheduled

**Why This Matters**: The calendar shows you the landscape of your commitments. When you can see the whole picture, you stop worrying about "what am I forgetting?"

### 4. Me Tab (Your Stats)

A gentle mirror, not a scoreboard.

**What You See:**
- Hours this week vs. your goal
- Today's progress toward "enough"
- Active and completed projects
- Weekly rhythm visualization

**What You Don't See:**
- Judgmental metrics
- "You missed 3 days" guilt trips
- Comparison to others or past performance

**Why This Matters**: Stats should inform, not shame. You can see patterns without feeling evaluated.

### 5. Settings Tab

Customize TouchStone to fit your life.

**Schedule Settings:**
- Working Hours (default: 9 AM - 9 PM)
- Time Blocks/Rules (meals, personal time)

**Focus Settings:**
- Daily productive hours goal (default: 6 hours)
- Session length range (default: 45-90 minutes)
- Deadline buffer percentage (default: 20%)
- Break configuration (interval and duration)

**Appearance:**
- Mode: System/Light/Dark
- Theme colors: Sage, Ocean, Lavender, Coral, Gold, Slate

**AI Assistant:**
- OpenAI API key configuration (required for strategic projects)

---

## Detailed Feature Guides

### Managing Stones (Fixed Events)

Stones are the foundation of your schedule—they represent reality that cannot be changed.

**Creating Stones:**
1. From Calendar tab, tap the + button
2. Choose voice input or manual entry
3. Set title, start time, and end time
4. Choose recurrence pattern if needed:
   - One-time
   - Daily
   - Weekdays only
   - Weekends only
   - Weekly (specific day)
   - Custom

**Voice Input:**
- Tap the microphone icon
- Speak naturally: "Meeting from 10 to 11 AM tomorrow"
- The speech parser extracts time and details automatically
- Review and confirm before saving

**Editing Stones:**
- Tap any stone to open the edit sheet
- Modify title, times, or recurrence
- Delete stones you no longer need

### Working with Projects

**Creating a Simple Project:**
1. Go to Plan tab
2. Tap + to add a project
3. Choose "Simple Project"
4. Enter title and optionally set a deadline
5. Start logging work immediately

**Creating a Strategic Project:**
1. Go to Plan tab
2. Tap + to add a project
3. Choose "Strategic Project"
4. Describe your goal in detail
5. Wait for AI to analyze and classify
6. Review the suggested archetype and phases
7. Adjust phase allocations if needed
8. AI generates detailed sessions
9. Optionally refine with documents or chat

**Phase Allocations:**
- Each phase has a percentage of total project time
- Drag sliders to adjust (minimum 5%, maximum 80%)
- Other phases auto-redistribute remaining time
- Total always equals 100%

**Document Context:**
- Attach PDFs or text files to projects
- AI considers document content when refining plans
- Great for RFPs, specifications, or reference materials

### Using Focus Mode

Focus Mode helps you concentrate on a single session.

**Starting Focus:**
1. From Flow tab, tap a suggested session
2. Select "Start Focus"
3. A 55-minute timer begins
4. Work on the session goal
5. Pause if needed, resume when ready
6. Complete or cancel when done

**When Complete:**
- A TouchLog is automatically created
- Duration is rounded to approximate buckets
- Session is marked complete
- Next session becomes available

### Understanding Pressure & Feasibility

TouchStone calculates pressure for projects with deadlines.

**Feasibility Statuses:**

| Status | Pressure | What It Means |
|--------|----------|---------------|
| **Healthy** | ≤50% | Comfortable pace, plenty of buffer |
| **Tight** | 50-75% | Manageable but stay focused |
| **At Risk** | 75-90% | Pushing limits, minimize distractions |
| **Impossible** | >90% | Cannot make deadline at current pace |
| **Overdue** | Past deadline | Deadline passed with work remaining |

**Pressure Formula:**
```
Pressure = (Remaining Hours × 1.25 buffer) / Available Capacity
```

Available capacity accounts for stones and your daily productive hours goal.

### Mental Rules (Cognitive Constraints)

Each project phase has a mental rule—a cognitive constraint to guide your work:

- "Explore widely, no conclusions yet"
- "Write fast, don't edit"
- "Hermit mode: no new inputs, no editing worry, just produce"
- "No new research, only polish and perfect"

These rules help you stay in the right mindset for each phase of work.

### Duration Buckets

TouchStone uses approximate time tracking rather than precise minutes:

| Bucket | Time Range |
|--------|------------|
| ~30m | Less than 45 minutes |
| ~1h | 45-75 minutes |
| ~1.5h | 75-105 minutes |
| ~2h | 105-150 minutes |

This reduces cognitive load—you don't need to track exact minutes.

### Rules (Soft Blocks)

Rules are recurring time blocks for meals and personal time.

**Default Rules:**
- Lunch: 12:00 PM - 1:00 PM
- Dinner: 6:00 PM - 7:00 PM

**Customizing Rules:**
1. Go to Settings → Time Blocks
2. Add, edit, or remove rules
3. Rules appear in your Flow timeline
4. The scheduler respects rules when suggesting sessions

---

## How to Use TouchStone

### The Daily Practice

1. **Open the app** — See today's plan already made for you
2. **Glance at the timeline** — Know what "enough" looks like today
3. **Do the first thing** — Don't overthink. Just start.
4. **Tap to log** — Quick touch when you complete a session
5. **Stop when "enough" is reached** — The app says stop. Trust it.

### The Mindset Shift

**Old way**: "I need to figure out what to do, prioritize, plan my time..."

**TouchStone way**: "I open the app. It shows me the plan. I follow it."

The app does the planning. You do the doing. That's the division of labor.

### When You Can't Work

- **Tap "Rest Day"** — No guilt, no judgment
- **Trust redistribution** — The system recalculates automatically
- **Check "still safe?"** — The app tells you if deadlines are still okay
- **Take care of yourself** — That's the point

### Setting Up for Success

1. **Add your fixed events (Stones)** — Meetings, appointments, commitments
2. **Create projects with deadlines** — So the app can calculate pressure
3. **Set realistic capacity** — Default is 6 hours; adjust to your reality
4. **Use Strategic Projects for complex work** — Let AI break it into sessions
5. **Trust the system** — Stop re-planning what the app already planned

---

## Technical Details

### Data Storage

TouchStone uses SwiftData for local-first storage. All your data stays on your device.

### AI Integration

Strategic project planning requires an OpenAI API key:
1. Get a key from platform.openai.com
2. Enter it in Settings → AI Assistant
3. Key is stored securely in iOS Keychain

The app uses the gpt-4o-mini model for:
- Goal classification into archetypes
- Phase generation with mental rules
- Session creation with specific goals
- Plan refinement conversations

### Privacy

- All data stored locally on device
- API key stored in secure Keychain
- Only project descriptions sent to OpenAI (when using strategic planning)
- No analytics or tracking

---

## Keyboard Shortcuts & Gestures

- **Swipe left** on items to reveal delete action
- **Long press** on sessions for quick actions
- **Drag** items in edit mode to reorder
- **Tap** stones or projects to view/edit details

---

## Troubleshooting

**Sessions not appearing:**
- Confirm you selected "Work today"
- Check that working hours include current time
- Verify you have active projects

**AI not working:**
- Verify API key is entered in Settings
- Check internet connection
- Ensure OpenAI account has credits

**Pressure showing Impossible:**
- Review deadline—is it realistic?
- Check total estimated hours
- Consider reducing scope or extending deadline

**Focus timer issues:**
- Ensure app stays in foreground
- Check Do Not Disturb settings
- Timer pauses if app backgrounds

---

## Glossary

| Term | Definition |
|------|------------|
| **Stone** | A fixed, immovable event (meeting, appointment) |
| **Water** | Flexible project work that flows around stones |
| **Touch** | Logging work effort on a project |
| **Touch Log** | A record of work effort with timestamp and duration |
| **Phase** | A stage within a strategic project |
| **Session** | A 60-90 minute focused work block |
| **Mental Rule** | A cognitive constraint for a phase |
| **Archetype** | A project pattern (LAB, HUNT, SPIRAL, BUILD) |
| **Pressure** | The ratio of required pace to available capacity |
| **Feasibility** | Whether a deadline is achievable |
| **Rule** | A recurring soft block (meals, personal time) |
| **Backlog** | Daily productive capacity in hour blocks |
| **Liquid Scheduler** | Algorithm that fills free time with project work |

---

## Version History

TouchStone follows semantic versioning. Check the App Store for release notes.

---

## Support

For issues, feedback, or feature requests:
- Report issues at the project repository
- Include iOS version and app version
- Describe steps to reproduce any bugs

---

## The TouchStone Promise

When you use TouchStone as designed:

- **You stop asking "what should I do?"** — The app answered that.
- **You stop worrying about deadlines** — The math is done for you.
- **You stop feeling guilty about rest** — Rest days are built in.
- **You stop working past exhaustion** — "Enough" means enough.
- **You start trusting** — The plan works. Follow it.

---

*TouchStone: Stop planning. Start trusting.*
