import Combine
import Foundation

@MainActor
final class CaddieViewModel: ObservableObject {
    @Published private(set) var course: Course?
    @Published private(set) var player: PlayerContext
    @Published private(set) var roundState: RoundState

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
        CaddieViewState.make(from: packet)
    }

    func loadSample() {
        course = SampleRound.course
        player = SampleRound.player
        roundState = SampleRound.roundState
    }

    func markLie(_ lie: ShotLie) {
        let currentShot = roundState.currentShotContext() ?? SampleRound.readyShot
        let updatedShot = ShotContext(
            shotNumber: currentShot.shotNumber,
            remainingDistanceM: currentShot.remainingDistanceM,
            lie: .known(lie),
            wind: currentShot.wind
        )
        roundState = roundState.updateShotContext(updatedShot)
    }

    func addDistance(_ distanceM: Double) {
        let currentShot = roundState.currentShotContext() ?? SampleRound.readyShot
        let updatedShot = ShotContext(
            shotNumber: currentShot.shotNumber,
            remainingDistanceM: .known(distanceM),
            lie: currentShot.lie,
            wind: currentShot.wind
        )
        roundState = roundState.updateShotContext(updatedShot)
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
}
