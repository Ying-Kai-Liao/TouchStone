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
   - Wait for CI checks to pass
   - Wait for review/approval before merging

6. **Before merging a PR:**
   - Always run `xcodebuild` to verify the build passes
   - Test on a simulator to catch runtime errors (especially SwiftData migrations)
   - Never merge a PR without confirming the build succeeds

7. **After PR is merged:**
   - Delete the feature branch
   - Pull latest main before starting new work

## Continuous Integration (CI)

This project uses GitHub Actions to automatically build and test the app on every PR and push to `main`.

### CI Workflow

- **Trigger**: Runs on every push to `main` and on all pull requests targeting `main`
- **Environment**: macOS 15 with latest available Xcode (16.x preferred for objectVersion 77 support)
- **Platform**: iOS Simulator (iPhone 15, iOS 17.2)
- **Steps**:
  1. Checkout code
  2. Build the project
  3. Run tests (if available)
  4. Upload logs on failure

### PR Requirements

**All pull requests MUST pass CI checks before merging.**

If CI fails on your PR:
1. Review the build logs in the GitHub Actions tab
2. Fix the issues locally on your feature branch
3. Commit and push the fixes
4. CI will automatically re-run
5. Repeat until all checks pass

### Common Build Issues

- **Missing files**: Ensure all Swift files are added to the Xcode project
- **Import errors**: Check that all dependencies are properly configured
- **Signing issues**: CI runs without code signing - don't add signing requirements
- **API keys**: Don't commit API keys; use environment variables or mock services for tests
- **Xcode version**: This project uses objectVersion 77 (Xcode 15+). If you see "didn't find classname for 'isa' key" errors, ensure you're using Xcode 15.3 or later

### Testing Locally Before Push

To ensure your changes will pass CI, build and test locally:

```bash
# Clean build
xcodebuild clean build \
  -project TouchStone.xcodeproj \
  -scheme TouchStone \
  -destination 'platform=iOS Simulator,name=iPhone 15,OS=17.2'

# Run tests
xcodebuild test \
  -project TouchStone.xcodeproj \
  -scheme TouchStone \
  -destination 'platform=iOS Simulator,name=iPhone 15,OS=17.2'
```

**Important**: If you're using Claude Code for development, ensure it checks CI status and fixes any failures in a loop until all checks pass successfully.

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
