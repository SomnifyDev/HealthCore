import SwiftUI
import HealthCore
import HealthKit
import Logger

struct ContentView: View {

    // MARK: - Private properties

    @State private var shouldShowUnsuccessfulAuthorizationErrorAlert: Bool = false
    @State private var shouldShowUnsuccessfulWritingErrorAlert: Bool = false
    @State private var shouldShowUnsuccessfulReadingErrorAlert: Bool = false
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
                Label {
                    Text("Write data to HealthStore")
                } icon: {
                    Image(systemName: "arrow.up.heart.fill")
                        .foregroundColor(.red)
                }
            }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal)

            Button {
                Task { await readData() }
            } label: {
                Label {
                    Text("Read data from HealthStore")
                } icon: {
                    Image(systemName: "arrow.down.heart.fill")
                        .foregroundColor(.red)
                }
            }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal)

            Spacer()
        }
        .alert("Error during HealthStore authorization", isPresented: $shouldShowUnsuccessfulAuthorizationErrorAlert) {
            Button("OK", role: .cancel) { }
        }
        .alert("Error during reading from HealthStore", isPresented: $shouldShowUnsuccessfulReadingErrorAlert) {
            Button("OK", role: .cancel) { }
        }
        .alert("Error during writing to HealthStore", isPresented: $shouldShowUnsuccessfulWritingErrorAlert) {
            Button("OK", role: .cancel) { }
        }
    }

    // MARK: - Init

    init() {
        let neededDataTypes: Set<HKSampleType> = [
            HKQuantityType(.heartRate),
            HKQuantityType(.activeEnergyBurned),
            HKCategoryType(.sleepAnalysis)
        ]
        self.healthCoreProvider = HealthCoreProvider(
            dataTypesToRead: neededDataTypes,
            dataTypesToWrite: neededDataTypes
        )
    }

    // MARK: - Private properties

    private func readData() async {
        let data = await healthCoreProvider.readData(
            sampleType: HKQuantityType(.heartRate),
            dateInterval: DateInterval(
                start: Date.distantPast,
                end: Date.distantFuture
            ),
            ascending: false,
            limit: 10,
            queryOptions: [],
            readingErrorHandler: {
                shouldShowUnsuccessfulReadingErrorAlert.toggle()
            },
            authorizationErrorHandler: {
                shouldShowUnsuccessfulAuthorizationErrorAlert.toggle()
            }
        )
        print(data?.description ?? "")
    }

    private func writeData() async {
        await healthCoreProvider.writeData(
            data: [
                HKCategorySample(
                    type: HKObjectType.categoryType(forIdentifier: HKCategoryTypeIdentifier.sleepAnalysis)!,
                    value: HKCategoryValueSleepAnalysis.asleep.rawValue,
                    start: Date(),
                    end: Date()
                ),
                HKQuantitySample(
                    type: HKQuantityType(.heartRate),
                    quantity: HKQuantity(unit: .countMin(), doubleValue: 55.0),
                    start: Date(),
                    end: Date()
                )
            ],
            writingErrorHandler: {
                shouldShowUnsuccessfulWritingErrorAlert.toggle()
            },
            authorizationErrorHandler: {
                shouldShowUnsuccessfulAuthorizationErrorAlert.toggle()
            }
        )
    }

}
