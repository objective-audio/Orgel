import Combine
import Foundation
import Orgel

enum TopAction: CaseIterable {
    case createA
    case createB
    case insertA
    case insertB
    case undo
    case redo
    case clear
    case purge
    case saveChanged
    case cancelChanged
}

final class TopPresenter: PresenterForTopView {
    @Published private(set) var currentSaveId: Int64 = 0
    @Published private(set) var lastSaveId: Int64 = 0
    @Published private(set) var isProcessing: Bool = false
    @Published var error: Error?

    var aObjectsCount: Int {
        interactor.objects[.a]?.count ?? 0
    }

    func aObject(at index: Int) -> SyncedObject? {
        interactor.objects[.a]?.elements[index].value
    }

    var bObjectsCount: Int { interactor.objects[.b]?.count ?? 0 }

    func bObject(at index: Int) -> SyncedObject? {
        interactor.objects[.b]?.elements[index].value
    }

    var isAlertShown: Bool {
        get { error != nil }
        set { error = nil }
    }

    private let interactor: Interactor
    private weak var navigationLifecycle: RootNavigationLifecycle?

    private var cancellables: Set<AnyCancellable> = []

    init?() {
        guard let lifetime = Lifetime.rootNavigation else {
            return nil
        }

        self.interactor = lifetime.interactor
        self.navigationLifecycle = lifetime.lifecycle

        interactor.infoPublisher.sink { [weak self] info in
            guard let self else { return }
            self.currentSaveId = info.currentSaveId
            self.lastSaveId = info.lastSaveId
        }.store(in: &cancellables)

        interactor.objectsPublisher.sink { [weak self] value in
            guard let self else { return }
            self.objectWillChange.send()
        }.store(in: &cancellables)

        interactor.eventPublisher.sink { [weak self] event in
            self?.eventDidReceive(event)
        }.store(in: &cancellables)

        interactor.isProcessingPublisher.sink { [weak self] isProcessing in
            self?.isProcessing = isProcessing
        }.store(in: &cancellables)
    }

    func performAction(_ action: TopAction) {
        switch action {
        case .createA:
            interactor.createObject(entityName: .a)
        case .createB:
            interactor.createObject(entityName: .b)
        case .insertA:
            interactor.insert(entityName: .a)
        case .insertB:
            interactor.insert(entityName: .b)
        case .undo:
            interactor.undo()
        case .redo:
            interactor.redo()
        case .clear:
            interactor.clear()
        case .purge:
            interactor.purge()
        case .saveChanged:
            interactor.saveChanged()
        case .cancelChanged:
            interactor.cancelChanged()
        }
    }

    func isAvailable(forAction action: TopAction) -> Bool {
        return !isProcessing && interactor.isAvailable(forAction: action)
    }

    func showObject(at index: Int, entityName: Entity.Name) {
        guard let object = interactor.objects[entityName]?.elements[index].value, object.isAvailable
        else {
            return
        }
        navigationLifecycle?.showObject(id: object.id, entityName: entityName)
    }

    func deleteObject(indexSet: IndexSet, entityName: Entity.Name) {
        interactor.remove(entityName: entityName, indexSet: indexSet)
    }
}

extension TopPresenter {
    private func eventDidReceive(_ event: Interactor.Event) {
        switch event {
        case let .operationFailed(error):
            self.error = error
        }
    }
}

extension Interactor {
    fileprivate func isAvailable(forAction action: TopAction) -> Bool {
        switch action {
        case .createA, .createB:
            true
        case .insertA, .insertB:
            canInsert
        case .undo:
            canUndo
        case .redo:
            canRedo
        case .clear:
            canClear
        case .purge:
            canPurge
        case .saveChanged, .cancelChanged:
            hasChanged
        }
    }
}
