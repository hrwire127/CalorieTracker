# Architecture

## Shape
The app is a SwiftUI MVVM app backed by SwiftData. Views own presentation, ViewModels own screen state and operations, models define persisted data, utilities hold reusable pure-ish helpers, and services perform external API calls.

## Data Flow
1. User acts in SwiftUI view.
2. View calls a ViewModel or local save closure.
3. ViewModel validates with `FoodEntryValidator` where needed.
4. SwiftData `ModelContext` inserts/updates/deletes `DailyGoal` and `FoodItem`.
5. Goal totals are recalculated before save.
6. Views reload through ViewModel state, SwiftData fetches, or `foodItemsDidChange` notification.

## AI Flow
Image AI:
`AICameraEntryView` -> `AICameraEntryViewModel` -> `ImageProcessor` -> `NetworkManager.estimateCalories(fromBase64Image:)` -> `NutritionEstimate` -> `FoodConfirmationView` -> SwiftData.

Text AI:
`ManualEntryView` AI Guess tab -> `ManualEntryViewModel` -> `NetworkManager.estimateNutrition(foodName:grams:)` -> editable fields -> SwiftData.

## Persistence
- `DailyGoal` and `FoodItem` are SwiftData `@Model` types.
- Current diet targets are stored in `UserDefaults` through `DailyGoalTargets`.
- Profile/settings/API key/theme/backup metadata use `@AppStorage` and backup snapshots.
- Backups serialize goals, food items, profile, settings, image data, and current targets.

## Mermaid Mindmap
```mermaid
mindmap
  root((CalorieTracker))
    App
      CalorieTrackerApp
      AppRootView
      TabView
      Central AI Scan Button
    Data
      SwiftData
        DailyGoal
        FoodItem
      UserDefaults
        DailyGoalTargets
        Profile
        Theme
        Gemini API Key
      Backup
        BackupManager
        BackupDocument
    Views
      Dashboard
        Progress Ring
        Streak Bar
        Today Food
      Entry
        Manual Entry
        AI Guess
        AI Camera Entry
        Confirmation
        Food Editor
      History
        Week Mode
        Month Mode
        Period Food List
      Statistics
        Charts
        Deficit Surplus Metrics
      Settings
        Profile
        Theme
        Backup
        API Key
    ViewModels
      DashboardViewModel
      ManualEntryViewModel
      AICameraEntryViewModel
      StatisticsViewModel
    Services
      NetworkManager
        Gemini Image Estimate
        Gemini Text Estimate
    Utilities
      FoodEntryValidator
      NutritionCalculator
      ImageProcessor
      CameraAuthorization
    CI
      project.yml
      codemagic.yaml
      ScreenshotUITests
```

## Future Agent Guidance
- Keep model changes conservative; add migration planning before changing persisted model shape.
- Prefer adding helper structs/functions near related views unless shared across screens.
- Keep AI responses parsed through `NutritionEstimate`.
- Preserve confirmation/edit-before-save behavior for AI outputs.
- Keep Codemagic workflows working from generated XcodeGen project.
