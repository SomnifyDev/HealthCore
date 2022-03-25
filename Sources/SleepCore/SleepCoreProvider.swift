import Foundation
import HealthCore
import HealthKit
import CommonExtensions

// MARK: - Public types

public enum SleepCoreProviderError: Error {
    case microSleepNotFoundError
    case sleepNotFoundError
    case notEnoughRawDataError
}

// MARK: - SleepCoreProvider

public final class SleepCoreProvider {

    // MARK: - Public types

    public enum Constant {
        public static let minimalAcceptableMicroSleepSamplesDifference = 15
        public static let minimalAcceptableMicroSleepDuration = 30
        public static let maximalAcceptableDifferenceBetweenMicroSleepSamples = 45
    }

    // MARK: - Private properties
    
    private let healthCoreProvider: HealthCoreProvider
    private let lock = NSLock()

    // MARK: - Init

    public init(healthCoreProvider: HealthCoreProvider) {
        self.healthCoreProvider = healthCoreProvider
    }

    // MARK: - Public methods
    
    public func retrieveLastSleep(
        author: HealthCoreProvider.BundleAuthor = .concrete(identifiers: ["com.apple"])
    ) async throws -> Sleep {
        self.lock.lock()
        let currentDate = Date()

        let fetchInterval = DateInterval(
            start: Calendar.current.date(byAdding: .day, value: -3, to: Date())!,
            end: currentDate
        )

        let rawData = try await self.getRawData(dateInterval: fetchInterval, author: author)

        guard
            !(rawData.inbedSamples ?? []).isEmpty,
            !(rawData.asleepSamples ?? []).isEmpty
        else {
            self.lock.unlock()
            throw SleepCoreProviderError.notEnoughRawDataError
        }

        var sleep = Sleep(samples: [])
        var lastMicroSleepStart = currentDate

        var inBedRawFiltered = rawData.inbedSamples
        var asleepRawFiltered = rawData.asleepSamples
        var heartRawFiltered = rawData.heartSamples
        var energyRawFiltered = rawData.energySamples
        var respiratoryRawFiltered = rawData.respiratorySamples

        var isFirstFetch = true

        // запускаем функцию определения последнего микросна сна для отфильтрованных сэмплов
        while true {
            inBedRawFiltered = inBedRawFiltered?.filter { $0.endDate <= lastMicroSleepStart }
            asleepRawFiltered = asleepRawFiltered?.filter { $0.endDate <= lastMicroSleepStart }
            heartRawFiltered = heartRawFiltered?.filter { $0.endDate <= lastMicroSleepStart }
            energyRawFiltered = energyRawFiltered?.filter { $0.endDate <= lastMicroSleepStart }
            respiratoryRawFiltered = respiratoryRawFiltered?.filter { $0.endDate <= lastMicroSleepStart }

            // запускаем функцию определения последнего микросна сна для отфильтрованных сэмплов
            let microSleepDetectionResult = self.detectMicroSleep(
                inbedSamplesRaw: ((inBedRawFiltered ?? []).isEmpty && !(asleepRawFiltered ?? []).isEmpty) ? asleepRawFiltered : inBedRawFiltered,
                asleepSamplesRaw: ((asleepRawFiltered ?? []).isEmpty && !(inBedRawFiltered ?? []).isEmpty) ? inBedRawFiltered : asleepRawFiltered,
                heartSamplesRaw: heartRawFiltered,
                energySamplesRaw: energyRawFiltered,
                respiratoryRaw: respiratoryRawFiltered,
                isFirstFetch: isFirstFetch
            )

            switch microSleepDetectionResult {
            case .success((let asleepInterval, let inbedInterval, let heartSamples, let energySamples, let respiratorySamples)):
                guard
                    abs(asleepInterval.end.minutes(from: lastMicroSleepStart)) <= Constant.maximalAcceptableDifferenceBetweenMicroSleepSamples ||
                        lastMicroSleepStart == currentDate ||
                        sleep.samples.isEmpty
                else {
                    self.lock.unlock()
                    if sleep.samples.isEmpty {
                        throw SleepCoreProviderError.notEnoughRawDataError
                    }
                    return sleep
                }

                lastMicroSleepStart = asleepInterval.start

                if inbedInterval.duration / 60.0 < Double(Constant.minimalAcceptableMicroSleepDuration) {
                    continue
                }

                let _ = energySamples
                let _ = heartSamples
                let _ = respiratorySamples
                let sleepPhases: [SleepPhase] = [] // TODO: - Implement phases detection
                let microSleep = MicroSleep(
                    sleepInterval: asleepInterval,
                    inBedInterval: inbedInterval,
                    phases: sleepPhases
                )

                sleep.samples.append(microSleep)
                isFirstFetch = false
                try await self.saveMicroSleepIfNeeded(microSleep: microSleep)

            case .failure(_):
                self.lock.unlock()
                if sleep.samples.isEmpty {
                    throw SleepCoreProviderError.notEnoughRawDataError
                }
                return sleep
            }
        }
    }

