public struct SerialPlaybackQueue<Element: Equatable> {
    private var pending: [Element] = []
    public private(set) var current: Element?

    public var isIdle: Bool { current == nil && pending.isEmpty }

    public init() {}

    public mutating func enqueue(_ items: [Element]) {
        pending.append(contentsOf: items)
    }

    public mutating func startNext() -> Element? {
        guard current == nil, !pending.isEmpty else { return nil }
        current = pending.removeFirst()
        return current
    }

    public mutating func finishCurrent() -> Element? {
        current = nil
        return startNext()
    }

    public mutating func finishCurrent(matching completed: Element) -> Element? {
        guard current == completed else { return nil }
        return finishCurrent()
    }

    public mutating func clear() {
        current = nil
        pending.removeAll()
    }
}
