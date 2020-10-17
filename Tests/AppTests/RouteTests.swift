import XCTest
import Endpoint

class RouteTests: XCTestCase {
    
    struct User {
        let id: Int
    }
    func testSimpleRoute() {
        let route = constant("bands")/int()/constant("fans")
//        let runBuild: (User) -> [String] = { route.runBuild((((), $0.id), ())) }
        
        // (((), Int), ())
//        let makeRunParse: (
//            ((()) -> (Int) -> (()) -> User)
//        ) -> ([String]) -> User? = { makeResult in
//            return { components in
//                guard let result = route.runParse(components) else { return nil }
//                return makeResult(result.0.0)(result.0.1)(result.1)
//            }
//        }
        func makeRunParse(
            _ makeResult: @escaping ((()) -> (Int) -> (()) -> User)
        ) -> ([String]) -> User? {
            return { components in
                guard let result = route.runParse(components) else { return nil }
                return makeResult(result.0.0)(result.0.1)(result.1)
            }
        }
        let runBuild: (()) -> ((Int)) -> (()) -> [String] = { _ in
            { id in
                { _ in
                    route.runBuild((((), id), ()))
                }
            }
        }
        
        func makeRunBuild(
            _ user: User,
            _ giveParams: ((User) -> ()) -> ((User) -> Int) -> ((User) -> Void)) -> [String] {
            []
        }
        let runParse = makeRunParse(curry { _, id, _ in User(id: id) })

//        let user = User(id: 1)
//        XCTAssertEqual(runBuild(user), ["bands", "1", "fans"])
//        let path = ["bands", "1", "fans"]
//        XCTAssertEqual(runParse(path)?.id, 1)
    }
}