    // MARK: - Private methods
    
    /// Функция для первичного доставания большого количества данных за 2-3 суток, необходимых для выявления последнего зарегистрированного сна
    private func getRawData(
        dateInterval: DateInterval,
        author: HealthCoreProvider.BundleAuthor
    ) async throws -> (
        asleepSamples: [HKSample]?,
        inbedSamples: [HKSample]?,
        heartSamples: [HKSample]?,
        energySamples: [HKSample]?,
        respiratorySamples: [HKSample]?
    ) {
        let asleepSamples = try await self.healthCoreProvider.readData(
            sampleType: .categoryType(
                forIdentifier: .sleepAnalysis,
                categoryValue: HKCategoryValueSleepAnalysis.asleep.rawValue
            ),
            dateInterval: dateInterval,
            author: author
        )

        let inbedSamples = try await self.healthCoreProvider.readData(
            sampleType: .categoryType(
                forIdentifier: .sleepAnalysis,
                categoryValue: HKCategoryValueSleepAnalysis.inBed.rawValue
            ),
            dateInterval: dateInterval,
            author: author
        )

        let heartSamples = try await self.healthCoreProvider.readData(
            sampleType: .quantityType(forIdentifier: .heartRate),
            dateInterval: dateInterval,
            author: author
        )

        let energySamples = try await self.healthCoreProvider.readData(
            sampleType: .quantityType(forIdentifier: .activeEnergyBurned),
            dateInterval: dateInterval,
            author: author
        )

        let respiratorySamples = try await self.healthCoreProvider.readData(
            sampleType: .quantityType(forIdentifier: .respiratoryRate),
            dateInterval: dateInterval,
            author: author
        )

        return (asleepSamples, inbedSamples, heartSamples, energySamples, respiratorySamples)
    }

    /// Функция для получения сэмплов микросна из сырых категориальных данных сна
    private func filterLastMicroSleepSamples(rawSamples: [HKSample]) -> [HKCategorySample] {
        guard let firstSample = rawSamples.first else { return [] }
        var filteredSamples: [HKCategorySample] = []
        var startDateBefore: Date = firstSample.startDate

        for item in rawSamples {
            if let sample = item as? HKCategorySample {
                if sample == firstSample {
                    filteredSamples.append(sample)
                } else {
                    if sample.endDate.minutes(from: startDateBefore) <= Constant.minimalAcceptableMicroSleepSamplesDifference {
                        filteredSamples.append(sample)
                        startDateBefore = sample.startDate
                    } else { break }
                }
            }
        }
        return filteredSamples
    }

