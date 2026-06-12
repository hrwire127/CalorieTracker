import SwiftUI

struct SettingsView: View {
    @AppStorage("GeminiApiKey") private var geminiApiKey: String = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("API Settings"), footer: Text("The API key is stored locally on your device and used to communicate with Google Gemini services for estimating calories.")) {
                    SecureField("Gemini API Key", text: $geminiApiKey)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                }
            }
            .navigationTitle("Settings")
        }
    }
}

#Preview {
    SettingsView()
}
