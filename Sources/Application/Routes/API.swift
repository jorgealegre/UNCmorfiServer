//
// Copyright © 2018 George Alegre. All rights reserved.
//

import Foundation

import Kitura
import KituraContracts

/// Router handling main API requests.
class APIRouter {

    private init() {}

    // MARK: - Endpoints

    static func setEndpoints(router: Router) {
        router.get("/users", handler: getUsers)
        router.get("/menu", handler: getMenu)
        router.get("/servings", handler: getServings)
    }

    // MARK: - Handlers

    private struct GetUsersQuery: QueryParams {
        let codes: [String]
    }

    private static func getUsers(queryParams: GetUsersQuery, callback: @escaping ([User]?, RequestError?) -> Void) {
        UNCComedor.api.getUsers(from: queryParams.codes) { result in
            switch result {
            case let .success(users):
                callback(users, nil)
            case let .failure(error):
                print(error)
                callback(nil, nil)
            }

        }
    }

    private static func getMenu(callback: @escaping ([Date: [String]]?, RequestError?) -> Void) {
        UNCComedor.api.getMenu { result in
            switch result {
            case let .success(menu):
                callback(menu, nil)
            case let .failure(error):
                callback(nil, nil)
            }
        }
    }

    private static func getServings(callback: @escaping ([Date: Int]?, RequestError?) -> Void) {
        UNCComedor.api.getServings { result in
            switch result {
            case let .success(servings):
                callback(servings, nil)
            case let .failure(error):
                callback(nil, nil)
            }

        }
    }
}
