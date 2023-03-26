//
//  AverageWalkingSpeedViewModel.swift
//  SmoothWalker
//
//  Created by Jonathan Yee on 3/25/23.
//  Copyright © 2023 Apple. All rights reserved.
//

import CareKitUI
import Foundation
import HealthKit
import UIKit

class AverageWalkingSpeedViewModel {
    private var queryPredicate: NSPredicate? = nil
    private var queryAnchor: HKQueryAnchor? = nil
    private var queryLimit: Int = HKObjectQueryNoLimit

    let dataTypeIdentifier = HKQuantityTypeIdentifier.walkingSpeed.rawValue
    private var dataValues: [HealthDataTypeValue] = []

    private var selectedSegmentIndex = 1
    weak var chartView: OCKCartesianChartView?

    init() {
        queryPredicate = createLastWeekPredicate()
    }

    var isDataValuesEmpty: Bool {
        dataValues.isEmpty
    }

    func writeMockData() {
        var samples = [HKQuantitySample]()
        let today = Date()
        for i in 0..<365 {
            guard
                let dayModified = Calendar.current.date(byAdding: .day, value: -i, to: today),
                let date = Calendar.current.date(byAdding: .minute, value: -10, to: dayModified),
                let sampleType = HKQuantityType.quantityType(forIdentifier: .walkingSpeed)
            else { return }

            let randomDouble = Double.random(in: 0...2)
            let quantity = HKQuantity(unit: .meter().unitDivided(by: .second()), doubleValue: randomDouble)

            let quantitySample = HKQuantitySample(type: sampleType,
                                                  quantity: quantity,
                                                  start: date,
                                                  end: date)
            samples.append(quantitySample)
        }

        HealthData.healthStore.save(samples) { (success, error) in
            if success {
                self.loadData()
            }
        }
    }

    func segmentedValueChanged(to index: Int) {
        selectedSegmentIndex = index

        if index == 0 {
            // daily
            queryPredicate = createDailyPredicate()
        } else if index == 1 {
            // weekly
            queryPredicate = createLastWeekPredicate()

        } else {
            // monthly
            queryPredicate = createMonthlyPredicate()
        }

        loadData()
    }

    func loadData() {
        performQuery { [weak self] in
            guard let self = self,
                let chartView = self.chartView
            else { return }

            DispatchQueue.main.async {

                chartView.applyDefaultConfiguration()

                chartView.headerView.titleLabel.text = getDataTypeName(for: self.dataTypeIdentifier)

                self.dataValues.sort { $0.startDate < $1.startDate }

                if self.selectedSegmentIndex == 0 {
                    chartView.graphView.horizontalAxisMarkers = ["12am", "6", "12pm", "6"]
                } else if self.selectedSegmentIndex == 1 {
                    chartView.graphView.horizontalAxisMarkers = createHorizontalAxisMarkers()
                } else {
                    chartView.graphView.horizontalAxisMarkers = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
                }

                let data = self.dataValues.compactMap { CGFloat($0.value) }
                guard
                    let unit = preferredUnit(for: self.dataTypeIdentifier),
                    let unitTitle = getUnitDescription(for: unit)
                else {
                    return
                }

                var dataSeries = OCKDataSeries(values: data, title: unitTitle)
                dataSeries.size = 1

                chartView.graphView.dataSeries = [
                    dataSeries
                ]
            }
        }
    }

    private func performQuery(completion: @escaping () -> Void) {
        guard let sampleType = getSampleType(for: dataTypeIdentifier) else { return }

        let anchoredObjectQuery = HKAnchoredObjectQuery(type: sampleType,
                                                        predicate: queryPredicate,
                                                        anchor: queryAnchor,
                                                        limit: queryLimit) {
            (query, samplesOrNil, deletedObjectsOrNil, anchor, errorOrNil) in

            guard let samples = samplesOrNil else { return }

            self.dataValues = samples.map { (sample) -> HealthDataTypeValue in
                var dataValue = HealthDataTypeValue(startDate: sample.startDate,
                                                    endDate: sample.endDate,
                                                    value: .zero)
                if let quantitySample = sample as? HKQuantitySample,
                   let unit = preferredUnit(for: quantitySample) {
                    dataValue.value = quantitySample.quantity.doubleValue(for: unit)
                }

                return dataValue
            }

            completion()
        }

        HealthData.healthStore.execute(anchoredObjectQuery)
    }
}
