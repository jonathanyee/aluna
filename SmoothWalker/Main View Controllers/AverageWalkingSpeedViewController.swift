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

class AverageWalkingSpeedViewController: UIViewController {

    private lazy var segmentedControl: UISegmentedControl = {
        let view = UISegmentedControl(items: ["Daily", "Weekly", "Monthly"])
        view.addTarget(self, action: #selector(segmentedValueChanged(_:)), for: .valueChanged)
        view.selectedSegmentIndex = 1
        return view
    }()

    private lazy var chartView: OCKCartesianChartView = {
        let chartView = OCKCartesianChartView(type: .line)
        return chartView
    }()

    private let viewModel = AverageWalkingSpeedViewModel()

    // MARK: Initializers

    init() {
        super.init(nibName: nil, bundle: nil)
        viewModel.chartView = chartView
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - View Life Cycle Overrides

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        // Authorization
        if !viewModel.isDataValuesEmpty { return }

        HealthData.requestHealthDataAccessIfNeeded(dataTypes: [viewModel.dataTypeIdentifier]) { (success) in
            if success {
                // Perform the query and reload the data.
                self.viewModel.loadData()
            }
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setUpMockDataButton()
        setupView()
    }

    // MARK: - Selector Overrides

    @objc func segmentedValueChanged(_ sender: UISegmentedControl) {
        let index = sender.selectedSegmentIndex
        viewModel.segmentedValueChanged(to: index)
    }

    @objc func didTapAddMockDataButton() {
        viewModel.writeMockData()
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
}
