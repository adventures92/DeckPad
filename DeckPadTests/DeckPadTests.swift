//
//  DeckPadTests.swift
//  DeckPadTests
//

import Foundation
import Testing
@testable import DeckPad

struct CoreTypesTests {
    @Test func controlIDEncodesAsBareString() throws {
        let id = ControlID("deck1.play")
        let data = try JSONEncoder().encode(id)
        #expect(String(data: data, encoding: .utf8) == "\"deck1.play\"")
        #expect(try JSONDecoder().decode(ControlID.self, from: data) == id)
    }

    @Test func triggerRoundTripsThroughJSON() throws {
        let triggers: [Trigger] = [.press, .release, .doubleTap, .hold(ms: 500), .toggle, .continuous, .relative]
        for trigger in triggers {
            let data = try JSONEncoder().encode(trigger)
            #expect(try JSONDecoder().decode(Trigger.self, from: data) == trigger)
        }
    }
}
