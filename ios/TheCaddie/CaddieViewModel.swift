import Combine
import Foundation

@MainActor
final class CaddieViewModel: ObservableObject {
    @Published private(set) var course: Course?
    @Published private(set) var player: PlayerContext
    @Published private(set) var roundState: RoundState
    @Published var isHandsFreeListening: Bool = false

    init(
        course: Course?,
        player: PlayerContext,
        roundState: RoundState
    ) {
        self.course = course
        self.player = player
        self.roundState = roundState
    }

    var packet: CaddieRecommendationPacket {
        CaddieRecommendationEngine.build(
            course: course,
            player: player,
            roundState: roundState
        )
    }

    var viewState: CaddieViewState {
        CaddieViewState.make(
            from: packet,
            roundState: roundState,
            course: course
        )
    }

    var selectedHoleNumber: Int {
        roundState.selectedHoleNumber
    }

    var availableHoleNumbers: [Int] {
        course?.holes.map(\.number) ?? []
    }

    var canSelectPreviousHole: Bool {
        guard let currentIndex = availableHoleNumbers.firstIndex(of: selectedHoleNumber) else {
            return false
        }

        return currentIndex > availableHoleNumbers.startIndex
    }

    var canSelectNextHole: Bool {
        guard let currentIndex = availableHoleNumbers.firstIndex(of: selectedHoleNumber) else {
            return false
        }

        return currentIndex < availableHoleNumbers.index(before: availableHoleNumbers.endIndex)
    }

    func loadSample() {
        course = KungsbackaNyaCourse.course
        player = SampleRound.player
        roundState = KungsbackaNyaCourse.openingRoundState
    }

    func markLie(_ lie: ShotLie) {
        let currentShot = resolvedShotContext()
        let updatedShot = ShotContext(
            shotNumber: currentShot.shotNumber,
            remainingDistanceM: currentShot.remainingDistanceM,
            lie: .known(lie),
            wind: currentShot.wind
        )
        roundState = roundState.updateShotContext(updatedShot)
    }

    func recordShotResult(_ lie: ShotLie) {
        roundState = roundState.recordShotResult(
            course: course,
            player: player,
            resultingLie: lie
        )
    }

    func recordQuickAction(_ action: CaddieViewState.QuickAction.Kind) {
        switch action {
        case .fairway:
            recordShotResult(.fairway)
        case .rough:
            recordShotResult(.rough)
        case .bunker:
            recordShotResult(.bunker)
        case .green:
            recordShotResult(.green)
        case .holed:
            finishCurrentHole()
        }
    }

    func selectHole(_ holeNumber: Int) {
        guard availableHoleNumbers.contains(holeNumber) else {
            return
        }

        roundState = roundState.selectHole(holeNumber)
    }

    func selectPreviousHole() {
        guard let currentIndex = availableHoleNumbers.firstIndex(of: selectedHoleNumber),
              currentIndex > availableHoleNumbers.startIndex else {
            return
        }

        let previousIndex = availableHoleNumbers.index(before: currentIndex)
        selectHole(availableHoleNumbers[previousIndex])
    }

    func selectNextHole() {
        guard let currentIndex = availableHoleNumbers.firstIndex(of: selectedHoleNumber),
              currentIndex < availableHoleNumbers.index(before: availableHoleNumbers.endIndex) else {
            return
        }

        let nextIndex = availableHoleNumbers.index(after: currentIndex)
        selectHole(availableHoleNumbers[nextIndex])
    }

    func addDistance(_ distanceM: Double) {
        let currentShot = resolvedShotContext()
        let updatedShot = ShotContext(
            shotNumber: currentShot.shotNumber,
            remainingDistanceM: .known(distanceM),
            lie: currentShot.lie,
            wind: currentShot.wind
        )
        roundState = roundState.updateShotContext(updatedShot)
    }

    func finishCurrentHole() {
        roundState = roundState.finishCurrentHole(course: course)
    }

    func finishHoleFromGreen(putts: Int) {
        guard let course,
              let hole = course.hole(number: selectedHoleNumber) else {
            return
        }
        let shotNumber = roundState.currentShotContext()?.shotNumber ?? 1
        let finalStrokes = shotNumber + putts - 1
        let finalFairwayHit = hole.par > 3 ? true : nil
        let finalGIR = (finalStrokes - putts) <= (hole.par - 2)
        
        roundState = roundState.finishCurrentHole(
            course: course,
            strokes: finalStrokes,
            putts: putts,
            fairwayHit: finalFairwayHit,
            greenInRegulation: finalGIR
        )
    }

    func selectNextOpenHole() {
        guard let course else {
            return
        }

        if let nextHole = course.holes.first(where: { hole in
            hole.number > selectedHoleNumber
                && !roundState.completedHoleNumbers.contains(hole.number)
        }) {
            selectHole(nextHole.number)
            return
        }

        if let firstOpenHole = course.holes.first(where: { hole in
            !roundState.completedHoleNumbers.contains(hole.number)
        }) {
            selectHole(firstOpenHole.number)
        }
    }

