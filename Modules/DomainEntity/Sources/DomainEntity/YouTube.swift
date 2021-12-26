//
//  YouTube.swift
//  App
//
//  Created by Masato TSUTSUMI on 2021/04/26.
//

import Foundation

public protocol YouTubePaginationQuery {
    var maxResults: Int { get set }
    var pageToken: String? { get set }
}

public struct YouTubePage<Item>: Codable where Item: Codable {
    public let kind: String
    public let etag: String
    public let nextPageToken: String?
    public let prevPageToken: String?
    public let regionCode: String?
    public let pageInfo: PageInfo
    public let items: [Item]

    public init(
        kind: String, etag: String, nextPageToken: String?, prevPageToken: String?,
        regionCode: String?, pageInfo: PageInfo, items: [Item]
    ) {
        self.kind = kind
        self.etag = etag
        self.nextPageToken = nextPageToken
        self.prevPageToken = prevPageToken
        self.regionCode = regionCode
        self.pageInfo = pageInfo
        self.items = items
    }
}

public struct PageInfo: Codable {
    public var totalResults: Int
    public var resultsPerPage: Int
}

public struct YouTubeVideo: Codable, Equatable {
    public var kind: String
    public var etag: String
    public var id: ItemId
    public var snippet: ItemSnippet?

    public struct ItemId: Codable, Equatable {
        public var kind: String
        public var videoId: String?
    }

    public struct ItemSnippet: Codable, Equatable {
        public var publishedAt: Date?
        public var channelId: String?
        public var title: String?
        public var description: String?
        public var thumbnails: Tumbnails?
        public var channelTitle: String?
        public var liveBroadcastContent: String?
        public var publishTime: Date?

        public struct Tumbnails: Codable, Equatable {
            public var `default`: ThumbnailItem?
            public var medium: ThumbnailItem?
            public var high: ThumbnailItem?

            public struct ThumbnailItem: Codable, Equatable {
                public var url: String?
                public var width: Int?
                public var height: Int?
            }
        }
    }
}
