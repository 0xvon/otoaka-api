import Foundation
import NIO
import Vapor
import Auth0

class Auth0Client {
    struct User: Codable {
        let token: String
        let sub: String
    }
    
    let auth: Authentication
    let domain: String = Environment.get("AUTH0_DOMAIN")!
    let clientId: String = Environment.get("AUTH0_CLIENT_ID")!
    let clientSecret: String = Environment.get("AUTH0_CLIENT_SECRET")!
    init() {
        auth = Auth0
            .authentication(clientId: clientId, domain: domain)
    }
    
    func createToken(userName: String, email: String? = nil, password: String = "Passw0rd!!", callback: @escaping (User) -> Void)
    {
        let email = email ?? "\(userName)@example.com"
        let tempPassword = "Passw0rd!"
        auth.createUser(email: email, username: userName, password: tempPassword, connection: "Username-Password-Authentication")
            .start({ [unowned self] res in
                switch res {
                case .success(let user):
                    auth
                        .login(usernameOrEmail: user.username!, password: tempPassword, realm: "Username-Password-Authentication", scope: "openid")
                        .start({ res in
                            switch res {
                            case .success(let credentials):
                                callback(User(token: credentials.idToken!, sub: user.username!))
                            case .failure(let error):
                                fatalError(String(describing: error))
                            }
                        })
                case .failure(let error):
                    fatalError(String(describing: error))
                }
            })
    }
    
    func destroyUser(userName: String) {
        
    }
}