    /// Функция для определения микросна по эпловским сэмплам.
    /// См. описание функции retrieveData
    private func detectMicroSleep(
        inbedSamplesRaw: [HKSample]?,
        asleepSamplesRaw: [HKSample]?,
        heartSamplesRaw: [HKSample]?,
        energySamplesRaw: [HKSample]?,
        respiratoryRaw: [HKSample]?,
        isFirstFetch: Bool
    ) -> (
        Result<(
            asleepInterval: DateInterval,
            inbedInterval: DateInterval,
            heartSamples: [HKSample]?,
            energySamples: [HKSample]?,
            respiratorySamples: [HKSample]?
        ),
        SleepCoreProviderError>
    ) {
        guard
            let asleepSamplesRaw = asleepSamplesRaw,
            let inbedSamplesRaw = inbedSamplesRaw
        else {
            return .failure(.notEnoughRawDataError)
        }

        var microAsleepSamples = self.filterLastMicroSleepSamples(rawSamples: asleepSamplesRaw)
        var microInBedSamples = self.filterLastMicroSleepSamples(rawSamples: inbedSamplesRaw)

        if microInBedSamples.isEmpty, microAsleepSamples.isEmpty {
            return .failure(.microSleepNotFoundError)
        } else if microInBedSamples.isEmpty {
            microInBedSamples = microAsleepSamples
        } else if microAsleepSamples.isEmpty {
            microAsleepSamples = microInBedSamples
        }

        var asleepInterval = DateInterval(start: microAsleepSamples.last!.startDate, end: microAsleepSamples.first!.endDate)
        var inbedInterval = DateInterval(start: microInBedSamples.last!.startDate, end: microInBedSamples.first!.endDate)

        // может такое случиться, что часы заряжались => за прошлую ночь asleep сэмплы отсутствуют (а inbed есть),
        // тогда asleep вытащятся за позапрошлые сутки (последние сэмплы asleep) и это будут разные промежутки у inbed и asleep
        // или наоборот есть только asleep сэмплы (такой баг случается если встаешь раньше будильника)
        if !inbedInterval.intersects(asleepInterval), isFirstFetch {
            if inbedInterval.end > asleepInterval.end {
                microAsleepSamples = microInBedSamples
                asleepInterval = DateInterval(start: microAsleepSamples.last!.startDate, end: microAsleepSamples.first!.endDate)
            } else {
                microInBedSamples = microAsleepSamples
                inbedInterval = DateInterval(start: microInBedSamples.last!.startDate, end: microInBedSamples.first!.endDate)
            }
        }

        if inbedInterval.end < asleepInterval.end {
            inbedInterval.end = asleepInterval.end
        }

        let heartSamples = heartSamplesRaw?.filter { asleepInterval.intersects(DateInterval(start: $0.startDate, end: $0.endDate)) }
        let energySamples = energySamplesRaw?.filter { asleepInterval.intersects(DateInterval(start: $0.startDate, end: $0.endDate)) }
        let respiratorySamples = respiratoryRaw?.filter { asleepInterval.intersects(DateInterval(start: $0.startDate, end: $0.endDate)) }

        return .success((asleepInterval, inbedInterval, heartSamples, energySamples, respiratorySamples))
    }

    /// Сохраняет микросон в базу данных healthKit если он еще не был сохранен ранее
    private func saveMicroSleepIfNeeded(microSleep: MicroSleep) async throws {
        let expandedIntervalStart = Calendar.current.date(byAdding: .minute, value: -5, to: microSleep.inBedInterval.start)!
        let expandedIntervalEnd = Calendar.current.date(byAdding: .minute, value: 5, to: microSleep.inBedInterval.end)!
        let expandedInterval = DateInterval(start: expandedIntervalStart, end: expandedIntervalEnd)

        let existingSleepySamples = try await self.healthCoreProvider.readData(
            sampleType: .categoryType(forIdentifier: .sleepAnalysis, categoryValue: HKCategoryValueSleepAnalysis.asleep.rawValue),
            dateInterval: expandedInterval,
            author: .concrete(identifiers: Set([Bundle.main.bundleIdentifier ?? ""])))

        guard
            let existingSleepySamples = existingSleepySamples, existingSleepySamples.isEmpty,
            let sleepType = HKObjectType.categoryType(forIdentifier: HKCategoryTypeIdentifier.sleepAnalysis)
        else {
            return
        }

        let asleepSample = HKCategorySample(
            type: sleepType,
            value: HKCategoryValueSleepAnalysis.asleep.rawValue,
            start: microSleep.sleepInterval.start,
            end: microSleep.sleepInterval.end,
            metadata: self.generateMetadata(microSleep: microSleep)
        )

        let inBedSample = HKCategorySample(
            type: sleepType,
            value: HKCategoryValueSleepAnalysis.inBed.rawValue,
            start: microSleep.inBedInterval.start,
            end: microSleep.inBedInterval.end
        )

        return try await self.healthCoreProvider.writeData(data: [asleepSample, inBedSample])
    }

    /// Генерация  метадаты по микросну для последуюшего сохранения ее в данных сэмпла хелскит
    private func generateMetadata(microSleep: MicroSleep) -> [String: Any] {
        var metadata: [String: Any] = [:]
        
        let heartValues = microSleep.heartData.compactMap { $0.value }
        let energyValues = microSleep.energyData.compactMap { $0.value }
        let respiratoryValues = microSleep.respiratoryData.compactMap { $0.value }

        let meanHeartRate = (heartValues.reduce(0.0, +)) / Double(heartValues.count)
        let energyConsumption = energyValues.reduce(0.0, +)
        let meanRespiratoryRate = (respiratoryValues.reduce(0.0, +)) / Double(respiratoryValues.count)

        metadata["Heart rate mean"] = String(format: "%.3f", meanHeartRate)
        metadata["Energy consumption"] = String(format: "%.3f", energyConsumption)
        metadata["Respiratory rate"] = String(format: "%.3f", meanRespiratoryRate)

        return metadata
    }
}
