//
//  AverageWalkingSpeedTableViewController.swift
//  SmoothWalker
//
//  Created by Jonathan Yee on 3/23/23.
//  Copyright © 2023 Apple. All rights reserved.
//

import CareKitUI
import Foundation
import HealthKit
import UIKit

class AverageWalkingSpeedTableViewController: UIViewController {

    private lazy var segmentedControl: UISegmentedControl = {
        let view = UISegmentedControl(items: ["Daily", "Weekly", "Monthly"])
        view.addTarget(self, action: #selector(segmentedValueChanged(_:)), for: .valueChanged)
        return view
    }()

    private lazy var chartView: OCKCartesianChartView = {
        let chartView = OCKCartesianChartView(type: .line)
        return chartView
    }()

    private let dataTypeIdentifier = HKQuantityTypeIdentifier.walkingSpeed.rawValue
    private var dataValues: [HealthDataTypeValue] = []

    private var queryPredicate: NSPredicate? = nil
    private var queryAnchor: HKQueryAnchor? = nil
    private var queryLimit: Int = HKObjectQueryNoLimit

    // MARK: Initializers

    init() {
        super.init(nibName: nil, bundle: nil)

        queryPredicate = createLastWeekPredicate()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - View Life Cycle Overrides

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        // Authorization
        if !dataValues.isEmpty { return }

        HealthData.requestHealthDataAccessIfNeeded(dataTypes: [dataTypeIdentifier]) { (success) in
            if success {
                // Perform the query and reload the data.
                self.loadData()
            }
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setUpMockDataButton()
        setupView()
    }

    // MARK: - Selector Overrides

    @objc func segmentedValueChanged(_ sender:UISegmentedControl!) {
        print("Selected Segment Index is : \(sender.selectedSegmentIndex)")
    }
    @objc func didTapAddMockDataButton() {
        writeMockData()
    }

    // MARK: - Private methods

    private func setUpMockDataButton() {
        let barButtonItem = UIBarButtonItem(title: "Add Mock Data", style: .plain, target: self, action: #selector(didTapAddMockDataButton))

        navigationItem.rightBarButtonItem = barButtonItem
    }

    private func setupView() {
        view.backgroundColor = .white
        let stack = UIStackView(arrangedSubviews: [segmentedControl, chartView])
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .vertical
        view.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
        ])
    }

    private func writeMockData() {
        var samples = [HKQuantitySample]()
        let today = Date()
        for i in 0..<365 {
            guard
                let date = Calendar.current.date(byAdding: .day, value: -i, to: today),
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

    private func loadData() {
        performQuery { [weak self] in
            guard let self = self else { return }

            DispatchQueue.main.async {
                self.chartView.applyDefaultConfiguration()

                self.chartView.headerView.titleLabel.text = getDataTypeName(for: self.dataTypeIdentifier)

                self.dataValues.sort { $0.startDate < $1.startDate }

                let sampleStartDates = self.dataValues.map { $0.startDate }

                self.chartView.graphView.horizontalAxisMarkers = createHorizontalAxisMarkers(for: sampleStartDates)

                let data = self.dataValues.compactMap { CGFloat($0.value) }
                guard
                    let unit = preferredUnit(for: self.dataTypeIdentifier),
                    let unitTitle = getUnitDescription(for: unit)
                else {
                    return
                }

                var dataSeries = OCKDataSeries(values: data, title: unitTitle)
                dataSeries.size = 2
                
                self.chartView.graphView.dataSeries = [
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
