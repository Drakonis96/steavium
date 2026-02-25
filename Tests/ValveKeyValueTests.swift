import XCTest
@testable import Steavium

final class ValveKeyValueTests: XCTestCase {
    func testParseAndReadNestedValue() throws {
        let input = """
        "UserLocalConfigStore"
        {
            "Software"
            {
                "Valve"
                {
                    "Steam"
                    {
                        "apps"
                        {
                            "570"
                            {
                                "LaunchOptions"      "-novid"
                            }
                        }
                    }
                }
            }
        }
        """

        let document = try ValveKeyValueDocument.parse(input)
        let launchOptions = document.string(
            at: ["UserLocalConfigStore", "Software", "Valve", "Steam", "apps", "570", "LaunchOptions"]
        )
        XCTAssertEqual(launchOptions, "-novid")
    }

    func testSetAndRemoveValue() throws {
        let input = """
        "Root"
        {
            "Node"
            {
                "Value"  "A"
            }
        }
        """

        var document = try ValveKeyValueDocument.parse(input)
        let path = ["Root", "Node", "Extra"]
        document.setString("Test Value", at: path)

        let serialized = document.serialized()
        let reparsed = try ValveKeyValueDocument.parse(serialized)
        XCTAssertEqual(reparsed.string(at: path), "Test Value")

        var removed = reparsed
        removed.removeValue(at: path)
        XCTAssertNil(removed.string(at: path))
    }

    func testEscapedCharactersRoundTrip() throws {
        var document = ValveKeyValueDocument(entries: [])
        let value = #"line1\nline2 \"quoted\""#
        document.setString(value, at: ["Root", "Escaped"])

        let serialized = document.serialized()
        let reparsed = try ValveKeyValueDocument.parse(serialized)
        XCTAssertEqual(reparsed.string(at: ["Root", "Escaped"]), value)
    }
}
