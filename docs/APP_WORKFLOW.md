# TouchStone App Workflow

> **Acknowledge your reality. Let your work flow around it.**

TouchStone is a productivity app built on a simple philosophy: your time has two types of content—**Stones** (fixed events you can't move) and **Water** (flexible work that flows around them). Instead of fighting your calendar, TouchStone helps you work *with* it.

---

## Core Concepts

### Stones (Fixed Events)
Meetings, appointments, classes, commitments—things that happen at specific times and cannot be moved. These are your reality.

### Water (Flexible Work)
Projects and tasks that need attention but don't have fixed times. Water flows into the gaps between your stones.

### The Magic
When you add projects with deadlines, TouchStone calculates how much time you need to invest daily and automatically suggests work sessions that fit around your fixed commitments—no manual scheduling required.

---

## Getting Started

### Step 1: Set Up Your Stones
Before TouchStone can help you, it needs to know your reality.

1. Go to the **Flow** tab
2. Tap **+** to add fixed events:
   - Recurring meetings (daily standups, weekly syncs)
   - Classes or appointments
   - Personal commitments

*Future feature: Import your calendar automatically*

### Step 2: Configure Your Capacity
Tell TouchStone how many productive hours you have each day.

1. Go to the **Me** tab
2. Set your **Daily Productive Hours** (default: 6 hours)
3. Adjust meal times (Lunch, Dinner) if needed

### Step 3: Create Your First Project
This is where the magic happens.

---

## Creating Projects

### Option A: Simple Project
For straightforward work without complex planning.

1. Go to **Plan** tab → tap **+**
2. Choose **Simple Project**
3. Enter title, current phase, and deadline
4. TouchStone tracks your progress as you work

### Option B: Strategic Project (AI-Powered)
For complex goals that need structured planning.

1. Go to **Plan** tab → tap **+**
2. Choose **Strategic Project**
3. Describe your goal in plain language:
   > "Write a research paper on machine learning optimization techniques"

4. TouchStone's AI generates a complete plan:

```
Archetype: LAB (Creative/Research)

Phase 1: Research (Divergent)
├─ Session 1: Literature review (90 min)
├─ Session 2: Concept mapping (60 min)
└─ Mental Rule: "Explore widely, no conclusions yet"

Phase 2: Drafting (Execution)
├─ Session 1: Create outline (60 min)
├─ Session 2: Write first draft (90 min)
└─ Mental Rule: "Write fast, don't edit"

Phase 3: Refining (Convergent)
├─ Session 1: Review and rewrite (90 min)
├─ Session 2: Final formatting (60 min)
└─ Mental Rule: "No new research, only polish"

Total: 7.5 hours across 6 sessions
```

5. Review, customize if needed, and save
6. Set your deadline

---

## Daily Workflow

### Morning: Start Your Day

1. Open the **Flow** tab
2. See your day's timeline:
   - Stones (fixed events) locked in place
   - Suggested water (project sessions) in free slots
   - Meals marked at your configured times

3. Answer: **"Do you want to work today?"**
   - **"Let's go"** → Locks in your schedule
   - **"Rest"** → Shows only stones, no work suggestions

### During the Day: Touch Your Projects

When you work on a project:

1. Tap the session in your flow
2. Choose how to log your work:
   - **Quick Touch**: Log approximate time (~30m, ~1h, ~1.5h, ~2h)
   - **Focus Mode**: Start a 55-minute timer (optional)

3. Session marked complete → Next session suggested

### Real-Time Adaptation

**Add a new meeting?** TouchStone automatically reschedules your pending sessions around it—completed work stays intact.

---

## Understanding the Flow Timeline

```
TODAY'S FLOW

9:00 AM ─ 10:00 AM
[STONE] Team Sync                    ✓ Completed
─────────────────────────────────────
10:00 AM ─ 11:00 AM
[WATER] Q4 Strategy - Research       ● In Progress
"Explore market trends"
─────────────────────────────────────
11:00 AM ─ 12:00 PM
[WATER] ML Project - Assembly        ○ Suggested
"Build data pipeline"
─────────────────────────────────────
12:00 PM ─ 1:00 PM
[MEAL] Lunch
─────────────────────────────────────
1:00 PM ─ 2:00 PM
[WATER] ML Project - Assembly        ○ Suggested
"Train initial model"
─────────────────────────────────────
2:00 PM ─ 3:00 PM
[STONE] Client Call                  ○ Upcoming
```

---

## Pressure & Deadlines

### How TouchStone Calculates Workload

For each project with a deadline:
```
Daily Need = Remaining Hours ÷ Days Until Deadline
```

TouchStone compares this against your available capacity (after stones) to determine feasibility.

### Pressure Indicators (Calendar View)

| Status | Color | Meaning |
|--------|-------|---------|
| Healthy | Green | Plenty of time, on track |
| Tight | Yellow | Need consistent daily effort |
| At Risk | Orange | Behind schedule, increase focus |
| Impossible | Red | Cannot complete in time |
| Overdue | Dark Red | Deadline passed |

### Smart Suggestions

As deadlines approach:
- Suggestions increase to keep you on track
- Priority shifts to urgent projects
- Calendar shows pressure visualization

---

## Project Archetypes

When you create a strategic project, AI classifies it into one of four patterns:

### LAB (Creative/Research)
*Research papers, design projects, creative writing*
- **Exploration** → **Bricklaying** → **Refining**

### HUNT (Administrative/Bureaucratic)
*Applications, compliance, documentation*
- **Audit** → **Gathering** → **Execution**

### SPIRAL (Learning/Skill Acquisition)
*Online courses, certifications, skill building*
- **Input** → **Output** → **Reflection**

### BUILD (Engineering/Construction)
*Software projects, physical builds, systems*
- **Spec** → **Dependencies** → **Assembly** → **Testing**

Each archetype comes with phase-specific **mental rules**—cognitive constraints that help you stay focused on what matters for that stage.

---

## Phase Mental Rules

Mental rules prevent common productivity traps:

| Phase Type | Mental Rule Example |
|------------|---------------------|
| Divergent | "Explore widely, no conclusions yet" |
| Convergent | "No new inputs, only synthesize" |
| Execution | "Do the work, don't plan more" |
| Input | "Absorb theory and examples" |
| Output | "Produce without seeking help" |
| Reflection | "Review what worked, adjust" |

---

## The Four Tabs

### Flow (Daily Reality)
Your merged timeline of stones and water. Start here each day.

### Calendar (Pressure View)
Month view showing deadline pressure across all projects. Spot problems before they become crises.

### Plan (Project Management)
Create, view, and manage all your projects. Track progress through phases and sessions.

### Me (Settings)
- Daily capacity configuration
- Meal/break times
- OpenAI API key (for AI features)
- Theme and appearance

---

## Key Principles

1. **Reality First**
   Stones are acknowledged, not optimized away. Your meetings are real—work around them.

2. **Effort Over Precision**
   "Touching" a project means acknowledging you worked on it. Approximate time is enough—this isn't a time tracker.

3. **Capacity Respected**
   TouchStone won't suggest more work than your daily capacity. When you've done enough, it celebrates and suggests rest.

4. **Phases Guide Focus**
   Each project phase has a mental rule. Follow it to avoid spinning your wheels (like editing during a drafting phase).

5. **Flexibility Built In**
   Schedules adapt in real-time. Add a meeting, and your work sessions flow to new slots automatically.

---

## Typical Week with TouchStone

| Day | Actions |
|-----|---------|
| **Monday** | Add week's meetings as stones. Confirm "Let's go". Work through 3 suggested sessions. |
| **Tuesday** | New deadline added → pressure recalculated. Complete 2 sessions on urgent project. |
| **Wednesday** | Surprise meeting → sessions auto-rescheduled. Still complete daily goal. |
| **Thursday** | Phase 1 complete → automatically moves to Phase 2 with new mental rule. |
| **Friday** | Calendar shows healthy pressure. Take an easy day, touch 1 project. |
| **Weekend** | Choose "Rest" → only stones shown. Recharge for next week. |

---

## Quick Reference

| Want to... | Do this... |
|------------|------------|
| See today's schedule | Flow tab |
| Add a meeting | Flow tab → + |
| Create a project | Plan tab → + |
| Start working | Flow tab → tap session → Focus |
| Log quick work | Flow tab → tap session → Touch |
| Check deadlines | Calendar tab |
| Adjust work hours | Me tab → Daily Productive Hours |

---

## What Makes TouchStone Different

**Traditional schedulers**: "Here's your optimized day. Stick to it."

**TouchStone**: "Here's your reality. Here's what fits. Touch what you can."

No guilt. No over-optimization. Just honest acknowledgment of what's fixed and what's flexible—letting your productive work flow naturally around the stones of your day.

---

*TouchStone: Reality acknowledged. Work flowing.*
