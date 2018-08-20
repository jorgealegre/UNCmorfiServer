//
// Copyright © 2018 George Alegre. All rights reserved.
//

import Kitura
import SwiftMetrics
import SwiftMetricsDash
import SwiftMetricsPrometheus
import LoggerAPI

class MetricsRouter {
    private init() {}

    private var swiftMetrics: SwiftMetrics?
    private var swiftMetricsDash: SwiftMetricsDash?
    private var swiftMetricsPrometheus: SwiftMetricsPrometheus?

    static func setEndpoints(router: Router) {
        do {
            let metrics = try SwiftMetrics()
            let _ = try SwiftMetricsDash(swiftMetricsInstance: metrics, endpoint: router)
            let _ = try SwiftMetricsPrometheus(swiftMetricsInstance: metrics, endpoint: router)
            Log.info("Initialized metrics.")
        } catch {
            Log.warning("Failed to initialize metrics: \(error)")
        }
    }
}
