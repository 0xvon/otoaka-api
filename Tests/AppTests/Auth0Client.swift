import Foundation
import NIO
import Vapor

class Auth0Client {
    struct User: Codable {
        let token: String
        let sub: String
    }
    
    let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    let app: Application
    let domain: String = Environment.get("AUTH0_DOMAIN")!
    let clientId: String = Environment.get("AUTH0_CLIENT_ID")!
    let clientSecret: String = Environment.get("AUTH0_CLIENT_SECRET")!
    let managementApiToken: String = Environment.get("AUTH0_MANAGEMENT_API_TOKEN")!
    init(_ app: Application) {
        self.app = app
    }

    func createToken(userName: String, email: String? = nil, password: String = "Passw0rd!!") throws -> User
    {
        
        let email = email ?? "\(userName)@example.com"
        let tempPassword = "Passw0rd!"
        
        var headers = HTTPHeaders()
        headers.add(name: .contentType, value: HTTPMediaType.json.serialize())
        headers.add(name: .authorization, value: "Bearer \(managementApiToken)")
        
        let createUserRequest = CreateUserRequest(email: email, email_verified: true, username: userName, user_id: userName, connection: "Username-Password-Authentication", password: tempPassword)
        let createUserBodyData = try ByteBuffer(data: encoder.encode(createUserRequest))
        
        let createUserRes = try app.client.post("\(domain)/api/v2/users", headers: headers) { req in
            req.body = createUserBodyData
        }.wait()
        
        let createdUser = try createUserRes.content.decode(CreateUserResponse.self)
        
        var loginHeaders = HTTPHeaders()
        loginHeaders.add(name: .contentType, value: HTTPMediaType.json.serialize())
        
        let loginRequest = LoginRequest(
            grant_type: "password",
            username: userName,
            password: tempPassword,
            client_id: clientId,
            client_secret: clientSecret,
            audience: "\(domain)/api/v2/"
        )
        let loginBodyData = try ByteBuffer(data: encoder.encode(loginRequest))
        let loginRes = try app.client.post("\(domain)/oauth/token", headers: loginHeaders) { req in
            req.body = loginBodyData
        }.wait()
        
        let token = try loginRes.content.decode(AccessToken.self)
        return User(token: token.access_token, sub: createdUser.user_id)
    }

    func destroyUser(id: String) throws -> EventLoopFuture<Void> {
        var headers = HTTPHeaders()
        headers.add(name: .contentType, value: HTTPMediaType.json.serialize())
        headers.add(name: .authorization, value: "Bearer \(managementApiToken)")
        
        return app.client.delete("\(domain)/api/v2/users/\(id.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!)", headers: headers).map { _ in }
    }
}

struct CreateUserRequest: Codable {
    let email: String
    let email_verified: Bool
    let username: String?
    let user_id: String?
    let connection: String
    let password: String
}

struct CreateUserResponse: Codable {
    let user_id: String
    let email: String
    let email_verified: Bool
}


struct LoginRequest: Codable {
    let grant_type: String
    let username: String
    let password: String
//    let scope: String
    let client_id: String
    let client_secret: String
    let audience: String
}

struct AccessToken: Codable {
    let access_token: String
    let scope: String?
    let expires_in: Int?
    let token_type: String?
}
