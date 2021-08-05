//
//  ExternalAPI.swift
//  App
//
//  Created by Masato TSUTSUMI on 2021/04/25.
//

import Foundation

public struct CreateGroupAsMaster: EndpointProtocol {
    public typealias Request = CreateGroup.Request
    public typealias Response = Group
    public struct URI: CodableURL {
        @StaticPath("external", "create_group") public var prefix: Void
        public init() {}
    }
    public static let method: HTTPMethod = .post
}

public struct BatchGroupUpdates: EndpointProtocol {
    public typealias Request = Empty
    public typealias Response = Empty
    public struct URI: CodableURL {
        @StaticPath("external", "group_updates") public var prefix: Void
        public init() {}
    }
    public static var method: HTTPMethod = .get
}

public struct ScanGroups: EndpointProtocol {
    public typealias Request = Empty
    public typealias Response = [Group]
    public struct URI: CodableURL {
        @StaticPath("external", "groups") public var prefix: Void
        public init() {}
    }
    public static var method: HTTPMethod = .get
}

public struct CreateGroupFromBatch: EndpointProtocol {
    public typealias Request = CreateGroup.Request
    public typealias Response = CreateGroup.Response
    public struct URI: CodableURL {
        @StaticPath("external", "create_group") public var prefix: Void
        public init() {}
    }
    public static var method: HTTPMethod = .post
}

public struct FetchLive: EndpointProtocol {
    public typealias Request = CreateLive.Request
    public typealias Response = CreateLive.Response
    public struct URI: CodableURL {
        @StaticPath("external", "fetch_live") public var prefix: Void
        public init() {}
    }
    public static var method: HTTPMethod = .post
}

public struct CheckGlobalIP: EndpointProtocol {
    public typealias Request = Empty
    public typealias Response = String
    public struct URI: CodableURL {
        @StaticPath("external", "global_ip") public var prefix: Void
        public init() {}
    }
    public static var method: HTTPMethod = .get
}

public struct TestGetPiaArtist: EndpointProtocol {
    public typealias Request = Empty
    public typealias Response = PiaSearchArtists.Response
    public struct URI: CodableURL {
        @StaticPath("external", "test_pia_artist") public var prefix: Void
        @Query public var piaApiKey: String
        @Query public var keyword: String?
        public init() {}
    }
    public static var method: HTTPMethod = .get
}

public struct TestGetPiaEventRelease: EndpointProtocol {
    public typealias Request = Empty
    public typealias Response = PiaSearchEventReleasesBriefly.Response
    public struct URI: CodableURL {
        @StaticPath("external", "test_pia_event_release") public var prefix: Void
        @Query public var piaApiKey: String
        @Query public var keyword: String?
        public init() {}
    }
    public static var method: HTTPMethod = .get
}

public struct ListChannel: EndpointProtocol {
    public typealias Request = Empty
    public typealias Response = YouTubePage<YouTubeVideo>
    public struct URI: CodableURL, YouTubePaginationQuery {
        @StaticPath("youtube", "v3", "search") public var prefix: Void
        @Query public var channelId: String?
        @Query public var q: String?
        @Query public var part: String
        @Query public var publishedBefore: String?
        @Query public var maxResults: Int
        @Query public var order: String?
        @Query public var type: String?
        @Query public var pageToken: String?
        @Query public var key: String?
        public init() {}
    }
    public static let method: HTTPMethod = .get
}

public struct PiaSearchArtists: EndpointProtocol {
    public typealias Request = Empty
    public struct Response: Codable, Equatable {
        public var searchHeader: PiaApiGetResponseHeader
        public var artists: PiaArtist?

        public init(searchHeader: PiaApiGetResponseHeader, artists: PiaArtist?) {
            self.searchHeader = searchHeader
            self.artists = artists
        }
    }
    public struct URI: CodableURL {
        @StaticPath("1.1", "artists") public var prefix: Void
        @Query public var apikey: String
        @Query public var keyword: String?
        @Query public var artist_code: String?
        @Query public var style_lclass_code: String?
        @Query public var style_sclass_code: String?
        @Query public var start_count: Int?
        @Query public var get_count: Int?
        public init() {}
    }
    public static let method: HTTPMethod = .get
}

public struct PiaSearchVenues: EndpointProtocol {
    public typealias Request = Empty
    public struct Response: Codable, Equatable {
        public var searchHeader: PiaApiGetResponseHeader
        public var venue: PiaVenue?
        
