# Centralize state with provider-specific modules

Use a singleton Quickshell service as the state owner across per-monitor bar widgets, without background polling. Keep Temporary Address, DuckDuckGo, and SimpleLogin as separate deep modules because their lifecycles and capabilities are materially different; share only credential and local-state modules. This avoids duplicated state across monitors and a shallow provider abstraction that would hide important differences.
