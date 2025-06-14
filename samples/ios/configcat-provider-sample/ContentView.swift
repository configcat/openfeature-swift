import SwiftUI
import ConfigCatOpenFeature
import OpenFeature
import ConfigCat

struct ContentView: View {
    @State private var text = ""
    
    var body: some View {
        VStack {
            Image(systemName: "globe")
                .imageScale(.large)
                .foregroundStyle(.tint)
            Text("Welcome to ConfigCat / OpenFeature!")
            Text(text)
        }
        .padding()
        .task {
            await OpenFeatureAPI.shared.setProviderAndWait(
                provider: ConfigCatProvider(sdkKey: "PKDVCLf-Hq-h-kCzMp-L7Q/HhOWfwVtZ0mb30i9wi17GQ") { opts in
                    // Info level logging helps to inspect the feature flag evaluation process.
                    // Use the default Warning level to avoid too detailed logging in your application.
                    opts.logLevel = .info
            }, initialContext: MutableContext(targetingKey: "configcat@example.com", structure: MutableStructure(attributes: [
                "Email": Value.string("configcat@example.com"),
            ])))
            
            let client = OpenFeatureAPI.shared.getClient()
            
            let value = client.getBooleanValue(key: "isPOCFeatureEnabled", defaultValue: false)
            text = "isPOCFeatureEnabled: \(value)"
        }
    }
}

#Preview {
    ContentView()
}