        public init(searchHeader: PiaApiGetResponseHeader, venue: PiaVenue?) {
            self.searchHeader = searchHeader
            self.venue = venue
        }
    }
    public struct URI: CodableURL {
        @StaticPath("1.1", "venues") public var prefix: Void
        @Query public var apikey: String
        @Query public var keyword: String?
        @Query public var latitude: Double?
        @Query public var longitude: Double?
        @Query public var range: Double?
        @Query public var datum: Int?
        @Query public var region_code: String?
        @Query public var prefecture_code: String?
        @Query public var venue_code: String?
        @Query public var start_count: Int?
        @Query public var get_count: Int?
        public init() {}
    }
    public static let method: HTTPMethod = .get
}

public struct PiaSearchEventReleasesBriefly: EndpointProtocol {
    public typealias Request = Empty
    public struct Response: Codable, Equatable {
        public var searchHeader: PiaApiGetResponseHeader
        public var eventReleases: PiaEventRelease?
        
        public init(searchHeader: PiaApiGetResponseHeader, eventReleases: PiaEventRelease?) {
            self.searchHeader = searchHeader
            self.eventReleases = eventReleases
        }
    }
    public struct URI: CodableURL {
        @StaticPath("1.1", "event_releases") public var prefix: Void
        @Query public var apikey: String
        @Query public var keyword: String?
        @Query public var lgenre_code: String?
        @Query public var sgenre_code: String?
        @Query public var artist_code: String?
        @Query public var event_code: String?
        @Query public var region_code: String?
        @Query public var prefecture_code: String?
        @Query public var venue_code: String?
        @Query public var perform_date_from: String?
        @Query public var perform_date_end: String?
        @Query public var sale_date_from: String?
        @Query public var sale_date_end: String?
        @Query public var pia_code: String?
        @Query public var release_type: String?
        @Query public var release_kind: String?
        @Query public var release_status: String?
        @Query public var sort: String?
        @Query public var start_count: Int?
        @Query public var get_count: Int?
        public init() {}
    }
    public static let method: HTTPMethod = .get
}

public struct PiaApiGetResponseHeader: Codable, Equatable {
    public var getCount: Int
    public var startCount: Int
    public var resultCount: Int
    
    public init(getCount: Int, startCount: Int, resultCount: Int) {
        self.getCount = getCount
        self.startCount = startCount
        self.resultCount = resultCount
    }
}

public struct PiaArtist: Codable, Equatable {
    public var artist: [PiaArtistItem]
    
    public init(artist: [PiaArtistItem]) {
        self.artist = artist
    }
}

public struct PiaImageUrlXl: Codable, Equatable {
    public var imageUrlXl: [PiaImageUrlType]
}

public struct PiaImageUrlS: Codable, Equatable {
    public var imageUrlS: [PiaImageUrlType]
}

public struct PiaArtistItem: Codable, Equatable {
    public var artistCode: String
    public var artistName: String
    public var artistKana: String?
    public var title: String?
    public var aritstUrlPc: String?
    public var artistUrlMobile: String?
    public var imageUrlXls: PiaImageUrlXl?
    public var imageUrlSs: PiaImageUrlS?
//    public var relatedArtist: [PiaRelatedArtist]
    
    public init(
        artistCode: String,
        artistName: String,
        artistKana: String?,
        title: String?,
        artistUrlPc: String?,
        artistUrlMobile: String?,
        imageUrlXls: PiaImageUrlXl?,
        imageUrlSs: PiaImageUrlS?
//        relatedArtist: [PiaRelatedArtist]
    ) {
        self.artistCode = artistCode
        self.artistName = artistName
        self.artistKana = artistKana
        self.title = title
        self.aritstUrlPc = artistUrlPc
        self.artistUrlMobile = artistUrlMobile
        self.imageUrlXls = imageUrlXls
        self.imageUrlSs = imageUrlSs
//        self.relatedArtist = relatedArtist
    }
}

public struct PiaRelatedArtist: Codable, Equatable {
    public var artistCode: String
    public var artistName: String
    public var title: String?
    public var aritstUrlPc: String?
    public var artistUrlMobile: String?
    public var imageUrlXl: [PiaImageUrlType]
    public var imageUrlS: [PiaImageUrlType]
    
