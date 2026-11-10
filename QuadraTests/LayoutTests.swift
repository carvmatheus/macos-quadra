import XCTest

final class ScreenGeometryTests: XCTestCase {
    func testFlipConvertsBetweenCocoaAndAccessibilitySpace() {
        // Primary screen 1000pt tall; a 100pt rect sitting 50pt above the bottom edge
        // is 850pt below the top edge in Accessibility (top-left origin) space.
        let cocoa = CGRect(x: 10, y: 50, width: 200, height: 100)
        let ax = ScreenGeometry.flip(cocoa, primaryHeight: 1000)
        XCTAssertEqual(ax, CGRect(x: 10, y: 850, width: 200, height: 100))
        XCTAssertEqual(ScreenGeometry.flip(ax, primaryHeight: 1000), cocoa)
    }

    func testNeighborToTheRightPicksClosestScreen() {
        let main = CGRect(x: 0, y: 0, width: 1440, height: 900)
        let right = CGRect(x: 1440, y: 0, width: 1920, height: 1080)
        let farRight = CGRect(x: 3360, y: 0, width: 1920, height: 1080)
        let frames = [main, farRight, right]
        XCTAssertEqual(ScreenGeometry.neighbor(of: main, in: frames, toward: .right), 2)
        XCTAssertEqual(ScreenGeometry.neighbor(of: right, in: frames, toward: .left), 0)
        XCTAssertNil(ScreenGeometry.neighbor(of: main, in: frames, toward: .left))
    }

    func testNeighborIgnoresScreensWithoutVerticalOverlap() {
        let main = CGRect(x: 0, y: 0, width: 1440, height: 900)
        let above = CGRect(x: 1440, y: 900, width: 1920, height: 1080)
        XCTAssertNil(ScreenGeometry.neighbor(of: main, in: [main, above], toward: .right))
    }

    func testApproximatelyEqual() {
        let a = CGRect(x: 0, y: 0, width: 720, height: 875)
        XCTAssertTrue(ScreenGeometry.approximatelyEqual(a, a.offsetBy(dx: 5, dy: -3), tolerance: 10))
        XCTAssertFalse(ScreenGeometry.approximatelyEqual(a, a.insetBy(dx: 20, dy: 0), tolerance: 10))
    }
}

final class SnapActionTests: XCTestCase {
    let visible = CGRect(x: 0, y: 25, width: 1441, height: 875)

    func testLeftHalf() {
        XCTAssertEqual(SnapAction.leftHalf.frame(in: visible), CGRect(x: 0, y: 25, width: 720, height: 875))
    }

    func testRightHalfTakesTheRemainder() {
        XCTAssertEqual(SnapAction.rightHalf.frame(in: visible), CGRect(x: 720, y: 25, width: 721, height: 875))
    }
}

final class ZoneLayoutTests: XCTestCase {
    let area = CGRect(x: 0, y: 0, width: 1200, height: 800)

    func testColumns() {
        let zones = ZoneLayout.columns(3).zones(in: area, spacing: 0)
        XCTAssertEqual(zones, [
            CGRect(x: 0, y: 0, width: 400, height: 800),
            CGRect(x: 400, y: 0, width: 400, height: 800),
            CGRect(x: 800, y: 0, width: 400, height: 800),
        ])
    }

    func testRowsAreOrderedTopToBottom() {
        // Cocoa space: the visually top row has the largest y.
        let zones = ZoneLayout.rows(2).zones(in: area, spacing: 0)
        XCTAssertEqual(zones, [
            CGRect(x: 0, y: 400, width: 1200, height: 400),
            CGRect(x: 0, y: 0, width: 1200, height: 400),
        ])
    }

    func testGridIsNumberedLeftToRightTopToBottom() {
        let zones = ZoneLayout.grid(columns: 2, rows: 2).zones(in: area, spacing: 0)
        XCTAssertEqual(zones, [
            CGRect(x: 0, y: 400, width: 600, height: 400),
            CGRect(x: 600, y: 400, width: 600, height: 400),
            CGRect(x: 0, y: 0, width: 600, height: 400),
            CGRect(x: 600, y: 0, width: 600, height: 400),
        ])
    }

    func testPriorityGridHasWideCenter() {
        let widths = ZoneLayout.priority.zones(in: area, spacing: 0).map(\.width)
        XCTAssertEqual(widths, [300, 600, 300])
    }

    func testSpacingAppliesToEdgesAndBetweenZones() {
        let zones = ZoneLayout.columns(2).zones(in: CGRect(x: 0, y: 0, width: 100, height: 100), spacing: 10)
        XCTAssertEqual(zones, [
            CGRect(x: 10, y: 10, width: 35, height: 80),
            CGRect(x: 55, y: 10, width: 35, height: 80),
        ])
    }

