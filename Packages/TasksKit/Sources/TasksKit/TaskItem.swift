import Foundation

public struct TaskItem: Equatable, Identifiable, Sendable {
    public let id: Int
    public var title: String
    public var isDone: Bool

    public init(id: Int, title: String, isDone: Bool) {
        self.id = id
        self.title = title
        self.isDone = isDone
    }
}
