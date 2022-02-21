import SwiftUI
import HealthCore
import HealthKit
import Logger

struct ContentView: View {

    // MARK: - Private properties

    @State private var shouldShowUnsuccessfulAuthorizationErrorAlert: Bool = false
    @State private var shouldShowUnsuccessfulWritingErrorAlert: Bool = false
    private let healthCoreProvider: HealthCoreProvider

    // MARK: - Internal properties

    var body: some View {
        VStack {
            HStack {
                Text("HealthCore ExampleApp")
                    .font(.title)
                    .bold()
                    .padding(.top, 32)
                    .padding(.horizontal, 16)
                Spacer()
            }

            Spacer()

            Button {
                Task { await writeData() }
            } label: {
                Text("Tap to write data to health store!")
            }
            .buttonStyle(.borderedProminent)
            .alert("Error during health kit authorization", isPresented: $shouldShowUnsuccessfulAuthorizationErrorAlert) {
                Button("OK", role: .cancel) { }
            }
            .padding(.horizontal)

            Button {
                Task { await readData() }
            } label: {
                Text("Tap to read data from health store!")
            }
            .buttonStyle(.borderedProminent)
            .alert("Error during health kit authorization", isPresented: $shouldShowUnsuccessfulAuthorizationErrorAlert) {
                Button("OK", role: .cancel) { }
            }
            .padding(.horizontal)

            Spacer()
        }
    }

    // MARK: - Init

    init() {
        self.healthCoreProvider = HealthCoreProvider(
            dataTypesToRead: [
                HKQuantityType.quantityType(forIdentifier: HKQuantityTypeIdentifier.heartRate)!,
                HKQuantityType.quantityType(forIdentifier: HKQuantityTypeIdentifier.activeEnergyBurned)!,
                HKObjectType.categoryType(forIdentifier: HKCategoryTypeIdentifier.sleepAnalysis)!
            ],
            dataTypesToWrite: [
                HKQuantityType.quantityType(forIdentifier: HKQuantityTypeIdentifier.heartRate)!,
                HKQuantityType.quantityType(forIdentifier: HKQuantityTypeIdentifier.activeEnergyBurned)!,
                HKObjectType.categoryType(forIdentifier: HKCategoryTypeIdentifier.sleepAnalysis)!
            ]
        )
    }

    // MARK: - Private properties

    private func readData() async {
        Logger.logEvent("Start reading data...", type: .info)
    }

    private func writeData() async {
        await healthCoreProvider.writeData(
            data: [
                HKCategorySample(
                    type: HKObjectType.categoryType(forIdentifier: HKCategoryTypeIdentifier.sleepAnalysis)!,
                    value: HKCategoryValueSleepAnalysis.asleep.rawValue,
                    start: Date(),
                    end: Date()
                )
            ],
            sampleType: HKSampleType.categoryType(forIdentifier: .sleepAnalysis)!,
            writingErrorHandler: {
                shouldShowUnsuccessfulWritingErrorAlert.toggle()
            },
            authorizationErrorHandler: {
                shouldShowUnsuccessfulAuthorizationErrorAlert.toggle()
            }
        )
    }

}
