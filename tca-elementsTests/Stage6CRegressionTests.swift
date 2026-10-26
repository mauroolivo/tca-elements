import XCTest
import ComposableArchitecture
@testable import tca_elements

@MainActor
final class Stage6CRegressionTests: XCTestCase {
    func testDeletingTaskFromListAlsoRemovesMatchingDetail() async {
        let task = TaskItem(id: 7, title: "Open detail", isDone: false)

        var initialState = AppFeature.State()
        initialState.tasksFeature.tasks = [TaskRowFeature.State(task: task)]
        initialState.tasksFeature.tasksPhase = .loaded
        initialState.detailPath.append(TaskDetailFeature.State(task: task))

        let store = TestStore(initialState: initialState) {
            AppFeature()
        }

        await store.send(.tasksFeature(.delegate(.taskDeleted(task.id)))) {
            $0.tasksFeature.tasks = []
            $0.tasksFeature.tasksPhase = .idle
            $0.detailPath = StackState()
        }
    }

    func testDeletingTaskFromDetailAlsoRemovesListRowAndResetsIdleWhenEmpty() async {
        let task = TaskItem(id: 9, title: "Delete from detail", isDone: false)

        var initialState = AppFeature.State()
        initialState.tasksFeature.tasks = [TaskRowFeature.State(task: task)]
        initialState.tasksFeature.tasksPhase = .loaded
        initialState.detailPath.append(TaskDetailFeature.State(task: task))
        let detailID = initialState.detailPath.ids.first!

        let store = TestStore(initialState: initialState) {
            AppFeature()
        }

        await store.send(.detailPath(.element(id: detailID, action: .delegate(.taskDeleted(task.id))))) {
            $0.tasksFeature.tasks = []
            $0.tasksFeature.tasksPhase = .idle
            $0.detailPath = StackState()
        }
    }

    func testUpdatingTaskFromDetailKeepsListInSync() async {
        let originalTask = TaskItem(id: 13, title: "Original title", isDone: false)
        let updatedTask = TaskItem(id: 13, title: "Updated title", isDone: true)

        var initialState = AppFeature.State()
        initialState.tasksFeature.tasks = [TaskRowFeature.State(task: originalTask)]
        initialState.tasksFeature.tasksPhase = .loaded
        initialState.detailPath.append(TaskDetailFeature.State(task: originalTask))
        let detailID = initialState.detailPath.ids.first!

        let store = TestStore(initialState: initialState) {
            AppFeature()
        }

        await store.send(.detailPath(.element(id: detailID, action: .delegate(.taskUpdated(updatedTask))))) {
            $0.tasksFeature.tasks[id: updatedTask.id]?.task = updatedTask
            $0.tasksFeature.tasksPhase = .loaded
            $0.detailPath[id: detailID]?.task = originalTask
        }
    }
}
