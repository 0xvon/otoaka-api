import Foundation
import NIO
import SotoCognitoIdentityProvider
import Vapor

class CognitoClient {
    struct User: Codable {
        let token: String
        let sub: String
    }

    let cognito: CognitoIdentityProvider
    let userPoolId: String = Environment.get("CONGNITO_IDP_USER_POOL_ID")!
    let region: String = Environment.get("AWS_REGION")!
    let clientId: String = Environment.get("CONGNITO_IDP_CLIENT_ID")!
    init() {
        cognito = CognitoIdentityProvider(
            client: .init(httpClientProvider: .createNew),
            region: Region(rawValue: region)
        )
    }

    func createToken(userName: String, email: String? = nil, password: String = "Passw0rd!!")
        -> EventLoopFuture<User>
    {
        let email = email ?? "\(userName)@example.com"
        let tempPassword = "Passw0rd!"
        return cognito.adminCreateUser(
            .init(temporaryPassword: tempPassword, username: userName, userPoolId: userPoolId)
        )
        .flatMap { response in
            let sub = response.user!.attributes!.first(where: { $0.name == "sub" })!.value!
            return self.cognito.adminInitiateAuth(
                .init(
                    authFlow: .adminNoSrpAuth,
                    authParameters: [
                        "USERNAME": userName,
                        "PASSWORD": tempPassword,
                    ],
                    clientId: self.clientId, userPoolId: self.userPoolId
                )
            )
            .and(value: sub)
        }
        .flatMap {
            (response: CognitoIdentityProvider.AdminInitiateAuthResponse, sub: String)
                -> EventLoopFuture<
                    (CognitoIdentityProvider.AdminRespondToAuthChallengeResponse, String)
                > in
            let input = CognitoIdentityProvider.AdminRespondToAuthChallengeRequest(
                challengeName: .newPasswordRequired,
                challengeResponses: [
                    "USERNAME": userName,
                    "NEW_PASSWORD": password,
                    "userAttributes.email": email,
                ],
                clientId: self.clientId,
                session: response.session,
                userPoolId: self.userPoolId
            )
            return self.cognito.adminRespondToAuthChallenge(input).and(value: sub)
        }
        .map { response, sub in
            User(token: response.authenticationResult!.idToken!, sub: sub)
        }
    }

    func destroyUser(userName: String) -> EventLoopFuture<Void> {
        cognito.adminDeleteUser(.init(username: userName, userPoolId: userPoolId))
    }
    deinit {
        try! cognito.client.syncShutdown()
    }
}
