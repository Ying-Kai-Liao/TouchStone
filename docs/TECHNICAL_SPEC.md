# TouchStone Technical Specification

## 1. Overview

**App Name:** TouchStone
**Platform:** iOS 17+
**Architecture:** SwiftUI + SwiftData (MVVM with @Observable)
**Storage:** Local-first (on-device SwiftData)
**External Dependencies:** OpenAI API (optional, for strategic planning)

---

## 2. System Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                        UI Layer                              │
│  ┌─────────┐ ┌─────────┐ ┌─────────┐ ┌─────────┐ ┌────────┐ │
│  │  Flow   │ │  Plan   │ │Calendar │ │   Me    │ │Settings│ │
│  │  Tab    │ │  Tab    │ │  Tab    │ │  Tab    │ │  Tab   │ │
│  └────┬────┘ └────┬────┘ └────┬────┘ └────┬────┘ └───┬────┘ │
└───────┼──────────┼──────────┼──────────┼───────────┼────────┘
        │          │          │          │           │
┌───────▼──────────▼──────────▼──────────▼───────────▼────────┐
│                     Service Layer                            │
│  ┌──────────────┐ ┌────────────────┐ ┌───────────────────┐  │
│  │   DayState   │ │ StrategyEngine │ │ PressureCalculator│  │
│  │  (Scheduler) │ │  (AI Planning) │ │   (Feasibility)   │  │
│  └──────────────┘ └────────────────┘ └───────────────────┘  │
│  ┌──────────────┐ ┌────────────────┐ ┌───────────────────┐  │
│  │   Speech     │ │  OpenAIClient  │ │  UserPreferences  │  │
│  │  Recognizer  │ │                │ │                   │  │
│  └──────────────┘ └────────────────┘ └───────────────────┘  │
└─────────────────────────────┬───────────────────────────────┘
                              │
┌─────────────────────────────▼───────────────────────────────┐
│                      Data Layer                              │
│  ┌──────────────────────────────────────────────────────┐   │
│  │                    SwiftData                          │   │
│  │  ┌─────────┐ ┌─────────┐ ┌─────────┐ ┌────────────┐  │   │
│  │  │ Stone   │ │ Project │ │ Touch   │ │ Planned    │  │   │
│  │  │ Event   │ │         │ │ Log     │ │ Session    │  │   │
│  │  └─────────┘ └─────────┘ └─────────┘ └────────────┘  │   │
│  │  ┌─────────┐ ┌─────────┐ ┌─────────┐ ┌────────────┐  │   │
│  │  │ Phase   │ │ Rule    │ │ DayPlan │ │ Scheduled  │  │   │
│  │  │         │ │         │ │         │ │ Session    │  │   │
│  │  └─────────┘ └─────────┘ └─────────┘ └────────────┘  │   │
│  └──────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

---

## 3. Data Models

### 3.1 StoneEvent

Fixed, immovable events representing reality.

```swift
@Model
class StoneEvent {
    var id: UUID
    var title: String
    var startHour: Int        // 0-23
    var startMinute: Int      // 0-59
    var endHour: Int          // 0-23
    var endMinute: Int        // 0-59
    var recurrence: Recurrence
    var specificDate: Date?   // For one-time events
    var createdAt: Date

    // Computed
    func occursOn(date: Date) -> Bool
    func resolvedStartTime(for date: Date) -> Date
    func resolvedEndTime(for date: Date) -> Date
    func durationMinutes() -> Int
}
```

**Recurrence Enum:**
```swift
enum Recurrence: String, Codable {
    case none           // One-time event
    case daily          // Every day
    case weekdays       // Monday-Friday
    case weekends       // Saturday-Sunday
    case weekly         // Specific day of week
    case custom         // Future: custom patterns
}
```

### 3.2 Project

Work that flows around stones.

