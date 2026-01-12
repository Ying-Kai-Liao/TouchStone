# Daily Flow State Machine

## State 0: Today / Idle
Shows:
- Date
- Stones (fixed events)
- Day summary (human language)
- Engagement gate question

## State 1: Engaged (user opted in)
Shows:
- "Things worth touching today"
- Each project has: "Spent some focused time"

## State 2: Touched
Trigger:
- user taps "Spent some focused time"
System:
- create TouchLog(projectId, timestamp)
UI:
- show toast "Logged · Undo" (3–5 sec)

## State 3: Offer Focus Mode (non-blocking)
Prompt:
- "Want to stay here for a bit?"
Actions:
- Enter focus mode
- Just log it

## State 4: Focus Mode active
Shows:
- Project name + phase + short goal line
- Soft time container (~1h) without strict countdown
Actions:
- Finish session
- Leave early

## State 5: Exit reflection (optional, non-evaluative)
Question:
- "Did you get something out of this?"
Choices:
- Yeah / A little / Not really
System:
- store reflection, no consequences
Return:
- Today
