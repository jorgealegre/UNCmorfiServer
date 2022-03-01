import Foundation

struct User: Codable {
    let name: String
    let code: String
    let balance: Int
    let imageCode: String
    let expirationDate: String?
    let type: String
    let imageURL: URL
}
