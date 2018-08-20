//
// Copyright © 2018 George Alegre. All rights reserved.
//

import Kitura
import LoggerAPI
import Health
import KituraContracts

class HealthRouter {
    private static let health = Health()

    private init() {}

    static func setEndpoints(router: Router) {
        router.get("/health", handler: getHealth)
    }

    private static func getHealth(callback: @escaping (Status?, RequestError?) -> Void) {
        if health.status.state == .UP {
            callback(health.status, nil)
        } else {
            callback(nil, RequestError(.serviceUnavailable, body: health.status))
        }
    }
}
