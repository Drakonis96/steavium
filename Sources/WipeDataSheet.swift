import SwiftUI

struct WipeDataSheet: View {
    @ObservedObject var viewModel: StoreViewModel
    @Binding var isPresented: Bool
    @Binding var wipeAccountData: Bool
    @Binding var wipeLibraryData: Bool
    @State private var showingWipeConfirmation: Bool = false

    private var language: AppLanguage { viewModel.language }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(L.selectiveDataWipe.resolve(in: language))
                .font(.title3.weight(.semibold))
            Text(L.wipeDataWarning.resolve(in: language))
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Toggle(
                L.removeAccountData.resolve(in: language),
                isOn: $wipeAccountData
            )
            Toggle(
                L.removeLibraryData.resolve(in: language),
                isOn: $wipeLibraryData
            )

            HStack {
                Spacer()
                Button(L.cancel.resolve(in: language)) {
                    showingWipeConfirmation = false
                    isPresented = false
                }
                .buttonStyle(ResponsiveBorderedStyle())
                Button(L.deleteSelection.resolve(in: language)) {
                    showingWipeConfirmation = true
                }
                .buttonStyle(ResponsiveBorderedProminentStyle())
                .disabled(viewModel.isBusy || (!wipeAccountData && !wipeLibraryData))
            }
        }
        .padding(20)
        .frame(width: 560)
        .confirmationDialog(
            L.confirmDataWipe.resolve(in: language),
            isPresented: $showingWipeConfirmation,
            titleVisibility: .visible
        ) {
            Button(L.deleteSelection.resolve(in: language), role: .destructive) {
                showingWipeConfirmation = false
                isPresented = false
                viewModel.wipeStoreData(
                    clearAccountData: wipeAccountData,
                    clearLibraryData: wipeLibraryData
                )
            }
            Button(L.cancel.resolve(in: language), role: .cancel) {
                showingWipeConfirmation = false
            }
        } message: {
            Text(L.wipeConfirmMessage.resolve(in: language))
        }
    }
}
