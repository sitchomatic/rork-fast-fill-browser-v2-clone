import SwiftUI

struct ContentView: View {
    @State private var biometricService = BiometricService()
    @AppStorage("requireBiometricOnLaunch") private var requireBiometric: Bool = true

    var body: some View {
        Group {
            if requireBiometric && !biometricService.isUnlocked {
                LockScreenView(biometricService: biometricService)
            } else {
                BrowserView(biometricService: biometricService)
            }
        }
        .task {
            biometricService.checkBiometricAvailability()
            if !requireBiometric {
                biometricService.isUnlocked = true
            }
        }
    }
}
