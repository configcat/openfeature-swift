# ConfigCat OpenFeature Provider for Swift

[![CI](https://github.com/configcat/openfeature-swift/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/configcat/openfeature-swift/actions/workflows/ci.yml)

This repository contains an OpenFeature provider that allows [ConfigCat](https://configcat.com) to be used with
the [OpenFeature Swift SDK](https://github.com/open-feature/swift-sdk).

## Installation

### Swift Package Manager

If you manage dependencies through SPM, in the dependencies section of Package.swift add:

```swift
.package(url: "https://github.com/configcat/openfeature-swift", from: "0.1.0")
```

and in the target dependencies section add:
```swift
.product(name: "ConfigCat", package: "openfeature-swift"),
```

### Xcode Dependencies

- Open the dependencies dialog from `File` > `Add Package Dependencies...`
- Search for `https://github.com/configcat/openfeature-swift` and click `Add Package`.

## Usage

The initializer of `ConfigCatProvider` takes the SDK key and an optional `ConfigCatOptions`
argument containing the additional configuration options for
the [ConfigCat Swift SDK](https://github.com/configcat/swift-sdk):

```swift
import ConfigCatOpenFeature
import ConfigCat
import OpenFeature

Task {
    // Configure the provider.
    let provider = ConfigCatProvider(sdkKey: "<YOUR-CONFIGCAT-SDK-KEY>") { opts in
        opts.pollingMode = PollingModes.autoPoll()
    }

    // Configure the OpenFeature API with the ConfigCat provider.
    await OpenFeatureAPI.shared.setProviderAndWait(provider: provider)

    // Create a client.
    let client = OpenFeatureAPI.shared.getClient()

    // Evaluate feature flag.
    let isAwesomeFeatureEnabled = client.getBooleanValue(key: "isAwesomeFeatureEnabled", defaultValue: false)
}
```

For more information about all the configuration options, see
the [Swift SDK documentation](https://configcat.com/docs/sdk-reference/ios/#creating-the-configcat-client).

## Need help?

https://configcat.com/support

## Contributing

Contributions are welcome. For more info please read the [Contribution Guideline](CONTRIBUTING.md).

## About ConfigCat

ConfigCat is a feature flag and configuration management service that lets you separate releases from deployments. You
can turn your features ON/OFF using <a href="https://app.configcat.com" target="_blank">ConfigCat Dashboard</a> even
after they are deployed. ConfigCat lets you target specific groups of users based on region, email or any other custom
user attribute.

ConfigCat is a <a href="https://configcat.com" target="_blank">hosted feature flag service</a>. Manage feature toggles
across frontend, backend, mobile, desktop apps. <a href="https://configcat.com" target="_blank">Alternative to
LaunchDarkly</a>. Management app + feature flag SDKs.

- [Official ConfigCat SDKs for other platforms](https://github.com/configcat)
- [Documentation](https://configcat.com/docs)
- [Blog](https://configcat.com/blog)