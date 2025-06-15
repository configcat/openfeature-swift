import Combine
import ConfigCat
import Foundation
import OpenFeature

/// Describes the ConfigCat OpenFeature metadata.
public struct ConfigCatProviderMetadata: ProviderMetadata {
    public var name: String? = "ConfigCatProvider"
}

/// Describes the ConfigCat OpenFeature provider.
public class ConfigCatProvider: FeatureProvider {
    public var hooks: [any Hook] = []
    public var metadata: ProviderMetadata = ConfigCatProviderMetadata()

    private let eventHandler = EventHandler()

    public let client: ConfigCatClient

    @Synced private var initialized: Bool = false
    @Synced private var snapshot: ConfigCatClientSnapshot?
    @Synced private var user: ConfigCatUser?

    public convenience init(
        sdkKey: String,
        configurator: (ConfigCatOptions) -> Void
    ) {
        let opts = ConfigCatOptions.default
        configurator(opts)
        self.init(sdkKey: sdkKey, options: opts)
    }

    public init(sdkKey: String, options: ConfigCatOptions? = nil) {
        self.client = ConfigCatClient.get(sdkKey: sdkKey, options: options)
        self.client.hooks.addOnConfigChanged { [weak self] _, snapshot in
            guard let self else {
                return
            }
            self.snapshot = snapshot
            if snapshot.cacheState != .noFlagData
                && self._initialized.testAndSet(expect: false, new: true)
            {
                self.eventHandler.send(.ready)
            }
        }
    }

    public func initialize(initialContext: EvaluationContext?) async {
        let initialUser = initialContext?.toUserObject()
        self.user = initialUser
        let state = await self.client.waitForReady()
        if state != .noFlagData {
            let snapshot = self.client.snapshot()
            self.snapshot = snapshot
            if self._initialized.testAndSet(expect: false, new: true) {
                self.eventHandler.send(.ready)
            }
        }
    }

    public func onContextSet(
        oldContext: EvaluationContext?,
        newContext: EvaluationContext
    ) async {
        let user = newContext.toUserObject()
        self.user = user
    }

    public func getBooleanEvaluation(
        key: String,
        defaultValue: Bool,
        context: EvaluationContext?
    ) -> ProviderEvaluation<Bool> {
        return eval(key: key, defaultValue: defaultValue, context: context)
    }

    public func getStringEvaluation(
        key: String,
        defaultValue: String,
        context: EvaluationContext?
    ) -> ProviderEvaluation<String> {
        return eval(key: key, defaultValue: defaultValue, context: context)
    }

    public func getIntegerEvaluation(
        key: String,
        defaultValue: Int64,
        context: EvaluationContext?
    ) -> ProviderEvaluation<Int64> {
        let intResult = eval(key: key, defaultValue: 0, context: context)
        if let err = intResult.errorCode {
            return ProviderEvaluation(
                value: defaultValue,
                reason: intResult.reason,
                errorCode: err,
                errorMessage: intResult.errorMessage
            )
        }
        return intResult.with(value: Int64(intResult.value))
    }

    public func getDoubleEvaluation(
        key: String,
        defaultValue: Double,
        context: EvaluationContext?
    ) -> ProviderEvaluation<Double> {
        return eval(key: key, defaultValue: defaultValue, context: context)
    }

    public func getObjectEvaluation(
        key: String,
        defaultValue: OpenFeature.Value,
        context: EvaluationContext?
    ) -> ProviderEvaluation<Value> {
        let stringResult = eval(key: key, defaultValue: "", context: context)
        if let err = stringResult.errorCode {
            return ProviderEvaluation(
                value: defaultValue,
                reason: stringResult.reason,
                errorCode: err,
                errorMessage: stringResult.errorMessage
            )
        }

        guard let jsonObject: Any = fromJson(json: stringResult.value)
        else {
            return ProviderEvaluation(
                value: defaultValue,
                reason: Reason.error.rawValue,
                errorCode: .typeMismatch,
                errorMessage: String(
                    format: "Could not parse '%@' as JSON",
                    stringResult.value
                )
            )
        }
        
        return stringResult.with(value: anyToValue(value: jsonObject))
    }

    private func eval<T>(
        key: String,
        defaultValue: T,
        context: EvaluationContext?
    ) -> ProviderEvaluation<T> {
        let snapshot = self.snapshot ?? self.client.snapshot()
        let user = self.user ?? context?.toUserObject()
        let details = snapshot.getValueDetails(
            for: key,
            defaultValue: defaultValue,
            user: user
        )
        return details.toProviderEvaluation()
    }

    public func observe() -> AnyPublisher<ProviderEvent?, Never> {
        return eventHandler.observe()
    }

    func fromJson(json: String) -> Any? {
        guard let data = json.data(using: .utf8) else {
            return nil
        }
        guard let result = try? JSONSerialization.jsonObject(with: data, options: [])
        else {
            return nil
        }
        return result
    }

    func anyToValue(value: Any) -> Value {
        return switch value {
        case let val as String: .string(val)
        case let val as Bool: .boolean(val)
        case let val as Double: .double(val)
        case let val as Int64: .integer(val)
        case let val as Int: .integer(Int64(val))
        case let val as Date: .date(val)
        case let val as [Any]: .list(val.map(anyToValue))
        case let val as [String: Any]: .structure(val.reduce(into: [String: Value]()) { (part, arg) in
            part[arg.key] = anyToValue(value: arg.value)
        })
        default: Value.null
        }
    }
}

extension EvaluationContext {
    func toUserObject() -> ConfigCatUser {
        ConfigCatUser(
            identifier: self.getTargetingKey(),
            email: self.getValue(key: "Email")?.asString(),
            country: self.getValue(key: "Country")?.asString(),
            custom: self.asObjectMap().filter { $1 != nil }.reduce(
                into: [String: Any]()
            ) { (part, arg) in
                part[arg.key] = arg.value as Any
            }
        )
    }
}

extension TypedEvaluationDetails {
    func toProviderEvaluation() -> ProviderEvaluation<Value> {
        ProviderEvaluation(
            value: self.value,
            variant: self.variationId,
            reason: self.toReason().rawValue,
            errorCode: self.toErrorCode(),
            errorMessage: self.error
        )
    }

    func toReason() -> Reason {
        if self.errorCode != .none {
            return .error
        }

        if self.matchedTargetingRule != nil
            || self.matchedPercentageOption != nil
        {
            return .targetingMatch
        }
        return .defaultReason
    }

    func toErrorCode() -> ErrorCode? {
        return switch self.errorCode {
        case .invalidUserInput: .general
        case .unexpectedError: .general
        case .none: nil
        case .invalidConfigModel: .parseError
        case .settingValueTypeMismatch: .typeMismatch
        case .configJsonNotAvailable: .parseError
        case .settingKeyMissing: .flagNotFound
        }
    }
}

extension ProviderEvaluation {
    func with<V>(value: V) -> ProviderEvaluation<V> {
        return ProviderEvaluation<V>(
            value: value,
            flagMetadata: self.flagMetadata,
            variant: self.variant,
            reason: self.reason,
            errorCode: self.errorCode,
            errorMessage: self.errorMessage
        )
    }
}
