//
// Copyright (c) 2026 Enjel Hutasoit
//

/// Adds device, app and network facts to `Event.context`.
public struct ContextEnricher: Plugin {
    public let name = "context-enricher"

    private let contextProvider: any ContextProvider
    private let networkStateProvider: any NetworkStateProvider

    public init(
        contextProvider: any ContextProvider = SystemContextProvider(),
        networkStateProvider: any NetworkStateProvider = UnknownNetworkStateProvider()
    ) {
        self.contextProvider = contextProvider
        self.networkStateProvider = networkStateProvider
    }

    public func process(_ event: Event) async -> Event? {
        let environment = await contextProvider.current()
        let network = await networkStateProvider.current()

        var enriched = event
        enriched.context.merge(environment.properties) { _, new in new }
        enriched.context["network"] = .string(network.rawValue)
        return enriched
    }
}
