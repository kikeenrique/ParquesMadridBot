import Foundation

enum ChangeDetector {
    /// Compares the saved state with the current one. A park counts as changed when its alert level or hours
    /// differ, or when it is new; the schedule date alone never counts. Parks seen before also get a
    /// change-log event, schedule-only changes included (same from/to code), so the history keeps the hours.
    static func detect(
        previous: [String: ParkState],
        current: [String: ParkState],
        detectedAt: String
    ) -> (changedParks: Set<String>, events: [ChangeEvent]) {
        var changedParks: Set<String> = []
        var events: [ChangeEvent] = []

        for (park, state) in current {
            guard let before = previous[park] else {
                changedParks.insert(park)
                continue
            }
            guard !before.sameAlert(as: state) else { continue }

            changedParks.insert(park)
            events.append(ChangeEvent(
                detectedAt: detectedAt,
                parque: park,
                fromCode: before.code,
                toCode: state.code,
                fromOpen: StatusFormatter.isOpen(before.code),
                toOpen: StatusFormatter.isOpen(state.code),
                fromHorario: before.horario,
                toHorario: state.horario
            ))
        }
        return (changedParks, events)
    }
}