    func testZoneIndexUnderPointIncludesGaps() {
        let zones = ZoneLayout.columns(2).zones(in: CGRect(x: 0, y: 0, width: 100, height: 100), spacing: 10)
        XCTAssertEqual(ZoneLayout.zoneIndex(at: CGPoint(x: 20, y: 50), in: zones, spacing: 10), 0)
        XCTAssertEqual(ZoneLayout.zoneIndex(at: CGPoint(x: 48, y: 50), in: zones, spacing: 10), 0)
        XCTAssertEqual(ZoneLayout.zoneIndex(at: CGPoint(x: 70, y: 50), in: zones, spacing: 10), 1)
        XCTAssertNil(ZoneLayout.zoneIndex(at: CGPoint(x: 500, y: 50), in: zones, spacing: 10))
    }

    func testIdRoundTripsForEveryPreset() {
        for layout in ZoneLayout.presets {
            XCTAssertEqual(ZoneLayout(id: layout.id), layout)
        }
    }
}

final class ZonePreferencesTests: XCTestCase {
    func testUnconfiguredDisplayUsesFallbackWithNoSpacing() {
        let prefs = ZonePreferences()
        XCTAssertEqual(prefs.zones(for: "A").layout, .default)
        XCTAssertEqual(prefs.zones(for: "A").spacing, 0)
    }

    func testEachDisplayKeepsItsOwnSettings() {
        var prefs = ZonePreferences()
        prefs.setLayout(.grid(columns: 2, rows: 2), for: "A")
        prefs.setSpacing(16, for: "B")
        XCTAssertEqual(prefs.zones(for: "A"), DisplayZones(layoutID: "grid-2x2", spacing: 0))
        XCTAssertEqual(prefs.zones(for: "B"), DisplayZones(layoutID: ZoneLayout.default.id, spacing: 16))
    }

    func testRoundTripsThroughJSON() throws {
        var prefs = ZonePreferences()
        prefs.setLayout(.columns(4), for: "A")
        let decoded = try JSONDecoder().decode(ZonePreferences.self, from: JSONEncoder().encode(prefs))
        XCTAssertEqual(decoded, prefs)
    }

    func testUnknownLayoutIdFallsBackToDefault() {
        XCTAssertEqual(DisplayZones(layoutID: "removed-layout", spacing: 0).layout, .default)
    }
}

final class FitTests: XCTestCase {
    // Built-in display: right half is 756pt wide, but Outlook refuses anything under 811pt.
    let visible = CGRect(x: 0, y: 0, width: 1512, height: 949)

    func testRightAlignedTargetKeepsOversizedWindowOnScreen() {
        let target = CGRect(x: 756, y: 0, width: 756, height: 949)
        let fitted = ScreenGeometry.fit(CGSize(width: 811, height: 949), into: target, within: visible)
        XCTAssertEqual(fitted, CGRect(x: 701, y: 0, width: 811, height: 949))
    }

    func testLeftAlignedTargetGrowsToTheRight() {
        let target = CGRect(x: 0, y: 0, width: 756, height: 949)
        let fitted = ScreenGeometry.fit(CGSize(width: 811, height: 949), into: target, within: visible)
        XCTAssertEqual(fitted, CGRect(x: 0, y: 0, width: 811, height: 949))
    }

    func testMiddleTargetGrowsAroundItsCenter() {
        let target = CGRect(x: 504, y: 0, width: 504, height: 949)
        let fitted = ScreenGeometry.fit(CGSize(width: 604, height: 949), into: target, within: visible)
        XCTAssertEqual(fitted, CGRect(x: 454, y: 0, width: 604, height: 949))
    }

    func testTopRowTargetStaysUnderTheMenuBar() {
        // Cocoa space: the top row ends at visible.maxY.
        let target = CGRect(x: 0, y: 475, width: 756, height: 474)
        let fitted = ScreenGeometry.fit(CGSize(width: 756, height: 600), into: target, within: visible)
        XCTAssertEqual(fitted, CGRect(x: 0, y: 349, width: 756, height: 600))
    }

    func testWindowThatFitsKeepsTarget() {
        let target = CGRect(x: 756, y: 0, width: 756, height: 949)
        XCTAssertEqual(ScreenGeometry.fit(target.size, into: target, within: visible), target)
    }
}

final class ZoneSelectionTests: XCTestCase {
    let area = CGRect(x: 0, y: 0, width: 1200, height: 800)

    func testCenterOfZoneSelectsOnlyThatZone() {
        let zones = ZoneLayout.columns(3).zones(in: area, spacing: 0)
        let selection = ZoneLayout.selection(at: CGPoint(x: 200, y: 400), in: zones, spacing: 0)
        XCTAssertEqual(selection, ZoneSelection(indices: [0], frame: zones[0]))
    }

