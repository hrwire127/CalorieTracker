import PhotosUI
import SwiftData
import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext

    @AppStorage("GeminiApiKey") private var geminiApiKey: String = ""
    @AppStorage("ProfileName") private var profileName: String = ""
    @AppStorage("ProfileWeightKg") private var profileWeightKg: String = ""
    @AppStorage("ProfileHeightCm") private var profileHeightCm: String = ""
    @AppStorage("ProfileAbout") private var profileAbout: String = ""
    @AppStorage("ProfileBirthDateTimestamp") private var profileBirthDateTimestamp: Double = 631_152_000
    @AppStorage("ProfileSex") private var profileSex = ProfileSex.unspecified.rawValue
    @AppStorage("ProfileActivityLevel") private var profileActivityLevel = ActivityLevel.sedentary.rawValue
    @AppStorage("ProfileImageData") private var profileImageData: Data = Data()
    @AppStorage("AppThemePreference") private var appThemePreference = AppThemePreference.system.rawValue
    @AppStorage("GeminiSelectedModel") private var selectedGeminiModel = GeminiModelOption.defaultOption.rawValue

    @State private var selectedProfilePhoto: PhotosPickerItem?
    @State private var backupDocument = BackupDocument()
    @State private var isExportingBackup = false
    @State private var isImportingBackup = false
    @State private var pendingImportData: Data?
    @State private var isShowingImportConfirmation = false
    @State private var backupMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                profilePhotoSection
                personalDetailsSection
                appearanceSection
                backupSection
                apiSection
            }
            .navigationTitle("Settings")
            .onChange(of: selectedProfilePhoto) { _, newItem in
                guard let newItem else {
                    return
                }

                Task {
                    await loadProfilePhoto(from: newItem)
                }
            }
            .fileExporter(
                isPresented: $isExportingBackup,
                document: backupDocument,
                contentType: .json,
                defaultFilename: BackupManager.fileName
            ) { result in
                switch result {
                case .success:
                    backupMessage = "Backup exported successfully."
                case .failure(let error):
                    backupMessage = "Export failed. \(error.localizedDescription)"
                }
            }
            .fileImporter(
                isPresented: $isImportingBackup,
                allowedContentTypes: [.json],
                allowsMultipleSelection: false
            ) { result in
                handleImportSelection(result)
            }
            .confirmationDialog(
                "Import Backup?",
                isPresented: $isShowingImportConfirmation,
                titleVisibility: .visible
            ) {
                Button("Replace Current Data", role: .destructive) {
                    importPendingBackup()
                }

                Button("Cancel", role: .cancel) {
                    pendingImportData = nil
                }
            } message: {
                Text("This will replace the current meals, goals, profile, and settings with the data from the backup file.")
            }
            .alert("Backup", isPresented: backupMessageBinding) {
                Button("OK", role: .cancel) {
                    backupMessage = nil
                }
            } message: {
                Text(backupMessage ?? "")
            }
        }
    }

    private var profilePhotoSection: some View {
        Section("Profile") {
            HStack(spacing: 16) {
                profileImage
                    .frame(width: 74, height: 74)

                VStack(alignment: .leading, spacing: 8) {
                    Text(profileName.isEmpty ? "Your Profile" : profileName)
                        .font(.headline)

                    PhotosPicker(selection: $selectedProfilePhoto, matching: .images) {
                        Label(profileImageData.isEmpty ? "Add Photo" : "Change Photo", systemImage: "photo")
                    }

                    if !profileImageData.isEmpty {
                        Button("Remove Photo", role: .destructive) {
                            profileImageData = Data()
                            selectedProfilePhoto = nil
                        }
                        .font(.footnote)
                    }
                }
            }
            .padding(.vertical, 6)
        }
    }

    private var personalDetailsSection: some View {
        Section("About You") {
            SettingsTextFieldRow(
                title: "Name",
                placeholder: "Name",
                systemImage: "person.fill",
                tint: .blue,
                text: $profileName,
                keyboardType: .default
            )
            .textInputAutocapitalization(.words)

            SettingsTextFieldRow(
                title: "Weight",
                placeholder: "kg",
                systemImage: "scalemass.fill",
                tint: .teal,
                text: $profileWeightKg,
                keyboardType: .decimalPad
            )

            SettingsTextFieldRow(
                title: "Height",
                placeholder: "cm",
                systemImage: "ruler.fill",
                tint: .indigo,
                text: $profileHeightCm,
                keyboardType: .decimalPad
            )

            HStack(spacing: 10) {
                FieldIcon(systemName: "calendar", tint: .orange)
                DatePicker(
                    "Birth Date",
                    selection: birthDateBinding,
                    displayedComponents: .date
                )
            }

            HStack(spacing: 10) {
                FieldIcon(systemName: "figure.stand", tint: .purple)
                Picker("Sex", selection: $profileSex) {
                    ForEach(ProfileSex.allCases) { sex in
                        Text(sex.title)
                            .tag(sex.rawValue)
                    }
                }
            }

            HStack(spacing: 10) {
                FieldIcon(systemName: "figure.run", tint: .green)
                Picker("Activity", selection: $profileActivityLevel) {
                    ForEach(ActivityLevel.allCases) { activityLevel in
                        Text(activityLevel.title)
                            .tag(activityLevel.rawValue)
                    }
                }
            }

            if let maintenanceCalories {
                HStack(spacing: 10) {
                    FieldIcon(systemName: "speedometer", tint: .red)
                    LabeledContent("Maintenance", value: "\(maintenanceCalories) kcal/day")
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 10) {
                    FieldIcon(systemName: "note.text", tint: .cyan)
                    Text("About Me")
                        .foregroundStyle(.secondary)
                }

                TextEditor(text: $profileAbout)
                    .frame(minHeight: 96)
            }
        }
    }

    private var appearanceSection: some View {
        Section("Appearance") {
            Picker("Theme", selection: $appThemePreference) {
                ForEach(AppThemePreference.allCases) { preference in
                    Text(preference.title)
                        .tag(preference.rawValue)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    private var apiSection: some View {
        Section(
            header: Text("API Settings"),
            footer: Text("The API key and selected model are stored locally on your device. Change the model here, then retry AI Scan or AI Guess.")
        ) {
            SecureField("Gemini API Key", text: $geminiApiKey)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

            HStack(spacing: 10) {
                FieldIcon(systemName: "cpu.fill", tint: .purple)
                Picker("AI Model", selection: selectedGeminiModelBinding) {
                    ForEach(GeminiModelOption.allCases) { option in
                        Text(option.title)
                            .tag(option.rawValue)
                    }
                }
            }

            Label(selectedGeminiModelOption.detail, systemImage: "info.circle")
                .font(.footnote)
                .foregroundStyle(.secondary)

            if geminiApiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Label("Required for AI Scan and AI Guess", systemImage: "exclamationmark.circle")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                Label("API key saved on this device", systemImage: "checkmark.circle.fill")
                    .font(.footnote)
                    .foregroundStyle(.green)
            }
        }
    }

    private var backupSection: some View {
        Section(
            header: Text("Backup"),
            footer: Text("Export a backup before deleting the app. The Gemini API key is not included and must be entered again after reinstalling.")
        ) {
            Button {
                exportBackup()
            } label: {
                Label("Export Backup", systemImage: "square.and.arrow.up")
            }

            Button {
                isImportingBackup = true
            } label: {
                Label("Import Backup", systemImage: "square.and.arrow.down")
            }
        }
    }

    @ViewBuilder
    private var profileImage: some View {
        if let image = UIImage(data: profileImageData) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .clipShape(Circle())
                .overlay {
                    Circle()
                        .strokeBorder(Color.secondary.opacity(0.18), lineWidth: 1)
                }
        } else {
            ZStack {
                Circle()
                    .fill(Color.secondary.opacity(0.14))

                Image(systemName: "person.crop.circle.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var birthDateBinding: Binding<Date> {
        Binding {
            Date(timeIntervalSince1970: profileBirthDateTimestamp)
        } set: { newDate in
            profileBirthDateTimestamp = newDate.timeIntervalSince1970
        }
    }

    private var maintenanceCalories: Int? {
        NutritionCalculator.maintenanceCalories(
            weightKgText: profileWeightKg,
            heightCmText: profileHeightCm,
            birthDateTimestamp: profileBirthDateTimestamp,
            sexRawValue: profileSex,
            activityRawValue: profileActivityLevel
        )
    }

    private var selectedGeminiModelOption: GeminiModelOption {
        GeminiModelOption.option(for: selectedGeminiModel)
    }

    private var selectedGeminiModelBinding: Binding<String> {
        Binding {
            selectedGeminiModelOption.rawValue
        } set: { newValue in
            selectedGeminiModel = GeminiModelOption.option(for: newValue).rawValue
        }
    }

    private var backupMessageBinding: Binding<Bool> {
        Binding {
            backupMessage != nil
        } set: { isPresented in
            if !isPresented {
                backupMessage = nil
            }
        }
    }

    @MainActor
    private func loadProfilePhoto(from item: PhotosPickerItem) async {
        guard let data = try? await item.loadTransferable(type: Data.self),
              let image = UIImage(data: data),
              let compressedData = image.jpegData(compressionQuality: 0.82) else {
            return
        }

        profileImageData = compressedData
    }

    private func exportBackup() {
        do {
            let data = try BackupManager.exportBackup(using: modelContext)
            backupDocument = BackupDocument(data: data)
            isExportingBackup = true
        } catch {
            backupMessage = "Export failed. \(error.localizedDescription)"
        }
    }

    private func handleImportSelection(_ result: Result<[URL], Error>) {
        do {
            guard let url = try result.get().first else {
                return
            }

            let didStartAccessing = url.startAccessingSecurityScopedResource()
            defer {
                if didStartAccessing {
                    url.stopAccessingSecurityScopedResource()
                }
            }

            pendingImportData = try Data(contentsOf: url)
            isShowingImportConfirmation = true
        } catch {
            backupMessage = "Import failed. \(error.localizedDescription)"
        }
    }

    private func importPendingBackup() {
        guard let pendingImportData else {
            return
        }

        do {
            try BackupManager.importBackup(from: pendingImportData, using: modelContext)
            self.pendingImportData = nil
            backupMessage = "Backup imported successfully."
        } catch {
            backupMessage = "Import failed. \(error.localizedDescription)"
        }
    }
}

private struct SettingsTextFieldRow: View {
    let title: String
    let placeholder: String
    let systemImage: String
    let tint: Color
    @Binding var text: String
    let keyboardType: UIKeyboardType

    var body: some View {
        HStack(spacing: 10) {
            FieldIcon(systemName: systemImage, tint: tint)

            Text(title)
                .foregroundStyle(.secondary)

            TextField(placeholder, text: $text)
                .keyboardType(keyboardType)
                .multilineTextAlignment(.trailing)
        }
    }
}

#Preview {
    SettingsView()
}
