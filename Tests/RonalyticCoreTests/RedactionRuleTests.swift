//
// Copyright (c) 2026 Enjel Hutasoit
//

import XCTest
@testable import RonalyticCore

final class RedactionRuleTests: XCTestCase {
    func test_maskEmails_replacesEmailInsideText() {
        let value: PropertyValue = "mail me at ron@example.com please"

        let result = RedactionRule.maskEmails.apply("note", value)

        XCTAssertEqual(
            result,
            .string("mail me at [redacted-email] please")
        )
    }

    func test_maskEmails_replacesEveryEmail() {
        let value: PropertyValue = "a@b.com and c@d.org"

        let result = RedactionRule.maskEmails.apply("note", value)

        XCTAssertEqual(
            result,
            .string("[redacted-email] and [redacted-email]")
        )
    }

    func test_maskEmails_ignoresNonStringValues() {
        let result = RedactionRule.maskEmails.apply("qty", .int(3))

        XCTAssertEqual(result, .int(3))
    }

    func test_maskPhoneNumbers_replacesInternationalNumber() {
        let value: PropertyValue = "call +62 812-3456-7890 now"

        let result = RedactionRule.maskPhoneNumbers.apply("note", value)

        XCTAssertEqual(
            result,
            .string("call [redacted-phone] now")
        )
    }

    func test_maskPhoneNumbers_keepsShortNumbers() {
        let value: PropertyValue = "order 12345"

        let result = RedactionRule.maskPhoneNumbers.apply("note", value)

        XCTAssertEqual(result, value)
    }

    func test_removeKeys_isCaseInsensitive() {
        let rule = RedactionRule.removeKeys(["password", "Token"])

        let password = rule.apply("PASSWORD", .string("secret"))
        let token = rule.apply("token", .string("abc"))
        let other = rule.apply("plan", .string("pro"))

        XCTAssertNil(password)
        XCTAssertNil(token)
        XCTAssertEqual(other, .string("pro"))
    }

    func test_custom_ruleDecidesTheValue() {
        let rule = RedactionRule { key, value in
            key == "card" ? .string("****") : value
        }

        let masked = rule.apply("card", .string("4111111111111111"))
        let kept = rule.apply("plan", .string("pro"))

        XCTAssertEqual(masked, .string("****"))
        XCTAssertEqual(kept, .string("pro"))
    }
}
