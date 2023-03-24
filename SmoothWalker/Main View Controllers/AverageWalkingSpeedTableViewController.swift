//
//  AverageWalkingSpeedTableViewController.swift
//  SmoothWalker
//
//  Created by Jonathan Yee on 3/23/23.
//  Copyright © 2023 Apple. All rights reserved.
//

import Foundation
import HealthKit
import UIKit

class AverageWalkingSpeedTableViewController: HealthQueryTableViewController {
    /// The date from the latest server response.
    private var dateLastUpdated: Date?

    // MARK: Initializers

    init() {
        super.init(dataTypeIdentifier: HKQuantityTypeIdentifier.walkingSpeed.rawValue)

        // Set weekly predicate
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

    // MARK: - Selector Overrides

    @objc
    override func didTapFetchButton() {
//        Network.pull() { [weak self] (serverResponse) in
//            self?.dateLastUpdated = serverResponse.date
//            self?.queryPredicate = createLastWeekPredicate(from: serverResponse.date)
//            self?.handleServerResponse(serverResponse)
//        }
        writeMockData()
    }

    // MARK: - Network

    /// Handle a response fetched from a remote server. This function will also save any HealthKit samples and update the UI accordingly.
    override func handleServerResponse(_ serverResponse: ServerResponse) {
        let weeklyReport = serverResponse.weeklyReport
        let addedSamples = weeklyReport.samples.map { (serverHealthSample) -> HKQuantitySample in

            // Set the sync identifier and version
            var metadata = [String: Any]()
            let sampleSyncIdentifier = String(format: "%@_%@", weeklyReport.identifier, serverHealthSample.syncIdentifier)

            metadata[HKMetadataKeySyncIdentifier] = sampleSyncIdentifier
            metadata[HKMetadataKeySyncVersion] = serverHealthSample.syncVersion

            // Create HKQuantitySample
            let quantity = HKQuantity(unit: .meter(), doubleValue: serverHealthSample.value)
            let sampleType = HKQuantityType.quantityType(forIdentifier: .walkingSpeed)!
            let quantitySample = HKQuantitySample(type: sampleType,
                                                  quantity: quantity,
                                                  start: serverHealthSample.startDate,
                                                  end: serverHealthSample.endDate,
                                                  metadata: metadata)

            return quantitySample
        }

        HealthData.healthStore.save(addedSamples) { (success, error) in
            if success {
                self.loadData()
            }
        }
    }

    private func writeMockData() {
        var samples = [HKQuantitySample]()
        let today = Date()
        for i in 0..<30 {
            guard
                let date = Calendar.current.date(byAdding: .day, value: -i, to: today),
                let sampleType = HKQuantityType.quantityType(forIdentifier: .walkingSpeed)
            else { return }
            
            let randomDouble = Double.random(in: 0...1.5)
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

    // MARK: Function Overrides

    override func reloadData() {
        super.reloadData()

        DispatchQueue.main.async {
            self.chartView.graphView.horizontalAxisMarkers = createHorizontalAxisMarkers()

            if let dateLastUpdated = self.dateLastUpdated {
                self.chartView.headerView.detailLabel.text = createChartDateLastUpdatedLabel(dateLastUpdated)
            }
        }
    }
}
