import SwiftUI
import HealthCore
import HealthKit

struct ContentView: View {

    @State private var shouldShowUnsuccessfulAuthorizationErrorAlert: Bool = false
    private let healthCoreProvider: HealthCoreProvider

    var body: some View {
        VStack {
            Button {
                Task {
                    await writeData()
                }
            } label: {
                Text("Tap to write data to health store!")
            }
            .alert("Error during health kit authorization", isPresented: $shouldShowUnsuccessfulAuthorizationErrorAlert) {
                Button("OK", role: .cancel) { }
            }
            Button {
                Task {
                    await readData()
                }
            } label: {
                Text("Tap to read data from health store!")
            }
            .alert("Error during health kit authorization", isPresented: $shouldShowUnsuccessfulAuthorizationErrorAlert) {
                Button("OK", role: .cancel) { }
            }
        }
    }

    init() {
        self.healthCoreProvider = HealthCoreProvider(
            dataTypesToRead: [
                HKQuantityType.quantityType(forIdentifier: HKQuantityTypeIdentifier.heartRate)!,
                HKQuantityType.quantityType(forIdentifier: HKQuantityTypeIdentifier.activeEnergyBurned)!
            ],
            dataTypesToWrite: [
                HKObjectType.categoryType(forIdentifier: HKCategoryTypeIdentifier.sleepAnalysis)!
            ],
            healthCoreProviderErrorHandler: { error in
                switch error {
                case .unsuccessfulAuthorizationError:
                    print("unsuccessfulAuthorizationError")
                case .unsuccessfulSavingDataToHealthStore:
                    print("unsuccessfulSavingDataToHealthStore")
                case .unsuccessfulWritingDataToHealthStore:
                    print("unsuccessfulWritingDataToHealthStore")
                }
            }
        )
    }

    private func readData() async {
        print("reading data...")
    }

    private func writeData() async {
        await healthCoreProvider.writeDataToHealthStore(
            data: [
                HKCategorySample(
                    type: HKObjectType.categoryType(forIdentifier: HKCategoryTypeIdentifier.sleepAnalysis)!,
                    value: HKCategoryValueSleepAnalysis.asleep.rawValue,
                    start: Date(),
                    end: Date()
                )
            ],
            objectType: HKSampleType.categoryType(forIdentifier: .sleepAnalysis)!
        )
    }

}