```swift
@Model
class Project {
    var id: UUID
    var title: String
    var projectDescription: String?
    var currentPhase: String?
    var deadline: Date?
    var totalPlannedMinutes: Int
    var isActive: Bool
    var isStrategic: Bool
    var archetype: String?    // LAB, HUNT, SPIRAL, BUILD
    var createdAt: Date

    // Relationships
    @Relationship(deleteRule: .cascade)
    var touchLogs: [TouchLog]

    @Relationship(deleteRule: .cascade)
    var phases: [ProjectPhase]

    @Relationship(deleteRule: .cascade)
    var documents: [ProjectDocument]

    // Computed
    var totalLoggedMinutes: Int
    var remainingMinutes: Int
    var completionPercentage: Double
    var feasibilityStatus: FeasibilityStatus
}
```

**FeasibilityStatus Enum:**
```swift
enum FeasibilityStatus {
    case healthy      // ≤50% pressure
    case tight        // 50-75% pressure
    case atRisk       // 75-90% pressure
    case impossible   // >90% pressure
    case overdue      // Past deadline
    case noDeadline   // No deadline set
}
```

### 3.3 TouchLog

Records work effort on a project.

```swift
@Model
class TouchLog {
    var id: UUID
    var timestamp: Date
    var duration: ApproximateDuration
    var note: String?
    var project: Project?

    // Computed
    var durationMinutes: Int
}
```

**ApproximateDuration Enum:**
```swift
enum ApproximateDuration: String, Codable {
    case thirtyMinutes = "~30m"    // <45 min
    case oneHour = "~1h"           // 45-75 min
    case ninetyMinutes = "~1.5h"   // 75-105 min
    case twoHours = "~2h"          // 105-150 min

    var minutes: Int {
        switch self {
        case .thirtyMinutes: return 30
        case .oneHour: return 60
        case .ninetyMinutes: return 90
        case .twoHours: return 120
        }
    }

    static func from(minutes: Int) -> ApproximateDuration
}
```

### 3.4 ProjectPhase

Stage within a strategic project.

```swift
@Model
class ProjectPhase {
    var id: UUID
    var title: String
    var sequenceOrder: Int
    var mentalRule: String       // Cognitive constraint
    var phaseType: PhaseType
    var allocationPercentage: Double  // 0.05 - 0.80
    var project: Project?

    @Relationship(deleteRule: .cascade)
    var plannedSessions: [PlannedSession]

    // Computed
    var allocatedMinutes: Int
    var completedMinutes: Int
    var isComplete: Bool
}
```

**PhaseType Enum:**
```swift
enum PhaseType: String, Codable {
    case divergent    // Explore, generate options
    case convergent   // Narrow down, decide
    case execution    // Do the work
    case input        // Gather information
    case output       // Produce deliverables
    case reflection   // Review, learn
}
```

### 3.5 PlannedSession

60-90 minute focused work block.

```swift
@Model
class PlannedSession {
    var id: UUID
    var title: String
    var goal: String
    var estimatedMinutes: Int    // 45-90
    var status: SessionStatus
    var isManuallyEdited: Bool
    var phase: ProjectPhase?
    var completedTouchLog: TouchLog?

    // Computed
    var isLocked: Bool  // completed or skipped
}
```

**SessionStatus Enum:**
```swift
enum SessionStatus: String, Codable {
    case planned
    case completed
    case skipped
}
```

### 3.6 FocusSession

Active focus timer state.

```swift
@Model
class FocusSession {
    var id: UUID
    var startTime: Date
    var targetDurationMinutes: Int
    var pausedAt: Date?
    var accumulatedPauseSeconds: Int
    var state: FocusState
    var plannedSession: PlannedSession?
    var project: Project?

    // Computed
    var elapsedMinutes: Int
    var remainingMinutes: Int
    var isActive: Bool
}
```

**FocusState Enum:**
```swift
enum FocusState: String, Codable {
    case idle
    case running
    case paused
    case completed
    case cancelled
}
```

### 3.7 Rule

Recurring soft blocks (meals, personal time).

```swift
@Model
class Rule {
    var id: UUID
    var title: String
    var startHour: Int
    var startMinute: Int
    var endHour: Int
    var endMinute: Int
    var isActive: Bool
    var ruleType: RuleType

    // Computed
    func durationMinutes() -> Int
}
```

**RuleType Enum:**
```swift
enum RuleType: String, Codable {
    case lunch
    case dinner
    case personal
    case custom
}
```

**Default Rules (seeded on first launch):**
| Rule | Start | End |
|------|-------|-----|
| Lunch | 12:00 | 13:00 |
| Dinner | 18:00 | 19:00 |

