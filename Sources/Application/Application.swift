import Foundation
import Kitura
import LoggerAPI
import Configuration
import CloudEnvironment
import KituraContracts
import Health
import KituraOpenAPI

import SwiftSoup

public let projectPath = ConfigurationManager.BasePath.project.path
public let health = Health()

enum Result<A> {
    case success(A)
    case failure(Error)
}

struct User: Codable {
    // MARK: Properties
    let name: String
    let code: String
    let balance: Int
    let imageCode: String
    let expirationDate: Date
}

class UNCComedor {

    // MARK: Singleton

    static let api = UNCComedor()
    private init() {}

    // MARK: URLSession

    private let session = URLSession.shared

    // MARK: API endpoints

    static let baseDataURL = "http://comedor.unc.edu.ar/gv-ds.php"
    static let baseMenuURL = URL(string: "https://www.unc.edu.ar/vida-estudiantil/men%C3%BA-de-la-semana")!
    static let baseServingsURL = URL(string: "http://comedor.unc.edu.ar/gv-ds.php?json=true&accion=1&sede=0475")!

    // MARK: Errors

    enum UNCComedorError: Error {
        case servingDateUnparseable
        case servingCountUnparseable
    }

    // MARK: Helpers

    /**
     Use as first error handling method of any type of URLSession task.
     - Parameters:
     - error: an optional error found in the task completion handler.
     - res: the `URLResponse` found in the task completion handler.
     - Returns: if an error is found, a custom error is returned, else `nil`.
     */
    static func handleAPIResponse(error: Error?, res: URLResponse?) -> Error? {
        guard error == nil else {
            // TODO handle client error
            //            handleClientError(error)
            return error!
        }

        guard let httpResponse = res as? HTTPURLResponse,
            (200...299).contains(httpResponse.statusCode) else {
                print("response = \(res!)")
                // TODO: create my own errors
                //            handleServerError(res)
                return NSError()
        }

        return nil
    }

    // MARK: - Public API methods

    func getMenu(callback: @escaping (_ result: Result<[Date:[String]]>) -> Void) {
        let task = session.dataTask(with: UNCComedor.baseMenuURL) { data, res, error in
            // Check for errors and exit early.
            let customError = UNCComedor.handleAPIResponse(error: error, res: res)
            guard customError == nil else {
                callback(.failure(customError!))
                return
            }

            guard let data = data,
                let dataString = String(data: data, encoding: .utf8) else {
                    callback(.failure(NSError()))
                    // TODO create my own errors
                    return
            }

            // Try to parse HTML and find the elements we care about.
            let elements: Elements
            do {
                let doc = try SwiftSoup.parse(dataString)
                elements = try doc.select("div[class='field-item even']").select("ul")
            } catch {
                print("can't parse HTML response.")
                // TODO: should create error
                callback(.failure(NSError()))
                return
            }

            // Should handle parsing lightly, don't completely know server's behaviour.
            // Prefer to not show anything or parse wrongly than to crash.
            var menu: [Date: [String]] = [:]

            // Whatever week we're in, find monday.
            let startingDay = Calendar(identifier: .iso8601)
                .date(from: Calendar(identifier: .iso8601)
                    .dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date()))!

            // For each day, parse the menu.
            do {
                for (index, element) in elements.enumerated() {
                    let listItems: [Element] = try element.select("li").array()

                    let foodList = listItems
                        .compactMap { try? $0.text() }
                        .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

                    let day = startingDay.addingTimeInterval(TimeInterval(index * 24 * 60 * 60))
                    menu[day] = foodList
                }
            } catch {
                callback(.failure(NSError()))
                return
            }

            callback(.success(menu))
        }