    public init(
        artistCode: String,
        artistName: String,
        title: String?,
        artistUrlPc: String?,
        artistUrlMobile: String?,
        imageUrlXl: [PiaImageUrlType],
        imageUrlS: [PiaImageUrlType]
    ) {
        self.artistCode = artistCode
        self.artistName = artistName
        self.title = title
        self.aritstUrlPc = artistUrlPc
        self.artistUrlMobile = artistUrlMobile
        self.imageUrlXl = imageUrlXl
        self.imageUrlS = imageUrlS
    }
}

public struct PiaEventRelease: Codable, Equatable {
    public var eventRelease: [PiaEventReleaseItem]
    
    public init(eventRelease: [PiaEventReleaseItem]) {
        self.eventRelease = eventRelease
    }
}

public struct PiaEventReleaseItem: Codable, Equatable {
    public var event: PiaEventItem
    public var release: PiaReleaseItem
    public var performs: PiaPerform
}

public struct PiaEvent: Codable, Equatable {
    public var event: [PiaEventItem]
}

public struct PiaRelease: Codable, Equatable {
    public var release: [PiaReleaseItem]
}

public struct PiaPerform: Codable, Equatable {
    public var perform: [PiaPerformItem]
}

public struct PiaEventItem: Codable, Equatable {
    public var eventCode: String
    public var bundle: String
    public var bundleCode: String?
    public var mainTitle: String
    public var mainTitleKana: String
    public var imageUrlXls: PiaImageUrlXl?
    public var imageUrlSs: PiaImageUrlS?
    public var lGenreName: String
    public var lGenreCode: String
    public var sGenreName: String
    public var sGenreCode: String
    public var eventUrlPc: String
    public var eventUrlMobile: String
    public var eventRank: String
}

public struct PiaReleaseItem: Codable, Equatable {
    public var releaseCode: String?
    public var lotReleaseCode: String?
    public var releaseName: String
    public var firstArrivalLotType: String
    public var releaseStatusCode: String
    public var releaseStatusName: String
    public var releaseKindCode: String
    public var releaseKindName: String
    public var releaseKindShortCode: String
    public var releaseKindShortName: String
    public var premiumFlag: String
    public var releaseDateFrom: String
    public var releaseDateEnd: String
    public var releaseUrlPc: String
    public var releaseUrlMobile: String
    public var saleStopFlag: String
    public var saleStopReason: String?
}

public struct PiaPerformItem: Codable, Equatable {
    public var performCode: String
    public var performTitle: String?
    public var performDate: String?
    public var openTime: String?
    public var performStartTime: String?
    public var performTermFrom: String?
    public var performTermEnd: String?
    public var termValidFlag: String
    public var performItemName: String?
    public var songTitle: String?
    public var appearInfo: String?
    public var saleStopFlag: String
    public var saleStopReason: String?
    public var appearMainArtists: PiaAppearMainArtist
    public var appearArtist: PiaAppearArtist?
    public var venue: PiaVenueItem?
}

public struct PiaAppearMainArtist: Codable, Equatable {
    public var appearMainArtist: [PiaArtistItem]
}

public struct PiaAppearArtist: Codable, Equatable {
    public var appearArtist: [PiaArtistItem]
}

public struct PiaVenue: Codable, Equatable {
    public var venue: [PiaVenueItem]
    
    public init(venue: [PiaVenueItem]) {
        self.venue = venue
    }
}

public struct PiaVenueItem: Codable, Equatable {
    public var venueCode: String
    public var venueName: String
    public var prefectureCode: String
    public var prefectureName: String
    public var postNo: String?
    public var address: String?
    public var japanLatitude: Float?
    public var japanLongitude: Float?
    public var worldLatitude: Float?
    public var worldLongitude: Float?
    
    public init(
        venueCode: String,
        venueName: String,
        prefectureCode: String,
        prefectureName: String,
        postNo: String?,
        address: String?,
        japanLatitude: Float?,
        japanLongitude: Float?,
        worldLatitude: Float?,
        worldLongitude: Float?
    ) {
        self.venueCode = venueCode
        self.venueName = venueName
        self.prefectureCode = prefectureCode
        self.prefectureName = prefectureName
        self.postNo = postNo
        self.address = address
        self.japanLatitude = japanLatitude
        self.japanLongitude = japanLongitude
        self.worldLatitude = worldLatitude
        self.worldLongitude = worldLongitude
    }
}

public struct PiaImageUrlType: Codable, Equatable {
    public var imageUrl: String?
    public var imageComment: String?
    
    public init(imageUrl: String?, imageComment: String?) {
        self.imageUrl = imageUrl
        self.imageComment = imageComment
    }
}
