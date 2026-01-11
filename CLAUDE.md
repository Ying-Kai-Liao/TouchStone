# TouchStone Development Guidelines

## Branching Strategy

All future development must follow this branching workflow:

1. **Never commit directly to `main`** - The main branch is protected and should only receive code through pull requests.

2. **Create a feature branch for all work:**
   ```bash
   git checkout main
   git pull origin main
   git checkout -b dev/<feature-name>
   ```

3. **Branch naming convention:**
   - `dev/<feature-name>` - For new features (e.g., `dev/calendar-sync`)
   - `dev/fix-<issue>` - For bug fixes (e.g., `dev/fix-session-logging`)
   - `dev/refactor-<area>` - For refactoring (e.g., `dev/refactor-models`)

4. **Development workflow:**
   ```
   main ──────────────────────────────────►
          \                        /
           └── dev/feature ──────►  (PR)
   ```

5. **Submit a Pull Request:**
   - Push your branch to origin
   - Create a PR targeting `main`
   - Include a summary of changes
   - Wait for review/approval before merging

6. **After PR is merged:**
   - Delete the feature branch
   - Pull latest main before starting new work

## Project Structure

```
TouchStone/
├── Models/           # SwiftData models (Project, Phase, Session, etc.)
├── Views/            # SwiftUI views organized by feature
│   ├── Today/        # Daily view and session logging
│   ├── Projects/     # Project management views
│   ├── Stones/       # Fixed event (stone) views
│   ├── History/      # Historical data views
│   └── Settings/     # App settings
├── Services/         # Business logic (AI, Keychain, Speech)
├── ContentView.swift # Main tab navigation
└── TouchStoneApp.swift # App entry point
```

## Key Concepts

- **Stones**: Fixed events that cannot be moved (meetings, appointments)
- **Water**: Flexible work (projects) that flows around stones
- **Strategic Projects**: AI-powered project decomposition into phases and sessions
- **Phases**: Project stages with mental rules (divergent, convergent, etc.)
- **Sessions**: 60-90 minute focused work blocks with specific goals

## Dependencies

- SwiftUI + SwiftData (local-first storage)
- Speech framework for voice input
- OpenAI API for strategic planning (requires API key in Settings)
