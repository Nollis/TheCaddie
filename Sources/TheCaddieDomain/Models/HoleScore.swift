import Foundation

public struct HoleScore: Equatable, Sendable {
    public let holeNumber: Int
    public let strokes: Int
    public let putts: Int
    public let fairwayHit: Bool?  // nil for par 3s
    public let greenInRegulation: Bool

    public init(
        holeNumber: Int,
        strokes: Int,
        putts: Int,
        fairwayHit: Bool?,
        greenInRegulation: Bool
    ) {
        self.holeNumber = holeNumber
        self.strokes = strokes
        self.putts = putts
        self.fairwayHit = fairwayHit
        self.greenInRegulation = greenInRegulation
    }
}
