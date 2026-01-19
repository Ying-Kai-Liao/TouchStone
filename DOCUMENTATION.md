# TouchStone Documentation

## Overview

TouchStone is an iOS time management app built on the "Stone & Water" philosophy. Rather than trying to optimize your schedule, TouchStone helps you acknowledge reality and make intentional choices about how to spend your flexible time around fixed commitments.

---

## Core Philosophy

### The Stone & Water Metaphor

- **Stones** represent fixed, immovable events in your day—meetings, appointments, commitments that cannot be changed. They represent reality.

- **Water** represents your flexible work—projects and tasks that can flow around your stones. Water fills the gaps between stones, representing intentional effort.

The philosophy is "acknowledging reality, not managing it." TouchStone doesn't try to create an impossible schedule. Instead, it shows you what's actually achievable given your fixed commitments and helps you make the most of your available time.

---

## Main Features

### 1. Flow Tab (Daily Workflow)

The Flow tab is your primary interface for managing today's work.

**Key Features:**
- **Daily Decision**: Each day starts with "Do you want to work today?" This acknowledges that rest days are valid choices.
- **Integrated Timeline**: See stones (fixed events) and suggested work sessions in chronological order
- **Liquid Scheduler**: The app automatically "pours" project work into available time slots between your stones
- **Quick Touch Logging**: Tap any project to log work effort—fast and frictionless
- **Focus Mode**: Optional 55-minute timer for deep work sessions
- **Capacity Tracking**: Visual indicator when you've reached your daily productive capacity
- **Contextual Messages**: Helpful messages based on your schedule load (e.g., "The schedule is light. You have space to think.")
- **Meal Badges**: Lunch and dinner times shown as inline badges
- **Undo Support**: Made a mistake? Undo your last touch with one tap
- **Edit Mode**: Drag to reorder sessions or adjust times

### 2. Plan Tab (Project Management)

Manage your projects with two approaches:

**Simple Projects**
- Quick creation with just a title
- Track current phase
- Log work directly

**Strategic Projects** (AI-Powered)
- AI-assisted project decomposition using four archetypes:

  | Archetype | Best For | Phases |
  |-----------|----------|--------|
  | **LAB** | Creative/Research work | Exploration → Bricklaying → Refining |
  | **HUNT** | Administrative tasks | Audit → Gathering → Execution |
  | **SPIRAL** | Learning projects | Input → Output → Reflection |
  | **BUILD** | Engineering/Technical | Spec → Dependencies → Assembly → Testing |

**Strategic Planning Flow:**
1. Enter your goal description
2. AI classifies it into the most suitable archetype
3. AI generates phases with mental rules (cognitive constraints)
4. AI creates 60-90 minute work sessions with specific goals
5. Adjust phase time allocations (5-80% per phase)
6. Optionally refine with documents and AI chat

### 3. Calendar Tab

Visual scheduling and stone management.

**Features:**
- **Month View**: Calendar grid with all your stones
- **Pressure Visualization**: Color-coded days showing deadline pressure and workload
- **Add Stones**: Use voice input or form entry
- **Day Detail**: View and manage stones for any selected day
- **Energy Gradient**: Visual representation of busy vs. light days

### 4. Me Tab (Personal Statistics)

Track your progress and build momentum.

**Displays:**
- Streak count (consecutive days with touches)
- Total hours (all-time)
- This week's hours
- Today's hours
- Active projects count
- Completed projects count
- Weekly progress visualization

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

## Tips for Success

### Daily Workflow

1. **Start each day with the prompt** - Consciously decide if you're working today
2. **Review your stones first** - Know your fixed commitments
3. **Trust the liquid scheduler** - Let it fill your gaps with project work
4. **Touch often** - Quick, approximate logging is better than perfect tracking
5. **Use Focus Mode for deep work** - The timer helps maintain concentration

### Project Planning

1. **Be specific in goal descriptions** - Better input = better AI output
2. **Choose strategic projects for complex work** - The structure helps
3. **Review and adjust phases** - AI suggestions are starting points
4. **Attach relevant documents** - Context improves AI recommendations
5. **Embrace mental rules** - They prevent premature optimization

### Managing Pressure

1. **Add deadlines to important projects** - Enables pressure tracking
2. **Watch the calendar colors** - Red days need attention
3. **Trust "Impossible" warnings** - Renegotiate deadlines early
4. **Use buffer wisely** - The 20% default protects against surprises

### Building Habits

1. **Log daily** - Even small touches build streaks
2. **Check Me tab weekly** - Track your progress
3. **Adjust settings as needed** - Your capacity may change
4. **Rest days are valid** - The app supports them intentionally

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

*TouchStone: Acknowledge reality. Flow intentionally.*
