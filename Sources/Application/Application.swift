//
// Copyright © 2018 George Alegre. All rights reserved.
//

import Foundation

import Kitura
import LoggerAPI
import Configuration
import CloudEnvironment
import KituraContracts
import KituraOpenAPI

public let projectPath = ConfigurationManager.BasePath.project.path

public class App {
    let router = Router()
    let cloudEnv = CloudEnv()

    public init() throws {}

    func postInit() throws {
        // Endpoints
        MetricsRouter.setEndpoints(router: router)
        HealthRouter.setEndpoints(router: router)
        APIRouter.setEndpoints(router: router)

        // API documentation
        KituraOpenAPI.addEndpoints(to: router)
    }

    public func run() throws {
        try postInit()

        Kitura.addHTTPServer(onPort: cloudEnv.port, with: router)
        Kitura.run()
    }
}
