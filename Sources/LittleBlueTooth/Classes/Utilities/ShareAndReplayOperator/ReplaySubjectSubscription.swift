import Foundation
import Combine

/// A class representing the connection of a subscriber to a publisher.
public final class ReplaySubjectSubscription<Output, Failure: Error>: Subscription {
    private let downstream: AnySubscriber<Output, Failure>
    private var isCompleted = false
    private var demand: Subscribers.Demand = .none

    public init(downstream: AnySubscriber<Output, Failure>) {
        self.downstream = downstream
    }

    // Tells a publisher that it may send more values to the subscriber.
    public func request(_ newDemand: Subscribers.Demand) {
        demand += newDemand
    }

    public func cancel() {
        isCompleted = true
    }

    public func receive(_ value: Output) {
        guard !isCompleted, demand > 0 else { return }

        demand += downstream.receive(value)
        demand -= 1
    }

    public func receive(completion: Subscribers.Completion<Failure>) {
        guard !isCompleted else { return }
        isCompleted = true
        downstream.receive(completion: completion)
    }

    public func replay(_ values: [Output], completion: Subscribers.Completion<Failure>?) {
        guard !isCompleted else { return }
        values.forEach { value in receive(value) }
        if let completion = completion { receive(completion: completion) }
    }
}