### 3.8 DayPlan

Daily work intention and schedule.

```swift
@Model
class DayPlan {
    var id: UUID
    var date: Date              // Normalized to midnight
    var wantsToWork: Bool
    var isCommitted: Bool       // Schedule locked
    var createdAt: Date

    @Relationship(deleteRule: .cascade)
    var scheduledSessions: [ScheduledSession]

    var backlog: Backlog?
}
```

### 3.9 ScheduledSession

Persisted work session locked to schedule.

```swift
@Model
class ScheduledSession {
    var id: UUID
    var startTime: Date
    var endTime: Date
    var status: ScheduledSessionStatus
    var project: Project?
    var plannedSession: PlannedSession?
    var dayPlan: DayPlan?

    // Computed
    var durationMinutes: Int
    var isPast: Bool
}
```

**ScheduledSessionStatus Enum:**
```swift
enum ScheduledSessionStatus: String, Codable {
    case pending
    case completed
    case skipped
}
```

### 3.10 Backlog

Daily productive capacity tracking.

```swift
@Model
class Backlog {
    var id: UUID
    var date: Date
    var totalHours: Int          // Default: 6
    var allocatedHours: Double
    var dayPlan: DayPlan?

    // Computed
    var remainingHours: Double
    var isFull: Bool
}
```

### 3.11 ProjectDocument

File attachments for AI context.

```swift
@Model
class ProjectDocument {
    var id: UUID
    var filename: String
    var fileType: String         // pdf, txt, etc.
    var bookmarkData: Data       // Security-scoped bookmark
    var extractedText: String?   // For AI context
    var project: Project?
    var createdAt: Date
}
```

### 3.12 WorkflowItem

Unified timeline item (computed, not persisted).

```swift
struct WorkflowItem: Identifiable {
    var id: UUID
    var type: WorkflowItemType
    var title: String
    var startTime: Date
    var endTime: Date
    var status: WorkflowItemStatus
    var project: Project?
    var plannedSession: PlannedSession?
    var stoneEvent: StoneEvent?
    var rule: Rule?

    // Computed
    var durationMinutes: Int
    var isPast: Bool
    var isCurrent: Bool
}
```

**WorkflowItemType Enum:**
```swift
enum WorkflowItemType {
    case stone           // Fixed event
    case water           // Project work session
    case breathingSpace  // Transition time
    case flowPrep        // Preparation time
    case rest            // Break between sessions
    case meal            // Lunch/dinner
}
```

**WorkflowItemStatus Enum:**
```swift
enum WorkflowItemStatus {
    case completed
    case inProgress
    case upcoming
    case overdue
    case suggested
}
```

---

## 4. Services

### 4.1 DayState (Liquid Scheduler)

Core scheduling algorithm that "pours water around stones."

```swift
@Observable
class DayState {
    var date: Date
    var stones: [StoneEvent]
    var projects: [Project]
    var rules: [Rule]
    var workflowItems: [WorkflowItem]
    var isWorkDay: Bool
    var isCommitted: Bool

    // Main computation
    func compute(
        stones: [StoneEvent],
        projects: [Project],
        rules: [Rule],
        preferences: UserPreferences
    ) -> [WorkflowItem]

    // For rest days
    func computeStonesOnly(stones: [StoneEvent]) -> [WorkflowItem]

    // Lock schedule to database
    func commitSchedule(context: ModelContext)

    // Load persisted schedule
    func loadFromPersistedSchedule(dayPlan: DayPlan)

    // Adjust for new stones
    func rescheduleAroundStones(newStone: StoneEvent)
}
```

**Liquid Scheduler Algorithm:**

```
1. INPUT: stones[], projects[], rules[], preferences
2. Get working hours range (default 9:00-21:00)
3. Filter stones that occur on target date
4. Convert rules to time blocks
5. Merge and sort all blocked times (stones + rules)
6. Calculate free slots between blocked times
7. Filter out past slots (for today)
8. For each free slot:
   a. Calculate available duration
   b. If duration >= minSessionLength (45 min):
      - Select next project needing work (priority: deadline pressure)
      - Create water session sized to fit slot (max 90 min)
      - Insert break if accumulated work >= breakInterval
   c. If duration < minSessionLength:
      - Mark as breathing space
9. Build unified WorkflowItem array
10. Sort by start time
11. OUTPUT: workflowItems[]
```