    func testNearSharedEdgeSpansBothZones() {
        let zones = ZoneLayout.columns(3).zones(in: area, spacing: 0)
        let expected = ZoneSelection(indices: [0, 1], frame: CGRect(x: 0, y: 0, width: 800, height: 800))
        // Zone width 400 → the merge band reaches 40pt into each zone.
        XCTAssertEqual(ZoneLayout.selection(at: CGPoint(x: 370, y: 400), in: zones, spacing: 0), expected)
        XCTAssertEqual(ZoneLayout.selection(at: CGPoint(x: 430, y: 400), in: zones, spacing: 0), expected)
        XCTAssertEqual(ZoneLayout.selection(at: CGPoint(x: 350, y: 400), in: zones, spacing: 0)?.indices, [0])
    }

    func testScreenEdgeHasNothingToMergeWith() {
        let zones = ZoneLayout.columns(3).zones(in: area, spacing: 0)
        XCTAssertEqual(ZoneLayout.selection(at: CGPoint(x: 5, y: 400), in: zones, spacing: 0)?.indices, [0])
    }

    func testGridCenterSpansAllFourZones() {
        let zones = ZoneLayout.grid(columns: 2, rows: 2).zones(in: area, spacing: 0)
        let selection = ZoneLayout.selection(at: CGPoint(x: 590, y: 410), in: zones, spacing: 0)
        XCTAssertEqual(selection, ZoneSelection(indices: [0, 1, 2, 3], frame: area))
    }

    func testGridEdgeSpansTwoZonesVertically() {
        let zones = ZoneLayout.grid(columns: 2, rows: 2).zones(in: area, spacing: 0)
        let selection = ZoneLayout.selection(at: CGPoint(x: 300, y: 410), in: zones, spacing: 0)
        XCTAssertEqual(selection, ZoneSelection(indices: [0, 2], frame: CGRect(x: 0, y: 0, width: 600, height: 800)))
    }

    func testMergeWorksAcrossSpacing() {
        let zones = ZoneLayout.columns(2).zones(in: CGRect(x: 0, y: 0, width: 100, height: 100), spacing: 10)
        let selection = ZoneLayout.selection(at: CGPoint(x: 50, y: 50), in: zones, spacing: 10)
        XCTAssertEqual(selection, ZoneSelection(indices: [0, 1], frame: CGRect(x: 10, y: 10, width: 80, height: 80)))
    }
}

final class UsableFrameTests: XCTestCase {
    // MacBook below, LG to the left; menu bar 33pt on the MacBook, 30pt on the LG.
    let macbook = CGRect(x: 0, y: 0, width: 1512, height: 982)
    let macbookVisible = CGRect(x: 0, y: 0, width: 1512, height: 949)
    let lg = CGRect(x: -2560, y: -187, width: 2560, height: 1080)
    let lgVisible = CGRect(x: -2560, y: -187, width: 2560, height: 1050)

    func testDockScreenLosesTheDockEdge() {
        let dock = DockPlacement(screenFrame: lg, edge: .bottom, thickness: 57)
        XCTAssertEqual(ScreenGeometry.usableFrame(frame: lg, visible: lgVisible, dock: dock),
                       CGRect(x: -2560, y: -130, width: 2560, height: 993))
    }

    func testOtherScreenIgnoresStaleDockReservation() {
        // macOS kept reserving the Dock on the MacBook after it moved to the LG.
        let stale = CGRect(x: 0, y: 57, width: 1512, height: 892)
        let dock = DockPlacement(screenFrame: lg, edge: .bottom, thickness: 57)
        XCTAssertEqual(ScreenGeometry.usableFrame(frame: macbook, visible: stale, dock: dock), macbookVisible)
    }

    func testNoDockUsesEverythingBelowTheMenuBar() {
        XCTAssertEqual(ScreenGeometry.usableFrame(frame: macbook, visible: CGRect(x: 0, y: 4, width: 1512, height: 945), dock: nil),
                       macbookVisible)
    }

    func testSideDocks() {
        let left = DockPlacement(screenFrame: macbook, edge: .left, thickness: 57)
        let right = DockPlacement(screenFrame: macbook, edge: .right, thickness: 57)
        XCTAssertEqual(ScreenGeometry.usableFrame(frame: macbook, visible: macbookVisible, dock: left),
                       CGRect(x: 57, y: 0, width: 1455, height: 949))
        XCTAssertEqual(ScreenGeometry.usableFrame(frame: macbook, visible: macbookVisible, dock: right),
                       CGRect(x: 0, y: 0, width: 1455, height: 949))
    }

    func testDockThicknessIsMeasuredFromWhicheverScreenReservesIt() {
        let stale = CGRect(x: 0, y: 57, width: 1512, height: 892)
        XCTAssertEqual(ScreenGeometry.dockThickness(screens: [(macbook, stale), (lg, lgVisible)]), 57)
        XCTAssertNil(ScreenGeometry.dockThickness(screens: [(macbook, macbookVisible), (lg, lgVisible)]))
    }
}