    func startRound(course: Course, startingHole: Int = 1) {
        self.course = course
        self.roundState = RoundState(
            courseId: course.id,
            selectedHoleNumber: startingHole,
            shotContexts: [
                startingHole: ShotContext(
                    shotNumber: 1,
                    remainingDistanceM: .known(course.hole(number: startingHole)?.teeLengthM ?? 300),
                    lie: .known(.tee),
                    wind: nil
                )
            ]
        )
    }
    
    func endRound() {
        self.course = nil
        self.roundState = SampleRound.roundState
    }

    func updatePlayerHandicap(_ handicap: Double) {
        self.player = PlayerContext(
            handicapIndex: handicap,
            clubs: player.clubs,
            strategyPreference: player.strategyPreference
        )
    }
    
    func updateStrategyPreference(_ strategy: StrategyPreference) {
        self.player = PlayerContext(
            handicapIndex: player.handicapIndex,
            clubs: player.clubs,
            strategyPreference: strategy
        )
    }

    func updateClubDistance(clubName: String, distanceM: Double) {
        var updatedClubs = player.clubs
        if let index = updatedClubs.firstIndex(where: { $0.name == clubName }) {
            let original = updatedClubs[index]
            updatedClubs[index] = PlayerClub(
                name: original.name,
                carryDistanceM: distanceM,
                typicalDispersionM: original.typicalDispersionM,
                playableLies: original.playableLies
            )
            self.player = PlayerContext(
                handicapIndex: player.handicapIndex,
                clubs: updatedClubs,
                strategyPreference: player.strategyPreference
            )
        }
    }

    func updateHoleScore(holeNumber: Int, strokes: Int, putts: Int, fairwayHit: Bool?, gir: Bool) {
        var updatedScores = roundState.holeScores
        updatedScores[holeNumber] = HoleScore(
            holeNumber: holeNumber,
            strokes: strokes,
            putts: putts,
            fairwayHit: fairwayHit,
            greenInRegulation: gir
        )
        self.roundState = RoundState(
            courseId: roundState.courseId,
            selectedHoleNumber: roundState.selectedHoleNumber,
            shotContexts: roundState.shotContexts,
            completedHoleNumbers: roundState.completedHoleNumbers.union([holeNumber]),
            holeScores: updatedScores
        )
    }

    private func resolvedShotContext() -> ShotContext {
        if let shot = roundState.currentShotContext() {
            return shot
        }

        if let course,
           let hole = course.hole(number: selectedHoleNumber) {
            return ShotContext(
                shotNumber: 1,
                remainingDistanceM: .known(hole.teeLengthM),
                lie: .known(.tee),
                wind: nil
            )
        }

        return SampleRound.readyShot
    }
}

extension CaddieViewModel {
    static func sample() -> CaddieViewModel {
        CaddieViewModel(
            course: KungsbackaNyaCourse.course,
            player: SampleRound.player,
            roundState: KungsbackaNyaCourse.openingRoundState
        )
    }

    static func noCourseLoaded() -> CaddieViewModel {
        CaddieViewModel(
            course: nil,
            player: SampleRound.player,
            roundState: SampleRound.roundState
        )
    }

    static func missingDistance() -> CaddieViewModel {
        CaddieViewModel(
            course: SampleRound.course,
            player: SampleRound.player,
            roundState: SampleRound.missingDistanceRoundState
        )
    }

    static func missingLie() -> CaddieViewModel {
        CaddieViewModel(
            course: SampleRound.course,
            player: SampleRound.player,
            roundState: SampleRound.missingLieRoundState
        )
    }

    static func onGreen() -> CaddieViewModel {
        CaddieViewModel(
            course: SampleRound.course,
            player: SampleRound.player,
            roundState: SampleRound.roundState.updateShotContext(
                ShotContext(
                    shotNumber: 3,
                    remainingDistanceM: .known(0),
                    lie: .known(.green),
                    wind: nil
                )
            )
        )
    }

    static func holeComplete() -> CaddieViewModel {
        CaddieViewModel(
            course: KungsbackaNyaCourse.course,
            player: SampleRound.player,
            roundState: RoundState(
                courseId: KungsbackaNyaCourse.course.id,
                selectedHoleNumber: 8,
                shotContexts: [
                    8: ShotContext(
                        shotNumber: 3,
                        remainingDistanceM: .known(0),
                        lie: .known(.green),
                        wind: nil
                    )
                ],
                completedHoleNumbers: [8]
            )
        )
    }

    static func roundComplete() -> CaddieViewModel {
        CaddieViewModel(
            course: SampleRound.course,
            player: SampleRound.player,
            roundState: RoundState(
                courseId: SampleRound.course.id,
                selectedHoleNumber: 2,
                shotContexts: [
                    2: ShotContext(
                        shotNumber: 3,
                        remainingDistanceM: .known(0),
                        lie: .known(.green),
                        wind: nil
                    )
                ],
                completedHoleNumbers: [1, 2]
            )
        )
    }
}
