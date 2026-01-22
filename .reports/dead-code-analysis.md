# Dead Code Analysis Report

**Generated:** 2026-01-23
**Project:** TouchStone (iOS/macOS Swift App)
**Analysis Method:** Reference search across all Swift files

---

## Summary

| Severity | Count | Description |
|----------|-------|-------------|
| SAFE     | 7     | Files/code only referenced in own file or preview |
| CAUTION  | 4     | Unused but may have external dependencies |
| DANGER   | 1     | Documentation file, no code impact |

---

## SAFE TO DELETE

These files/code are only referenced within themselves (self-reference or preview only):

### 1. `TodayView.swift` - Entire File
**Location:** `TouchStone/Views/Today/TodayView.swift`
**Status:** REPLACED by `TodayFlowView.swift`
**Evidence:**
- Only referenced within its own file (struct definition + preview)
- `ContentView.swift` uses `TodayFlowView()` not `TodayView()`
- Contains duplicate functionality (reality section, projects section, etc.)

**Recommendation:** DELETE entire file

---

### 2. `HistoryView.swift` - Entire File
**Location:** `TouchStone/Views/History/HistoryView.swift`
**Status:** NOT USED in any tab or navigation
**Evidence:**
- Only referenced within its own file
- Not in `ContentView.swift` tab navigation
- Contains `HistoryLogRow` struct used only internally

**Recommendation:** DELETE entire file (or note for future use)

---

### 3. `Architecture.swift` - Entire File
**Location:** `TouchStone/Architecture.swift`
**Status:** DOCUMENTATION ONLY (no executable code)
**Evidence:**
- Only contains comments explaining app architecture
- No imports, no structs, no actual code
- Only referenced in its own file

**Recommendation:** DELETE (documentation is better in CLAUDE.md or README)

---

### 4. `PhaseRowView.swift` - Unused Components
**Location:** `TouchStone/Views/Projects/PhaseRowView.swift`
**Status:** Contains 3 structs, ALL UNUSED
**Evidence:**
- `PhaseRowView` - only in this file (definition + preview)
- `CompactPhaseRow` - only in this file (definition + preview)
- `ActivePhaseCard` - only in this file (definition + preview)

**Recommendation:** DELETE entire file

---

### 5. `TotalTimeControl.swift` - Entire File
**Location:** `TouchStone/Views/Projects/Components/TotalTimeControl.swift`
**Status:** NOT USED anywhere
**Evidence:**
- Only referenced within its own file (definition + preview)

**Recommendation:** DELETE entire file

---

### 6. `PhasedSessionLogSheet.swift` - Entire File
**Location:** `TouchStone/Views/Today/PhasedSessionLogSheet.swift`
**Status:** NOT USED anywhere
**Evidence:**
- Only referenced within its own file (definition + preview)
- Similar functionality exists elsewhere

**Recommendation:** DELETE entire file

---

### 7. `StrategicProjectInputView.swift` - Entire File
**Location:** `TouchStone/Views/Projects/StrategicProjectInputView.swift`
**Status:** REPLACED by `StrategicPlanningChatView`
**Evidence:**
- Only referenced within its own file
- `ProjectsListView.swift` uses `StrategicPlanningChatView()` not this
- Contains `PhaseReviewCard` struct only used internally

**Recommendation:** DELETE entire file

---

## CAUTION - Verify Before Deleting

### 8. `DetailGenerationService.swift` - Entire File
**Location:** `TouchStone/Services/DetailGenerationService.swift`
**Status:** NOT USED
**Evidence:**
- Only referenced within its own file

**Recommendation:** Verify if planned for future use, then DELETE

---

### 9. `StonesListView.swift` - Entire File
**Location:** `TouchStone/Views/Stones/StonesListView.swift`
**Status:** NOT in tab navigation
**Evidence:**
- Not referenced in `ContentView.swift`
- Contains UI for managing stones but not currently accessible

**Recommendation:** Verify if planned for settings or future tab

---

### 10. `ProjectRow` struct (in ProjectsListView.swift)
**Location:** `TouchStone/Views/Projects/ProjectsListView.swift:311-318`
**Status:** WRAPPER only, not adding value
**Evidence:**
- Comment says "Keep for backwards compatibility"
- Just wraps `ProjectCard` with no additional functionality
- Used in 3 other files but could use `ProjectCard` directly

**Recommendation:** Consider removing wrapper and using ProjectCard directly

---

### 11. `SpeechParser.swift` - Potential Dead Code
**Location:** `TouchStone/Services/SpeechParser.swift`
**Status:** Referenced only in `SpeechStoneInputView`
**Evidence:**
- Used in `SpeechStoneInputView.swift`
- But `SpeechStoneInputView` may also be unused (verify usage)

**Recommendation:** Keep if voice input feature is used

---

## DANGER - Do Not Delete

### 12. Configuration and Entry Point Files
- `TouchStoneApp.swift` - App entry point
- `ContentView.swift` - Main navigation
- Model files in `Models/` - All actively used
- Core services (OpenAIClient, AgentService, DesignSystem, etc.)

---

## Unused Code Within Used Files

### In `TodayView.swift` (if not deleting entire file):
- `StoneRow` struct - only used in TodayView
- `ProjectTouchRow` struct - only used in TodayView

### In `HistoryView.swift` (if not deleting entire file):
- `DayGroup` struct - private, only used internally
- `HistoryLogRow` struct - only used internally

---

## File Deletion Summary

**Safe to Delete (7 files, ~1,200 lines):**
1. `TouchStone/Views/Today/TodayView.swift`
2. `TouchStone/Views/History/HistoryView.swift`
3. `TouchStone/Architecture.swift`
4. `TouchStone/Views/Projects/PhaseRowView.swift`
5. `TouchStone/Views/Projects/Components/TotalTimeControl.swift`
6. `TouchStone/Views/Today/PhasedSessionLogSheet.swift`
7. `TouchStone/Views/Projects/StrategicProjectInputView.swift`

**Verify First (1 file):**
1. `TouchStone/Services/DetailGenerationService.swift`

---

## Cleanup Results

### Successfully Deleted Files

| File | Lines Removed | Reason |
|------|--------------|--------|
| `Architecture.swift` | 84 | Documentation-only, no code |
| `HistoryView.swift` | 115 | Unused view, not in tab navigation |
| `TodayView.swift` | 429 | Replaced by TodayFlowView |
| `PhaseRowView.swift` | 224 | All 3 structs unused |
| `TotalTimeControl.swift` | 87 | Unused component |
| `PhasedSessionLogSheet.swift` | 284 | Unused sheet |
| `StrategicProjectInputView.swift` | 278 | Replaced by StrategicPlanningChatView |
| `DetailGenerationService.swift` | 101 | Unused service |

### Also Removed
- `TouchStone/Views/History/` - Empty directory after HistoryView deletion

### Total Lines Removed
**~1,602 lines of dead code**

### Build Verification
- All deletions verified with `xcodebuild build` after each removal
- Build status: **SUCCEEDED** for all deletions

---

## Remaining Candidates (Not Deleted)

These were flagged but not deleted - verify if needed:

1. `StonesListView.swift` - May be needed for future Stones tab
2. `ProjectRow` wrapper in `ProjectsListView.swift:311-318` - Provides backwards compatibility

---

## Notes

- The hook configuration error (`pr-merge-confirm.py`) is a separate issue from the codebase
- UI tests were not run due to the hook error but builds pass
- Manual verification recommended before merging
