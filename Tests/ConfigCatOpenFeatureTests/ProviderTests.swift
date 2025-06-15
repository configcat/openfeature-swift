import XCTest
import ConfigCat
import OpenFeature

@testable import ConfigCatOpenFeature

class ProviderTests: XCTestCase {
    func testMetadata() {
        let provider = ConfigCatProvider(sdkKey: "localhost") { opts in
            opts.flagOverrides = LocalDictionaryDataSource(source: [:], behaviour: .localOnly)
        }
        
        XCTAssertEqual("ConfigCatProvider", provider.metadata.name)
    }
    
    func testMetadataOptions() {
        let opts = ConfigCatOptions()
        opts.flagOverrides = LocalDictionaryDataSource(source: [:], behaviour: .localOnly)
        let provider = ConfigCatProvider(sdkKey: "localhost", options: opts)
        
        XCTAssertEqual("ConfigCatProvider", provider.metadata.name)
    }
    
    func testEval() {
        let provider = ConfigCatProvider(sdkKey: "localhost") { opts in
            opts.flagOverrides = try! BundleResourceDataSource(path: "test_json_complex.json", behaviour: .localOnly)
        }
        
        let boolVal = provider.getBooleanEvaluation(key: "enabledFeature", defaultValue: false, context: nil)
        XCTAssertTrue(boolVal.value)
        XCTAssertEqual("v-enabled", boolVal.variant)
        XCTAssertEqual(Reason.defaultReason.rawValue, boolVal.reason)
        
        let intVal = provider.getIntegerEvaluation(key: "intSetting", defaultValue: 0, context: nil)
        XCTAssertEqual(5, intVal.value)
        XCTAssertEqual("v-int", intVal.variant)
        XCTAssertEqual(Reason.defaultReason.rawValue, intVal.reason)
        
        let doubleVal = provider.getDoubleEvaluation(key: "doubleSetting", defaultValue: 0.0, context: nil)
        XCTAssertEqual(1.2, doubleVal.value)
        XCTAssertEqual("v-double", doubleVal.variant)
        XCTAssertEqual(Reason.defaultReason.rawValue, doubleVal.reason)
        
        let stringVal = provider.getStringEvaluation(key: "stringSetting", defaultValue: "", context: nil)
        XCTAssertEqual("test", stringVal.value)
        XCTAssertEqual("v-string", stringVal.variant)
        XCTAssertEqual(Reason.defaultReason.rawValue, stringVal.reason)
        
        let objVal = provider.getObjectEvaluation(key: "objectSetting", defaultValue: Value.null, context: nil)
        XCTAssertTrue(objVal.value.asStructure()!["bool_field"]!.asBoolean()!)
        XCTAssertEqual("value", objVal.value.asStructure()!["text_field"]!.asString()!)
        XCTAssertEqual("v-object", objVal.variant)
        XCTAssertEqual(Reason.defaultReason.rawValue, objVal.reason)
    }
    
    func testUser() {
        let date = parseDate(val: "2025-05-30T10:15:30.00Z")
        let context = MutableContext(targetingKey: "example@matching.com", structure: MutableStructure(attributes: [
            "custom1": Value.string("something"),
            "custom2": Value.boolean(true),
            "custom3": Value.integer(5),
            "custom4": Value.double(1.2),
            "custom5": Value.list([Value.integer(1), Value.integer(2)]),
            "custom6": Value.date(date),
        ]))
        
        let user = context.toUserObject()
        XCTAssertEqual("example@matching.com", user.identifier)
        XCTAssertEqual("something", user.attribute(for: "custom1") as! String)
        XCTAssertEqual(true, user.attribute(for: "custom2") as! Bool)
        XCTAssertEqual(5, user.attribute(for: "custom3") as! Int)
        XCTAssertEqual(1.2, user.attribute(for: "custom4") as! Double)
        XCTAssertEqual([1,2], user.attribute(for: "custom5") as! [Int])
        XCTAssertEqual(date, user.attribute(for: "custom6") as! Date)
    }
    
    func testTargeting() {
        let provider = ConfigCatProvider(sdkKey: "localhost") { opts in
            opts.flagOverrides = try! BundleResourceDataSource(path: "test_json_complex.json", behaviour: .localOnly)
        }
        
        let ctx = MutableContext(targetingKey: "example@matching.com")
        
        let boolVal = provider.getBooleanEvaluation(key: "disabledFeature", defaultValue: false, context: ctx)
        XCTAssertTrue(boolVal.value)
        XCTAssertEqual("v-disabled-t", boolVal.variant)
        XCTAssertEqual(Reason.targetingMatch.rawValue, boolVal.reason)
        
        let ctxCustom = MutableContext(targetingKey: "example@matching.com", structure: MutableStructure(attributes: [
            "custom-anything": Value.string("something")
        ]))
        
        let customBoolVal = provider.getBooleanEvaluation(key: "disabledFeature", defaultValue: false, context: ctxCustom)
        XCTAssertTrue(customBoolVal.value)
        XCTAssertEqual("v-disabled-t", customBoolVal.variant)
        XCTAssertEqual(Reason.targetingMatch.rawValue, customBoolVal.reason)
    }
    
