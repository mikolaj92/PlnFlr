import Foundation
import PlnFlrLayout

extension Workspace.Project.State {
    var activeFloorVariant: FloorVariant? {
        floorVariants.last { $0.before != nil && !undoneFloorVariantIDs.contains($0.id) }
    }

    var selectedPlans: [Workspace.Floor.State]? {
        guard let selected = try? floorsForPlanning(selectedFloorIDs),
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
            projects[p].error = error.localizedDescription
            for f in projects[p].floors.indices where ids.contains(projects[p].floors[f].id) {
                projects[p].floors[f].error = error.localizedDescription
            }
        }
    }

    mutating func refreshPlans() {
        for p in projects.indices {
            let active = projects[p].activeFloorVariant
            if let active {
                do {
                    let floors = try projects[p].floorsForPlanning(active.floorIDs)
                    guard canPlan(floors), hasPro || floors.allSatisfy({ $0.accessID == freeRoomID }) else {
                        throw FloorPlanningError.accessRequired
                    }
                    guard active.inputs == floors.map(FloorSnapshot.init) else {
                        throw FloorPlanningError.changedInputs
                    }
                    let plans = try floors.map { try $0.makePlan() }
                    commitPlans(plans, floors: floors, projectIndex: p)
                } catch {
                    for f in projects[p].floors.indices where active.floorIDs.contains(projects[p].floors[f].id) {
                        projects[p].floors[f].plan = nil
                        projects[p].floors[f].error = error.localizedDescription
                    }
                    projects[p].error = error.localizedDescription
                }
            }
            for f in projects[p].floors.indices {
                let floor = projects[p].floors[f]
                guard active?.floorIDs.contains(floor.id) != true, floor.plan != nil else { continue }
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
        }
    }
}

func approximateArea(_ mm2: Int) -> String {
    "≈ " + (Double(mm2) / 1_000_000).formatted(.number.precision(.fractionLength(0...2))) + " m²"
}