**Session Fitting Logic:**
```
slot_duration = slot.end - slot.start
if slot_duration >= 90:
    session_duration = 90
else if slot_duration >= 45:
    session_duration = slot_duration
else:
    skip (too short)
```

### 4.2 StrategyEngine

AI-powered project decomposition.

```swift
class StrategyEngine {
    private let client: OpenAIClient

    // Classify goal into archetype
    func classifyGoal(_ goal: String) async throws -> Archetype

    // Generate phases for archetype
    func generatePhases(
        goal: String,
        archetype: Archetype,
        totalMinutes: Int
    ) async throws -> [PhaseDefinition]

    // Generate sessions for phase
    func generateSessions(
        phase: PhaseDefinition,
        allocatedMinutes: Int
    ) async throws -> [SessionDefinition]

    // Full plan generation
    func generatePlan(
        goal: String,
        totalMinutes: Int
    ) async throws -> StrategicPlan
}
```

**Archetype Definitions:**

| Archetype | Description | Default Phases |
|-----------|-------------|----------------|
| LAB | Creative/Research | Exploration (40%) → Bricklaying (40%) → Refining (20%) |
| HUNT | Administrative | Audit (20%) → Gathering (40%) → Execution (40%) |
| SPIRAL | Learning | Input (30%) → Output (50%) → Reflection (20%) |
| BUILD | Engineering | Spec (15%) → Dependencies (20%) → Assembly (45%) → Testing (20%) |

**AI Prompts (summarized):**

Classification Prompt:
```
Analyze the following goal and classify it into one of these archetypes:
- LAB: Creative exploration, research, design work
- HUNT: Administrative tasks, gathering resources, organizing
- SPIRAL: Learning, skill development, study
- BUILD: Engineering, construction, technical implementation

Goal: {goal}

Respond with JSON: {"archetype": "LAB|HUNT|SPIRAL|BUILD", "reasoning": "..."}
```

Phase Generation Prompt:
```
Generate phases for a {archetype} project.
Goal: {goal}
Total time: {minutes} minutes

Each phase needs:
- title: Clear phase name
- mentalRule: Cognitive constraint (what mindset to maintain)
- phaseType: divergent|convergent|execution|input|output|reflection
- allocationPercentage: Decimal (0.05-0.80, must sum to 1.0)

Respond with JSON array of phases.
```

Session Generation Prompt:
```
Generate work sessions for this phase:
Phase: {phase.title}
Mental Rule: {phase.mentalRule}
Available time: {minutes} minutes
Session length: 60-90 minutes each

Each session needs:
- title: Action-oriented title
- goal: Specific, measurable outcome
- estimatedMinutes: 60-90

Respond with JSON array of sessions.
```

### 4.3 StrategyChatEngine

Interactive planning with conversation.

```swift
@Observable
class StrategyChatEngine {
    var messages: [ChatMessage]
    var currentStep: PlanningStep
    var archetype: Archetype?
    var phases: [PhaseDefinition]
    var sessions: [SessionDefinition]

    enum PlanningStep {
        case classifying
        case adjustingPhases
        case generatingSessions
        case refining
        case complete
    }

    func startPlanning(goal: String) async
    func adjustPhaseAllocation(_ phase: PhaseDefinition, to: Double)
    func regenerateSessions() async
    func sendMessage(_ message: String) async
}
```

**Phase Allocation Redistribution:**
```
When user adjusts phase X to new percentage P:
1. Calculate delta = P - X.currentPercentage
2. Distribute -delta proportionally among other unlocked phases
3. Ensure all phases stay within 5-80% range
4. Ensure total = 100%
```

### 4.4 PressureCalculator

Deadline feasibility analysis.

```swift
class PressureCalculator {
    func calculatePressure(
        for project: Project,
        availableHoursPerDay: Double,
        stoneHoursPerDay: Double
    ) -> PressureResult

    struct PressureResult {
        let ratio: Double           // 0.0 - ∞
        let status: FeasibilityStatus
        let requiredHoursPerDay: Double
        let availableHoursPerDay: Double
        let daysRemaining: Int
    }
}
```

