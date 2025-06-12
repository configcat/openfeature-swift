import ConfigCat
import Foundation

class BundleResourceDataSource: OverrideDataSource {
    private var settings: [String: Setting] = [:]

    public init(path: String, behaviour: OverrideBehaviour) throws {
        super.init(behaviour: behaviour)
        let json = loadResource(path: path)
        let jsonObject: [String: Any] = try fromJson(json: json)
        let result = Config.fromJson(json: jsonObject)
        self.settings = result.settings
    }

    public override func getOverrides() -> [String: Setting] {
        settings
    }
    
    func fromJson<T>(json: String) throws -> T {
        let data = json.data(using: .utf8)!
        let result = try JSONSerialization.jsonObject(with: data, options: []) as! T
        return result
    }
}
