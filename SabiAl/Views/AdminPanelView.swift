//
//  AdminGateView.swift
//  SabiAl
//

import SwiftUI

// MARK: - PIN gate

/// Guards the admin panel behind a local PIN. The default PIN is 1234
/// and can be changed from inside the panel itself.
struct AdminGateView: View {
    @ObservedObject var viewModel: ChatViewModel

    @AppStorage(BotSettings.Keys.adminPIN) private var storedPIN = BotSettings.Defaults.adminPIN

    @State private var unlocked = false
    @State private var entry = ""
    @State private var wrongPIN = false

    var body: some View {
        if unlocked {
            AdminPanelView(viewModel: viewModel, onLock: { unlocked = false })
        } else {
            lockScreen
        }
    }

    private var lockScreen: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "lock.shield")
                .font(.system(size: 56, weight: .light))
                .foregroundStyle(Color.accentColor)

            Text("Admin")
                .font(.largeTitle.weight(.bold))

            Text("Vendosni kodin PIN për të hyrë në panelin e administrimit.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            SecureField("Kodi PIN", text: $entry)
                .textFieldStyle(.roundedBorder)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 220)
                .submitLabel(.go)
                .onSubmit(tryUnlock)

            Button {
                tryUnlock()
            } label: {
                Text("Hyr")
                    .frame(maxWidth: 220)
            }
            .buttonStyle(.borderedProminent)

            if wrongPIN {
                Text("Kod i gabuar, provoni përsëri.")
                    .font(.footnote)
                    .foregroundStyle(.red)
            }

            Spacer()
            Spacer()
        }
        .padding()
    }

    private func tryUnlock() {
        if entry == storedPIN {
            entry = ""
            wrongPIN = false
            withAnimation(.snappy) { unlocked = true }
        } else {
            wrongPIN = true
            entry = ""
        }
    }
}

// MARK: - Admin panel

/// Full control of the bot: identity, personality, connection details,
/// security and data. Every change here takes effect immediately in the chat.
struct AdminPanelView: View {
    @ObservedObject var viewModel: ChatViewModel
    let onLock: () -> Void

    @AppStorage(BotSettings.Keys.botName) private var botName = BotSettings.Defaults.botName
    @AppStorage(BotSettings.Keys.greeting) private var greeting = BotSettings.Defaults.greeting
    @AppStorage(BotSettings.Keys.systemPrompt) private var systemPrompt = BotSettings.Defaults.systemPrompt
    @AppStorage(BotSettings.Keys.endpoint) private var endpoint = BotSettings.Defaults.endpoint
    @AppStorage(BotSettings.Keys.model) private var model = BotSettings.Defaults.model
    @AppStorage(BotSettings.Keys.temperature) private var temperature = BotSettings.Defaults.temperature
    @AppStorage(BotSettings.Keys.adminPIN) private var adminPIN = BotSettings.Defaults.adminPIN
    @AppStorage(BotSettings.Keys.aiEngine) private var engine = BotSettings.Defaults.aiEngine

    @State private var newPIN = ""
    @State private var pinSavedNotice = false

    var body: some View {
        NavigationStack {
            Form {
                identitySection
                connectionSection
                securitySection
                dataSection
                aboutSection
            }
            .navigationTitle("Paneli i Admin-it")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Dil", action: onLock)
                }
            }
        }
    }

    // MARK: Sections

    private var identitySection: some View {
        Section {
            LabeledContent("Emri i bot-it") {
                TextField("Sabi", text: $botName)
                    .multilineTextAlignment(.trailing)
            }
            TextField("Mesazhi i përshëndetjes", text: $greeting, axis: .vertical)

            VStack(alignment: .leading, spacing: 6) {
                Text("Personaliteti (udhëzimi sistemit)")
                    .font(.subheadline.weight(.medium))
                TextEditor(text: $systemPrompt)
                    .frame(minHeight: 90)
                    .font(.callout)
                    .scrollContentBackground(.hidden)
                    .padding(8)
                    .background(Color(.secondarySystemBackground), in: .rect(cornerRadius: 8))
            }
            .padding(.vertical, 4)
        } header: {
            Text("Identiteti i bot-it")
        } footer: {
            Text("Personaliteti përcakton si flet bot-i. Ndryshimet hyjnë në fuqi menjëherë.")
        }
    }

    private var connectionSection: some View {
        Section {
            Picker("Motori i AI-së", selection: $engine) {
                Text("Apple Intelligence (pa pagesë)").tag("apple")
                Text("OpenAI API (me çelës)").tag("openai")
            }

            if engine == "apple" {
                if let reason = AIService.appleAvailabilityReason {
                    Label(reason, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.orange)
                } else {
                    Label("Gati — funksionon në pajisje, pa çelës dhe pa pagesë.", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }
            } else {
                TextField("Adresa e API-së", text: $endpoint)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                TextField("Modeli (p.sh. gpt-4o-mini)", text: $model)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                LabeledContent("Çelësi i API-së") {
                    if ApiKeyManager.shared.has(key: "OPENAI_API_KEY") {
                        Label("Konfiguruar", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    } else {
                        Label("Mangëst", systemImage: "exclamationmark.circle")
                            .foregroundStyle(.orange)
                    }
                }
            }

            LabeledContent("Kreativiteti") {
                Slider(value: $temperature, in: 0...1.5, step: 0.1)
                    .frame(maxWidth: 160)
                Text(temperature.formatted(.number.precision(.fractionLength(1))))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("Lidhja me AI-në")
        } footer: {
            Text("""
                Apple Intelligence punon vetë në iPhone — është pa pagesë dhe pa çelës. \
                Nëse zgjidhet OpenAI, çelësi OPENAI_API_KEY futet vetëm një herë, \
                nëpërmjet kartës së çelësit që shfaqet në aplikacion. \
                Kreativiteti i lë lirinë përgjigjeve.
                """)
        }
    }

    private var securitySection: some View {
        Section {
            SecureField("Kodi i ri PIN", text: $newPIN)
                .keyboardType(.numberPad)

            Button("Ruaj kodin e ri") {
                let pin = newPIN.trimmingCharacters(in: .whitespaces)
                guard pin.count >= 4 else { return }
                adminPIN = pin
                newPIN = ""
                pinSavedNotice = true
            }
            .disabled(newPIN.trimmingCharacters(in: .whitespaces).count < 4)
        } header: {
            Text("Siguria")
        } footer: {
            Text(pinSavedNotice
                 ? "Kodi u ruajt. Përdoreni herën tjetër kur hyni si admin."
                 : "Kodi PIN duhet të ketë së paku 4 shifra.")
        }
    }

    private var dataSection: some View {
        Section("Të dhënat") {
            Button("Rinis bisedën me përshëndetjen e re") {
                viewModel.restartWithCurrentGreeting()
            }
            Button("Fshi gjithë historikun e bisedës", role: .destructive) {
                viewModel.clearHistory()
            }
        }
    }

    private var aboutSection: some View {
        Section("Rreth aplikacionit") {
            LabeledContent("Aplikacioni", value: "SabiAl")
            LabeledContent("Versioni", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
        }
    }
}

#Preview {
    AdminGateView(viewModel: ChatViewModel())
        .tint(Color(red: 0.05, green: 0.68, blue: 0.64))
}
