import SwiftUI

struct SettingsView: View {
    @AppStorage("OpenAIApiKey") private var openAIApiKey: String = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("API Settings"), footer: Text("The API key is stored locally on your device and used to communicate with OpenAI services for estimating calories.")) {
                    SecureField("OpenAI API Key", text: $openAIApiKey)
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
