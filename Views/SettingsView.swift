import PhotosUI
import SwiftUI
import UIKit

struct SettingsView: View {
    @AppStorage("GeminiApiKey") private var geminiApiKey: String = ""
    @AppStorage("ProfileName") private var profileName: String = ""
    @AppStorage("ProfileWeightKg") private var profileWeightKg: String = ""
    @AppStorage("ProfileHeightCm") private var profileHeightCm: String = ""
    @AppStorage("ProfileAbout") private var profileAbout: String = ""
    @AppStorage("ProfileBirthDateTimestamp") private var profileBirthDateTimestamp: Double = 631_152_000
    @AppStorage("ProfileImageData") private var profileImageData: Data = Data()
    @AppStorage("AppThemePreference") private var appThemePreference = AppThemePreference.system.rawValue

    @State private var selectedProfilePhoto: PhotosPickerItem?

    var body: some View {
        NavigationStack {
            Form {
                profilePhotoSection
                personalDetailsSection
                appearanceSection
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
            TextField("Name", text: $profileName)
                .textInputAutocapitalization(.words)

            TextField("Weight (kg)", text: $profileWeightKg)
                .keyboardType(.decimalPad)

            TextField("Height (cm)", text: $profileHeightCm)
                .keyboardType(.decimalPad)

            DatePicker(
                "Birth Date",
                selection: birthDateBinding,
                displayedComponents: .date
            )

            VStack(alignment: .leading, spacing: 8) {
                Text("About Me")
                    .foregroundStyle(.secondary)

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
            footer: Text("The API key is stored locally on your device and used to communicate with Google Gemini services for estimating calories.")
        ) {
            SecureField("Gemini API Key", text: $geminiApiKey)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
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

    @MainActor
    private func loadProfilePhoto(from item: PhotosPickerItem) async {
        guard let data = try? await item.loadTransferable(type: Data.self),
              let image = UIImage(data: data),
              let compressedData = image.jpegData(compressionQuality: 0.82) else {
            return
        }

        profileImageData = compressedData
    }
}

#Preview {
    SettingsView()
}
