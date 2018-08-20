//
// Copyright © 2018 George Alegre. All rights reserved.
//

import Foundation
import Kitura
import LoggerAPI
import HeliumLogger
import Application

do {
    HeliumLogger.use(LoggerMessageType.debug)

    let app = try App()
    try app.run()
} catch {
    Log.error(error.localizedDescription)
}
