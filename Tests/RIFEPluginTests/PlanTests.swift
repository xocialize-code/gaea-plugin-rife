import Foundation
import GaeaProtocol
import RIFEPlugin
import Testing

@Suite struct PlanTests {
    @Test func theRequestCarriesTheVideoAndFactor() {
        let r = request(video: Data([1, 2, 3]), factor: 4)
        #expect(r.factor == 4 && r.video.data == Data([1, 2, 3]) && r.video.format == .mp4)
    }

    @Test func theOfferStatesItsLimits() {
        #expect(maxFactor == 8 && maxWidth == 3840 && maxHeight == 2160)
    }
}
