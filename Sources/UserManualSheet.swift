import SwiftUI

struct UserManualSheet: View {
    let language: AppLanguage
    @Binding var isPresented: Bool

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text(L.beginnerManual.resolve(in: language))
                        .font(.title2.weight(.bold))

                    Text(L.manualIntro.resolve(in: language))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    ManualSectionCard(
                        title: L.manualPart1Title.resolve(in: language),
                        summary: L.manualPart1Summary.resolve(in: language),
                        steps: [
                            L.manualPart1Step1.resolve(in: language),
                            L.manualPart1Step2.resolve(in: language),
                            L.manualPart1Step3.resolve(in: language),
                        ]
                    )

                    ManualSectionCard(
                        title: L.manualPart2Title.resolve(in: language),
                        summary: L.manualPart2Summary.resolve(in: language),
                        steps: [
                            L.manualPart2Step1.resolve(in: language),
                            L.manualPart2Step2.resolve(in: language),
                            L.manualPart2Step3.resolve(in: language),
                            L.manualPart2Step4.resolve(in: language),
                        ]
                    )

                    ManualSectionCard(
                        title: L.manualPart3Title.resolve(in: language),
                        summary: L.manualPart3Summary.resolve(in: language),
                        steps: [
                            L.manualPart3Step1.resolve(in: language),
                            L.manualPart3Step2.resolve(in: language),
                            L.manualPart3Step3.resolve(in: language),
                        ]
                    )

                    ManualSectionCard(
                        title: L.manualPart4Title.resolve(in: language),
                        summary: L.manualPart4Summary.resolve(in: language),
                        steps: [
                            L.manualPart4Step1.resolve(in: language),
                            L.manualPart4Step2.resolve(in: language),
                            L.manualPart4Step3.resolve(in: language),
                        ]
                    )

                    ManualSectionCard(
                        title: L.manualPart5Title.resolve(in: language),
                        summary: L.manualPart5Summary.resolve(in: language),
                        steps: [
                            L.manualPart5Step1.resolve(in: language),
                            L.manualPart5Step2.resolve(in: language),
                            L.manualPart5Step3.resolve(in: language),
                        ]
                    )
                }
                .padding(20)
            }
            .navigationTitle(L.userManual.resolve(in: language))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L.close.resolve(in: language)) {
                        isPresented = false
                    }
                }
            }
        }
        .frame(minWidth: 780, minHeight: 640)
    }
}