        task.resume()
    }

    func getUsers(from codes: [String], callback: @escaping (_ result: Result<[User]>) -> Void) {
        // Exit early.
        guard !codes.isEmpty else {
            callback(.success([]))
            return
        }

        /// API only returns one user at a time. Use a dispatch group to execute many requests in
        /// parallel and wait for all to finish.
        let queue = DispatchQueue(label: "getUsers")
        let group = DispatchGroup()

        func getUser(from code: String, callback: @escaping (_ result: Result<User>) -> Void) {
            // Prepare the request and its parameters.
            var request = URLRequest(url: URL(string: UNCComedor.baseDataURL)!)
            request.httpMethod = "POST"
            request.httpBody = "accion=4&codigo=\(code)".data(using: .utf8)

            // Send the request and setup the callback.
            let task  = session.dataTask(with: request) { data, res, error in
                // Check for errors and exit early.
                let customError = UNCComedor.handleAPIResponse(error: error, res: res)
                guard customError == nil else {
                    callback(.failure(customError!))
                    return
                }

                guard let data = data else {
                    callback(.failure(NSError()))
                    // TODO: create my own errors
                    return
                }

                // Decode data.
                let response = String(data: data, encoding: .utf8)!

                let preffix = "rows: [{c: ["
                let suffix = "]}]}});"
                let preffixIndex = response.range(of: preffix)!.upperBound
                let suffixIndex = response.range(of: suffix)!.lowerBound

                let components = response[preffixIndex..<suffixIndex].components(separatedBy: "},{")

                var _16 = components[16]
                _16 = String(_16[_16.index(_16.startIndex, offsetBy: 4)..._16.index(_16.startIndex, offsetBy: _16.count - 2)])

                var _17 = components[17]
                _17 = String(_17[_17.index(_17.startIndex, offsetBy: 4)..._17.index(_17.startIndex, offsetBy: _17.count - 2)])

                var _5 = components[5]
                _5 = String(_5[_5.index(_5.startIndex, offsetBy: 3)..._5.index(_5.startIndex, offsetBy: _5.count - 1)])

                var _24 = components[24]
                _24 = String(_24[_24.index(_24.startIndex, offsetBy: 4)..._24.index(_24.startIndex, offsetBy: _24.count - 2)])

                let name = "\(_16) \(_17)"
                let balance = Int(_5)!
                let image = _24

                let user = User(name: name, code: code, balance: balance, imageCode: image, expirationDate: Date())

                callback(.success(user))
            }

            task.resume()

        }

        var users: [String: User] = [:]
        for code in codes {
            group.enter()

            getUser(from: code) { result in
                defer { group.leave() }

                switch result {
                case let .success(user):
                    users[code] = user
                case let .failure(error):
                    print(error)
                }
            }
        }

        group.notify(queue: queue) {
            callback(.success(Array(users.values)))
        }
    }

    func getServings(callback: @escaping (_ result: Result<[Date: Int]>) -> Void) {
        let task = session.dataTask(with: UNCComedor.baseServingsURL) { data, res, error in
            // Check for errors and exit early.
            let customError = UNCComedor.handleAPIResponse(error: error, res: res)
            guard customError == nil else {
                callback(.failure(customError!))
                return
            }

            guard let data = data else {
                callback(.failure(NSError()))
                // TODO: create my own errors
                return
            }

            guard let response = String(data: data, encoding: .utf8) else {
                print("Error decoding response as UTF-8 string.")
                callback(.failure(NSError()))
                return
            }

            /* Server response is weird Javascript function application with data as function's parameter.
             * Data is not a JSON string but a Javascript object, not to be confused with one another.
             */

            // Attempt to parse string into something useful.
            guard
                let start = response.range(of: "(")?.upperBound,
                let end = response.range(of: ")")?.lowerBound else {
                    callback(.failure(NSError()))
                    return
            }
            var jsonString = String(response[start..<end])

            jsonString = jsonString
                // Add quotes to keys.
                .replacingOccurrences(of: "(\\w*[A-Za-z]\\w*)\\s*:",
                                      with: "\"$1\":",
                                      options: .regularExpression,
                                      range: jsonString.startIndex..<jsonString.endIndex)
                // Replace single quotes with double quotes.
                .replacingOccurrences(of: "'", with: "\"")

            // Parse fixed string.
            guard let jsonData = jsonString.data(using: .utf8) else {
                callback(.failure(NSError()))
                return
            }
            guard let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
                callback(.failure(NSError()))
                return
            }

            // Transform complicated JSON structure into simple [Date: Int] dictionary.
            guard let table = json?["table"] as? [String: [[String: Any]]] else {
                callback(.failure(NSError()))
                return
            }

            guard let rows = table["rows"] else {
                callback(.failure(NSError()))
                return
            }

            let result = rows.reduce([Date: Int]()) { (result, row) -> [Date: Int] in
                // 'result' parameter is constant, can't be changed.
                var result = result

                guard let row = row["c"] as? [[String: Any]] else {
                    return result
                }

                // The server only gave us a time in timezone GMT-3 (e.g. 12:09:00)
                // We need to add the current date and timezone data. (e.g. 2017-09-10 15:09:00 +0000)
                // Start off by getting the current date.
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy-MM-dd'T'"

                let todaysDate = dateFormatter.string(from: Date())

                // Join today's date, the time from the row and the timezone into one string in ISO format.
                guard let time = row[0]["v"] as? String else {
                    return result
                }
                let dateString = "\(todaysDate)\(time)-0300"

                // Add time and timezone support to the parser.
                let timeFormat = "HH:mm:ssZ"
                dateFormatter.dateFormat = dateFormatter.dateFormat + timeFormat

                // Get a Date object from the resulting string.
                guard let date = dateFormatter.date(from: dateString) else {
                    return result
                }

                // Get food count from row.
                guard let count = row[1]["v"] as? Int else {
                    return result
                }

                // Add data to the dictionary.
                result[date] = count

                return result
            }

            callback(.success(result))
        }

        task.resume()
    }
}

public class App {
    let router = Router()
    let cloudEnv = CloudEnv()

    private let session = URLSession.shared

    public init() throws {
        // Run the metrics initializer
        initializeMetrics(router: router)
    }

    private struct GetUsersQuery: QueryParams {
        let codes: [String]
    }

    private func getUsers(queryParams: GetUsersQuery, callback: @escaping ([User]?, RequestError?) -> Void) {
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

    private func getMenu(callback: @escaping ([Date: [String]]?, RequestError?) -> Void) {
        UNCComedor.api.getMenu { result in
            switch result {
            case let .success(menu):
                callback(menu, nil)
            case let .failure(error):
                callback(nil, nil)
            }
        }
    }

    private func getServings(callback: @escaping ([Date: Int]?, RequestError?) -> Void) {
        UNCComedor.api.getServings { result in
            switch result {
            case let .success(servings):
                callback(servings, nil)
            case let .failure(error):
                callback(nil, nil)
            }

        }
    }

    func postInit() throws {
        // Endpoints
        initializeHealthRoutes(app: self)

        router.get("/users", handler: getUsers)
        router.get("/menu", handler: getMenu)
        router.get("/servings", handler: getServings)
    }

    public func run() throws {
        try postInit()
        KituraOpenAPI.addEndpoints(to: router)
        Kitura.addHTTPServer(onPort: cloudEnv.port, with: router)
        Kitura.run()
    }
}