**Pressure Calculation Formula:**
```
remaining_hours = project.totalPlannedMinutes - project.totalLoggedMinutes
buffered_hours = remaining_hours * 1.25  // 25% safety buffer
days_until_deadline = deadline.date - today
available_capacity = days_until_deadline * (dailyProductiveHours - avgStoneHours)

pressure_ratio = buffered_hours / available_capacity

if deadline < today && remaining_hours > 0:
    status = .overdue
else if pressure_ratio > 0.90:
    status = .impossible
else if pressure_ratio > 0.75:
    status = .atRisk
else if pressure_ratio > 0.50:
    status = .tight
else:
    status = .healthy
```

### 4.5 SpeechRecognizer

Voice input for stone creation.

```swift
@Observable
class SpeechRecognizer {
    var state: SpeechState
    var transcript: String
    var error: SpeechError?

    enum SpeechState {
        case idle
        case requesting      // Requesting permission
        case recording
        case processing
        case finished
    }

    func startRecording()
    func stopRecording()

    // Auto-stop after 30 seconds
    private var autoStopTimer: Timer?
}
```

**Speech Framework Usage:**
```swift
// Request authorization
SFSpeechRecognizer.requestAuthorization { status in }

// Create recognition request
let request = SFSpeechAudioBufferRecognitionRequest()
request.shouldReportPartialResults = true

// Start audio engine
let audioEngine = AVAudioEngine()
let inputNode = audioEngine.inputNode
inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
    request.append(buffer)
}

// Recognize
recognizer.recognitionTask(with: request) { result, error in
    self.transcript = result?.bestTranscription.formattedString ?? ""
}
```

### 4.6 SpeechParser

Parse natural language to stone events.

```swift
class SpeechParser {
    func parse(_ transcript: String) -> ParsedStone?

    struct ParsedStone {
        let title: String
        let startTime: DateComponents
        let endTime: DateComponents
        let date: Date?
        let recurrence: Recurrence
    }
}
```

**Parsing Patterns:**
```
Time patterns:
- "10 AM", "10:30 AM", "10 o'clock"
- "from X to Y", "X until Y", "X - Y"
- "at X" (assumes 1 hour duration)

Date patterns:
- "today", "tomorrow"
- "Monday", "next Tuesday"
- "January 15th", "15th of January"

Recurrence patterns:
- "every day", "daily"
- "every weekday", "weekdays"
- "every Monday", "weekly on Monday"
```

### 4.7 OpenAIClient

API communication with OpenAI.

```swift
class OpenAIClient {
    private let apiKey: String
    private let endpoint = "https://api.openai.com/v1/chat/completions"
    private let model = "gpt-4o-mini"

    func send(
        messages: [OpenAIMessage],
        jsonMode: Bool = false
    ) async throws -> String

    struct OpenAIMessage {
        let role: String      // system, user, assistant
        let content: String
    }
}
```

**Request Format:**
```json
{
  "model": "gpt-4o-mini",
  "messages": [...],
  "response_format": { "type": "json_object" },
  "temperature": 0.7,
  "max_tokens": 2000
}
```

**Error Handling:**
```swift
enum OpenAIError: Error {
    case networkError(Error)
    case httpError(statusCode: Int)
    case decodingError(Error)
    case apiError(message: String)
    case missingAPIKey
}
```

### 4.8 UserPreferences

Configuration management.

```swift
@Observable
class UserPreferences {
    // Persisted to UserDefaults
    @AppStorage var dailyProductiveHours: Int = 6
    @AppStorage var workDayStartHour: Int = 9
    @AppStorage var workDayEndHour: Int = 21
    @AppStorage var sessionMinMinutes: Int = 45
    @AppStorage var sessionMaxMinutes: Int = 90
    @AppStorage var breaksEnabled: Bool = true
    @AppStorage var breakIntervalMinutes: Int = 60
    @AppStorage var breakDurationMinutes: Int = 15
    @AppStorage var deadlineBufferPercent: Int = 20
    @AppStorage var appearanceMode: AppearanceMode = .system
    @AppStorage var themeColor: ThemeColor = .sage
}
```