    func testDateTargeting() {
        let provider = ConfigCatProvider(sdkKey: "localhost") { opts in
            opts.flagOverrides = try! BundleResourceDataSource(path: "test_json_complex.json", behaviour: .localOnly)
            opts.logLevel = .debug
        }
        
        let ctx = MutableContext(targetingKey: "example@matching.com", structure: MutableStructure(attributes: [
            "Date": Value.date(parseDate(val: "2025-05-30T10:15:30.00Z"))
        ]))
        
        let boolVal = provider.getBooleanEvaluation(key: "dateTargeting", defaultValue: false, context: ctx)
        XCTAssertTrue(boolVal.value)
        XCTAssertEqual("date-targeting", boolVal.variant)
        XCTAssertEqual(Reason.targetingMatch.rawValue, boolVal.reason)
    }
    
    func testErrors() {
        let provider = ConfigCatProvider(sdkKey: "localhost") { opts in
            opts.flagOverrides = try! BundleResourceDataSource(path: "test_json_complex.json", behaviour: .localOnly)
        }
        
        let boolVal = provider.getBooleanEvaluation(key: "non-existing", defaultValue: false, context: nil)
        XCTAssertFalse(boolVal.value)
        XCTAssertEqual(ErrorCode.flagNotFound, boolVal.errorCode)
        XCTAssertEqual(Reason.error.rawValue, boolVal.reason)
        XCTAssertTrue(boolVal.errorMessage!.contains("Failed to evaluate setting 'non-existing' (the key was not found in config JSON)"))
        
        let mismatchResult = provider.getBooleanEvaluation(key: "stringSetting", defaultValue: false, context: nil)
        XCTAssertFalse(mismatchResult.value)
        XCTAssertEqual(ErrorCode.typeMismatch, mismatchResult.errorCode)
        XCTAssertEqual(Reason.error.rawValue, mismatchResult.reason)
    }
    
    func testInitialize() async {
        let provider = ConfigCatProvider(sdkKey: "localhost") { opts in
            opts.flagOverrides = try! BundleResourceDataSource(path: "test_json_complex.json", behaviour: .localOnly)
        }
        
        let expect = XCTestExpectation(description: "Initialization complete")
        let obs = provider.observe().sink { event in
            if event == .ready {
                expect.fulfill()
            }
        }
        
        await provider.initialize(initialContext: nil)
        await fulfillment(of: [expect])
        XCTAssertNotNil(obs)
    }
    
    func testReadyOnConfigChange() async {
        let json = loadResource(path: "test_json_complex.json")
        let cached = "1686756435844\ntest-etag\n" + json
        let cache = SingleValueCache(initValue: "")
        
        let provider = ConfigCatProvider(sdkKey: randomSdkKey()) { opts in
            opts.offline = true
            opts.configCache = cache
            opts.pollingMode = PollingModes.autoPoll(autoPollIntervalInSeconds: 1)
        }
        
        let start = Date()
        
        let expect = XCTestExpectation(description: "Initialization complete")
        let obs = provider.observe().sink { event in
            if event == .ready {
                expect.fulfill()
            }
        }
        
        await provider.initialize(initialContext: nil)
        
        try! cache.write(for: "", value: cached)
        
        await fulfillment(of: [expect])
        
        XCTAssertTrue(Date().timeIntervalSince(start) > 1)
        XCTAssertNotNil(obs)
    }
    
    func testOpenFeatureAPI() async {
        let provider = ConfigCatProvider(sdkKey: "localhost") { opts in
            opts.flagOverrides = try! BundleResourceDataSource(path: "test_json_complex.json", behaviour: .localOnly)
        }
        
        await OpenFeatureAPI.shared.setProviderAndWait(provider: provider)
        let client = OpenFeatureAPI.shared.getClient()
        
        let boolVal = client.getBooleanDetails(key: "enabledFeature", defaultValue: false)
        XCTAssertTrue(boolVal.value)
        XCTAssertEqual("v-enabled", boolVal.variant)
        XCTAssertEqual(Reason.defaultReason.rawValue, boolVal.reason)
    }
}
