import Foundation
import PlnFlrLayout

extension Workspace.Project.State {
    var activeFloorVariant: FloorVariant? {
        floorVariants.last { $0.before != nil && !undoneFloorVariantIDs.contains($0.id) }
    }

    func floorsForPlanning(_ ids: [UUID]) throws -> [Workspace.Floor.State] {
        guard !ids.isEmpty, Set(ids).count == ids.count else { throw MaterialInputError.invalid }
        return try ids.map { id in
            guard let floor = floors.first(where: { $0.id == id }) else { throw MaterialInputError.invalid }
            return floor
        }
    }

    func resolvePlanningScope() throws -> [Workspace.Floor.State] {
        guard let planningScope else { throw PlanningScopeError.unselected }
        let ids: [UUID]
        switch planningScope {
        case .room(let id): ids = floors.filter { $0.roomID == id }.map(\.id)
        case .storey(let name):
            let members = Set(rooms.filter { $0.storeyID == name }.map(\.id))
            ids = floors.filter { members.contains($0.roomID) || $0.storey == name }.map(\.id)
        case .house: ids = floors.map(\.id)
        }
        guard !ids.isEmpty else { throw PlanningScopeError.empty }
        guard ids.allSatisfy({ id in floors.contains { $0.id == id } }) else {
            throw PlanningScopeError.missing
        }
        return try floorsForPlanning(ids)
    }

    var planningScopeMessage: String? {
        do {
            _ = try resolvePlanningScope()
            return selectedPlans == nil ? "Brak aktualnego wyniku dla zakresu. Wybierz Policz zakres." : nil
        } catch {
            return error.localizedDescription
        }
    }

    var selectedPlans: [Workspace.Floor.State]? {
        guard let selected = try? resolvePlanningScope(),
              plannedScope == planningScope,
              plannedInputs == selected.map(FloorSnapshot.init),
              selected.allSatisfy({ $0.plan != nil }) else { return nil }
        return selected
    }
}

extension Workspace.State {
    func canPlan(_ floors: [Workspace.Floor.State]) -> Bool {
        let ids = Set(floors.map(\.accessID))
        return hasPro || (ids.count == 1 && (freeRoomID == nil || ids.first == freeRoomID))
    }

    mutating func commitPlans(_ plans: [LayoutPlan], floors: [Workspace.Floor.State], projectIndex p: Int) {
        for (floor, plan) in zip(floors, plans) {
            if let f = projects[p].floors.firstIndex(where: { $0.id == floor.id }) {
                projects[p].floors[f].plan = plan
                projects[p].floors[f].error = nil
            }
        }
        if let resolved = try? projects[p].resolvePlanningScope(), resolved.map(\.id) == floors.map(\.id) {
            projects[p].plannedScope = projects[p].planningScope
            projects[p].plannedInputs = floors.map(FloorSnapshot.init)
        }
        if !hasPro && freeRoomID == nil { freeRoomID = floors.first?.accessID }
        projects[p].error = nil
    }

    mutating func planFloors(_ ids: [UUID], projectID: UUID) {
        guard let p = projects.firstIndex(where: { $0.id == projectID }) else { return }
        do {
            let floors = try projects[p].floorsForPlanning(ids)
            guard canPlan(floors) else {
                isPaywallPresented = true
                return
            }
            let plans = try floors.map { try $0.makePlan() }
            commitPlans(plans, floors: floors, projectIndex: p)
        } catch {
            if ids.count != 1 { projects[p].error = error.localizedDescription }
            for f in projects[p].floors.indices where ids.contains(projects[p].floors[f].id) {
                projects[p].floors[f].error = error.localizedDescription
            }
        }
    }

    mutating func refreshPlans() {
        for p in projects.indices {
            let active = projects[p].activeFloorVariant
            for f in projects[p].floors.indices {
                let floor = projects[p].floors[f]
                guard floor.plan != nil || active?.floorIDs.contains(floor.id) == true else { continue }
                guard hasPro || floor.accessID == freeRoomID else {
                    projects[p].floors[f].plan = nil
                    continue
                }
                do {
                    projects[p].floors[f].plan = try floor.makePlan()
                    projects[p].floors[f].error = nil
                } catch {
                    projects[p].floors[f].plan = nil
                    projects[p].floors[f].error = error.localizedDescription
                }
            }
            if let active, let index = projects[p].floorVariants.firstIndex(where: { $0.id == active.id }) {
                let floors = projects[p].floors.filter { active.floorIDs.contains($0.id) }
                if floors.count == active.floorIDs.count {
                    projects[p].floorVariants[index].inputs = floors.map(FloorSnapshot.init)
                }
            }
        }
    }
}

func approximateArea(_ mm2: Int) -> String {
    "≈ " + (Double(mm2) / 1_000_000).formatted(.number.precision(.fractionLength(0...2))) + " m²"
}