**AppearanceMode Enum:**
```swift
enum AppearanceMode: String, CaseIterable {
    case system
    case light
    case dark
}
```

**ThemeColor Enum:**
```swift
enum ThemeColor: String, CaseIterable {
    case sage
    case ocean
    case lavender
    case coral
    case gold
    case slate

    var color: Color { ... }
}
```

### 4.9 KeychainHelper

Secure API key storage.

```swift
class KeychainHelper {
    static func save(key: String, value: String) throws
    static func read(key: String) throws -> String?
    static func delete(key: String) throws
}

class APIKeyManager {
    private static let keyName = "openai_api_key"

    static func saveAPIKey(_ key: String) throws
    static func getAPIKey() throws -> String?
    static func deleteAPIKey() throws
    static var hasAPIKey: Bool
}
```

### 4.10 DocumentTextExtractor

Extract text from attached documents.

```swift
class DocumentTextExtractor {
    static func extractText(from url: URL) -> String?

    // Supported formats
    static func extractFromPDF(_ url: URL) -> String?
    static func extractFromText(_ url: URL) -> String?
}
```

---

## 5. View Architecture

### 5.1 Tab Structure

```swift
struct ContentView: View {
    @State private var selectedTab: Tab = .flow

    enum Tab {
        case flow
        case plan
        case calendar
        case me
        case settings
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            TodayFlowView().tag(Tab.flow)
            ProjectsListView().tag(Tab.plan)
            CalendarView().tag(Tab.calendar)
            MeView().tag(Tab.me)
            SettingsView().tag(Tab.settings)
        }
    }
}
```

### 5.2 View Hierarchy

```
ContentView
├── TodayFlowView
│   ├── WorkTodayPromptView
│   ├── FlowTimelineView
│   │   └── FlowItemRow (repeated)
│   ├── SuggestedSessionRow
│   ├── FocusModeView
│   ├── PhasedSessionLogSheet
│   └── StoneEditSheet
│
├── ProjectsListView
│   ├── NewProjectChoiceView
│   ├── ProjectFormView
│   ├── ProjectDetailView (simple)
│   └── StrategicProjectDetailView
│       ├── PhaseAllocationCard
│       ├── SessionGoalsList
│       └── EditableSessionRow
│
├── CalendarView
│   └── DayDetailView
│       └── StoneEventFormView
│
├── MeView
│
└── SettingsView
    ├── WorkingHoursView
    ├── DailyGoalView
    ├── RulesListView
    │   └── RuleFormView
    ├── AppearanceView
    └── APIKeyView
```

### 5.3 State Management

```swift
// App-level state
@main
struct TouchStoneApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .modelContainer(for: [
                    StoneEvent.self,
                    Project.self,
                    TouchLog.self,
                    ProjectPhase.self,
                    PlannedSession.self,
                    FocusSession.self,
                    Rule.self,
                    DayPlan.self,
                    ScheduledSession.self,
                    Backlog.self,
                    ProjectDocument.self
                ])
        }
    }
}

// View-level state
struct TodayFlowView: View {
    @Environment(\.modelContext) private var context
    @Query private var stones: [StoneEvent]
    @Query private var projects: [Project]
    @Query private var rules: [Rule]

    @State private var dayState = DayState()
    @State private var showingWorkPrompt = true
}
```

---

## 6. Algorithms

### 6.1 Project Priority Ordering

For liquid scheduler session assignment:

```
1. Filter to active projects only
2. Sort by:
   a. Has deadline vs no deadline (deadline first)
   b. Pressure ratio (higher pressure first)
   c. Days until deadline (sooner first)
   d. Created date (older first)
3. Round-robin if multiple projects have similar priority
```

### 6.2 Break Insertion

```
accumulated_work = 0
break_interval = preferences.breakIntervalMinutes  // default 60

for each session in schedule:
    accumulated_work += session.duration
    if accumulated_work >= break_interval:
        insert break (duration: preferences.breakDurationMinutes)
        accumulated_work = 0
```

### 6.3 Streak Calculation

