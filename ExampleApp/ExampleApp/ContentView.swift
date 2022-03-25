import SwiftUI
import HealthCore
import SleepCore
import HealthKit
import Logger

struct ContentView: View {

    // MARK: - Private properties

    @State private var shouldShowUnsuccessfulAuthorizationErrorAlert: Bool = false
    @State private var shouldShowUnsuccessfulWritingErrorAlert: Bool = false
    @State private var shouldShowUnsuccessfulReadingErrorAlert: Bool = false

    private let healthCoreProvider: HealthCoreProvider
    private let sleepCoreProvider: SleepCoreProvider

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
                Task { await self.readWorkoutData() }
            } label: {
                Label {
                    Text("Read workout data from HealthStore")
                } icon: {
                    Image(systemName: "arrow.down.heart.fill")
                        .foregroundColor(.red)
                }
            }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal)

            Button {
                Task { await self.writeData() }
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
                Task { await self.readData() }
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

            Button {
                Task { await self.readSleep() }
            } label: {
                Label {
                    Text("Read sleep from HealthStore")
                } icon: {
                    Image(systemName: "arrow.up.heart.fill")
                        .foregroundColor(.red)
                }
            }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal)


            Spacer()
        }
        .alert("Error during HealthStore authorization", isPresented: self.$shouldShowUnsuccessfulAuthorizationErrorAlert) {
            Button("OK", role: .cancel) { }
        }
        .alert("Error during reading from HealthStore", isPresented: self.$shouldShowUnsuccessfulReadingErrorAlert) {
            Button("OK", role: .cancel) { }
        }
        .alert("Error during writing to HealthStore", isPresented: self.$shouldShowUnsuccessfulWritingErrorAlert) {
            Button("OK", role: .cancel) { }
        }
    }

    // MARK: - Init

    init() {
        let neededDataTypes: Set<HealthCoreProvider.SampleType> = [
            .quantityType(forIdentifier: .heartRate),
            .quantityType(forIdentifier: .activeEnergyBurned),
            .categoryType(forIdentifier: .sleepAnalysis, categoryValue: 0),
            .workoutType
        ]
        self.healthCoreProvider = HealthCoreProvider(
            dataTypesToRead: neededDataTypes,
            dataTypesToWrite: neededDataTypes
        )

        self.sleepCoreProvider = SleepCoreProvider(healthCoreProvider: self.healthCoreProvider)
    }

    // MARK: - Private properties

    private func readWorkoutData() async {
        do {
            let today = Date()
            let data = try await self.healthCoreProvider.readData(
                sampleType: .workoutType,
                dateInterval: DateInterval(
                    start: Calendar.current.date(byAdding: .day, value: -100, to: today)!,
                    end: today
                )
            )
            if let workout = data?.first as? HKWorkout {
                print(workout)
            }
        } catch {
            self.shouldShowUnsuccessfulAuthorizationErrorAlert.toggle()
        }
    }

    private func readData() async {
        do {
            let data = try await self.healthCoreProvider.readData(
                sampleType: .quantityType(forIdentifier: .heartRate),
                dateInterval: DateInterval(
                    start: Date.distantPast,
                    end: Date.distantFuture
                ),
                ascending: false,
                limit: 10,
                queryOptions: []
            )
            print(data?.description ?? "")
        } catch {
            self.shouldShowUnsuccessfulAuthorizationErrorAlert.toggle()
        }
    }

    private func writeData() async {
        do {
            try await self.healthCoreProvider.writeData(
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
                ]
            )
        } catch {
            self.shouldShowUnsuccessfulAuthorizationErrorAlert.toggle()
        }
    }

    private func readSleep() async {
        do {
            let sleep = try await self.sleepCoreProvider.retrieveLastSleep()
            print("Sleep durationn")
            print(sleep.inbedInterval?.duration)
        } catch {
            self.shouldShowUnsuccessfulAuthorizationErrorAlert.toggle()
        }
    }
}
