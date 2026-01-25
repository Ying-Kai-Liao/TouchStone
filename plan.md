# Plan: Add `add_context` Action to Chat

## Overview
Add a fourth action type `add_context` so Sira can proactively propose DayContext creation (vacations, holidays, travel, etc.) when users mention them in chat.

## Files to Change

### 1. Backend: `backend/schemas.py`
- Add `PendingDayContext` model (after `PendingTouchLog`):
  - `temp_id: str`
  - `name: str`
  - `start_date: str` (ISO date)
  - `end_date: str` (ISO date)
  - `type: str` (holiday, vacation, travel, event, personal, custom)
  - `work_mode: str` (none, reduced, fixed, normal)
  - `capacity_percent: int` (0-100, default 50)
  - `fixed_task_description: str | None`
- Update `PendingAction`: add `day_context: PendingDayContext | None = None`, update action_type description to include `add_context`

### 2. Backend: `backend/server.py`
- Update `SIRA_SYSTEM_PROMPT` — in the Day Context Awareness section, add instruction: "When a user mentions being on vacation, traveling, having a holiday, or any event that affects their day, proactively propose an `add_context` action with appropriate type and work_mode."
- Update `_build_pending_actions()` (or wherever actions are constructed from sub-agent responses) to handle `add_context` action type

### 3. iOS: `AgentService.swift`
- Add `PendingDayContext` struct (after `PendingTouchLog`, ~line 350):
  - `tempId, name, startDate, endDate, type, workMode, capacityPercent, fixedTaskDescription`
  - CodingKeys mapping snake_case
  - Memberwise init
- Update `PendingAction` struct: add `dayContext: PendingDayContext?` field, update `id` computed property, update `CodingKeys`, update init

### 4. iOS: `PendingActionsPreview.swift`
- Add `@State private var selectedContextIndex: Int?`
- Add `pendingContextsSection` (after logs section, before suggestions) — label: "Day Plans to Add", icon: `calendar.badge.plus`
- Add `findActionIndex(for: PendingDayContext)` helper
- Add sheet for `PendingContextDetailSheet`
- Add `ContextSheetItem` identifiable wrapper
- Add `PendingContextRow` view — shows type icon, name, date range, work mode badge

### 5. iOS: New file `PendingContextDetailSheet.swift`
- Create `TouchStone/Views/Agent/PendingContextDetailSheet.swift`
- Pattern: same as `PendingStoneDetailSheet`
- Fields: name (TextField), start date (DatePicker), end date (DatePicker), type (Picker over DayContextType.allCases), work mode (Picker over DayContextWorkMode.allCases), capacity slider (if reduced), fixed task field (if fixed)
- onSave returns updated `PendingDayContext`, onDelete removes from pending

### 6. iOS: `ConfirmedActionsPreview.swift`
- Add `confirmedContextsSection` — shows confirmed day contexts with green checkmark style
- Add `ConfirmedContextRow` view

### 7. iOS: `UnifiedInputView.swift`
- Update `commitActions()` switch: add `case "add_context"` → call `createDayContext(from:)`
- Add `createDayContext(from: AgentService.PendingDayContext)` — converts to SwiftData `DayContext` model and inserts

## Execution Order
1. Backend schemas + server (2 files)
2. iOS AgentService struct additions (1 file)
3. iOS PendingContextDetailSheet (new file)
4. iOS PendingActionsPreview + ConfirmedActionsPreview (2 files)
5. iOS UnifiedInputView commitActions (1 file)
6. Build & verify