```
streak = 0
current_date = today

while true:
    touches_on_date = touchLogs.filter { $0.date == current_date }
    if touches_on_date.isEmpty:
        break
    streak += 1
    current_date = current_date - 1 day

return streak
```

### 6.4 Phase Reallocation

When user adjusts one phase's allocation:

```
function reallocate(phases, targetPhase, newPercentage):
    delta = newPercentage - targetPhase.percentage
    targetPhase.percentage = newPercentage

    otherPhases = phases.filter { $0 != targetPhase }
    totalOtherPercentage = sum(otherPhases.map { $0.percentage })

    for phase in otherPhases:
        proportion = phase.percentage / totalOtherPercentage
        phase.percentage -= delta * proportion
        phase.percentage = clamp(phase.percentage, 0.05, 0.80)

    // Normalize to ensure sum = 1.0
    normalize(phases)
```

---

## 7. API Contracts

### 7.1 OpenAI Classification Response

```json
{
  "archetype": "LAB",
  "reasoning": "This goal involves creative exploration and iteration..."
}
```

### 7.2 OpenAI Phase Generation Response

```json
{
  "phases": [
    {
      "title": "Exploration",
      "mentalRule": "Explore widely, no conclusions yet",
      "phaseType": "divergent",
      "allocationPercentage": 0.40
    },
    ...
  ]
}
```

### 7.3 OpenAI Session Generation Response

```json
{
  "sessions": [
    {
      "title": "Research existing solutions",
      "goal": "Find and document 5 existing approaches to this problem",
      "estimatedMinutes": 60
    },
    ...
  ]
}
```

---

## 8. Error Handling

### 8.1 Error Types

```swift
enum TouchStoneError: Error {
    // Data errors
    case modelNotFound(type: String, id: UUID)
    case invalidData(description: String)

    // Network errors
    case networkUnavailable
    case apiKeyMissing
    case apiError(OpenAIError)

    // Speech errors
    case speechNotAuthorized
    case speechRecognitionFailed(Error)

    // Document errors
    case documentAccessDenied
    case documentExtractionFailed
}
```

### 8.2 Error Recovery

| Error | Recovery Strategy |
|-------|-------------------|
| Network unavailable | Show offline indicator, queue for retry |
| API key missing | Prompt to add in Settings |
| Speech not authorized | Show settings link for permissions |
| Document access denied | Request access again with file picker |

---

## 9. Performance Considerations

### 9.1 SwiftData Queries

- Use `@Query` with predicates to limit data fetched
- Filter stones by date range, not all stones
- Lazy load touch logs for history view

### 9.2 Liquid Scheduler

- Cache computed schedule for current day
- Recompute only on:
  - Stone add/edit/delete
  - Project add/edit/delete
  - Rule change
  - Preference change
  - Day change

### 9.3 AI Requests

- Debounce user input before sending to AI
- Cache classification results
- Show loading states during AI operations

---

## 10. Security

### 10.1 API Key Storage

- Stored in iOS Keychain (kSecClassGenericPassword)
- Never logged or transmitted except to OpenAI
- User can delete at any time

### 10.2 Document Access

- Uses security-scoped bookmarks
- Request access each app launch
- No cloud sync of documents

### 10.3 Data Privacy

- All data stored on-device only
- No analytics or telemetry
- No network requests except OpenAI (when configured)

---

## 11. Testing Strategy

### 11.1 Unit Tests

- DayState: Liquid scheduler algorithm
- PressureCalculator: Feasibility calculations
- SpeechParser: Natural language parsing
- Duration conversion functions

### 11.2 Integration Tests

- SwiftData model relationships
- OpenAI client (with mock server)
- Full planning flow

### 11.3 UI Tests

- Tab navigation
- Stone creation flow
- Project creation flows (simple and strategic)
- Focus mode timer

---

## 12. Future Considerations

### 12.1 Planned Enhancements

- Calendar sync (import external calendars as stones)
- Widgets (today's schedule, current session)
- Watch app (quick touch logging)
- Siri shortcuts
- iCloud sync

### 12.2 Architecture Extensibility

- Protocol-based AI engine (swap OpenAI for other providers)
- Pluggable storage layer (future cloud sync)
- Theme system expansion

---

*Specification Version: 1.0*
*Last Updated: January 2026*
