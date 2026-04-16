//
//  LessGoTests.swift
//  LessGoTests
//
//  Created by Shyam Kannan on 2/16/26.
//

import Testing
import CoreLocation
@testable import LessGo

struct LessGoTests {

    @Test func apiConfigBaseURLIsSetToAValidURLString() {
        #expect(!APIConfig.baseURL.isEmpty)
        #expect(APIConfig.baseURL.hasPrefix("http"))
        #expect(URL(string: APIConfig.baseURL) != nil)
    }

    @Test func appConstantsAreWithinExpectedProductBounds() {
        #expect(AppConstants.defaultSearchRadiusMeters == 8000)
        #expect(AppConstants.maxSeats == 8)
        #expect(AppConstants.minPasswordLength == 8)
        #expect(AppConstants.sjsuCoordinate.latitude > 37.0)
        #expect(AppConstants.sjsuCoordinate.longitude < -121.0)
    }

}
