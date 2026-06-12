import SwiftUI
import PhotosUI

struct ManualEntryView: View {
    @Environment(\.dismiss) private var dismiss
    @FocusState private var focusedField: Field?

    @State private var foodName = ""
    @State private var caloriesText = ""
    @State private var gramsText = ""
    @State private var validationMessage: String?
    
    @State private var selectedItem: PhotosPickerItem? = nil
    @State private var selectedImageData: Data? = nil

    let onSave: (String, Int, Int?, Data?) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("Food Details") {
                    TextField("Food Name", text: $foodName)
                        .textInputAutocapitalization(.words)
                        .focused($focusedField, equals: .name)

                    TextField("Calories", text: $caloriesText)
                        .keyboardType(.numberPad)
                        .focused($focusedField, equals: .calories)

                    TextField("Grams (Optional)", text: $gramsText)
                        .keyboardType(.numberPad)
                        .focused($focusedField, equals: .grams)
                }
                
                Section("Image (Optional)") {
                    HStack {
                        Spacer()
                        VStack(spacing: 12) {
                            if let selectedImageData, let uiImage = UIImage(data: selectedImageData) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 150, height: 150)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                    .shadow(radius: 4)
                            }
                            
                            PhotosPicker(
                                selection: $selectedItem,
                                matching: .images,
                                photoLibrary: .shared()
                            ) {
                                Label(selectedImageData == nil ? "Add Photo" : "Change Photo", systemImage: "photo")
                                    .font(.headline)
                            }
                            .onChange(of: selectedItem) { _, newItem in
                                Task {
                                    if let data = try? await newItem?.loadTransferable(type: Data.self) {
                                        selectedImageData = data
                                    }
                                }
                            }
                            
                            if selectedImageData != nil {
                                Button("Remove Photo", role: .destructive) {
                                    selectedItem = nil
                                    selectedImageData = nil
                                }
                                .font(.footnote)
                            }
                        }
                        Spacer()
                    }
                    .padding(.vertical, 8)
                }

                if let validationMessage {
                    Section {
                        Text(validationMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Manual Entry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        save()
                    }
                    .disabled(!canSave)
                }
            }
            .onAppear {
                focusedField = .name
            }
        }
    }

    private var canSave: Bool {
        FoodEntryValidator.canSave(
            name: foodName,
            caloriesText: caloriesText,
            gramsText: gramsText
        )
    }

    private func save() {
        do {
            let entry = try FoodEntryValidator.validate(
                name: foodName,
                caloriesText: caloriesText,
                gramsText: gramsText
            )
            onSave(entry.name, entry.calories, entry.grams, selectedImageData)
            dismiss()
        } catch {
            validationMessage = error.localizedDescription
        }
    }

    private enum Field: Hashable {
        case name
        case calories
        case grams
    }
}
