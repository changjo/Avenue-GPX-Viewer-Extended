//
//  ThumbnailProvider.swift
//  Avenue Thumbnails
//
//  Created by Vincent Neo on 13/1/23.
//  Copyright © 2023 Vincent. All rights reserved.
//

import QuickLookThumbnailing
import MapKit
import CoreGPX

class ThumbnailProvider: QLThumbnailProvider {

    func prepareRegion(from gpx: GPXRoot) -> MKCoordinateRegion {
        let extent = GPXExtentCoordinates()
        for route in gpx.routes {
            for point in route.points {
                guard let coordinate = GPXWaypointAdapter.coordinate(from: point) else { continue }
                extent.extendAreaToIncludeLocation(coordinate)
            }
        }
        
        for track in gpx.tracks {
            for segment in track.segments {
                for point in segment.points {
                    guard let coordinate = GPXWaypointAdapter.coordinate(from: point) else { continue }
                    extent.extendAreaToIncludeLocation(coordinate)
                }
            }
        }
        
        for waypoint in gpx.waypoints {
            guard let coordinate = GPXWaypointAdapter.coordinate(from: waypoint) else { continue }
            extent.extendAreaToIncludeLocation(coordinate)
        }
        
        var region = extent.region
        region.span.latitudeDelta *= 1.25
        region.span.longitudeDelta *= 1.25
        
        return region
    }
    
    override func provideThumbnail(for request: QLFileThumbnailRequest, _ handler: @escaping (QLThumbnailReply?, Error?) -> Void) {
        
        // There are three ways to provide a thumbnail through a QLThumbnailReply. Only one of them should be used.
        
        let ext = request.fileURL.pathExtension.lowercased()
        guard ext == "gpx" || ext == "rgp" else {
            handler(nil, nil)
            return
        }
        
        guard let gpx = self.parseRoot(from: request.fileURL) else {
            handler(nil, GPXError.parser.fileIsEmpty)
            return
        }
        
        let region = self.prepareRegion(from: gpx)
        
        let options = MKMapSnapshotter.Options()
        options.region = region
        options.size = request.maximumSize
        if #available(macOS 10.14, *) {
            options.appearance = NSAppearance(named: .aqua)
        }
        
        let snapshotter = MKMapSnapshotter(options: options)
        snapshotter.start { snapshot, error in
            let drawer = MKSnapshotDrawer(snapshot!, gpx: gpx)
            let newImage = drawer.processImage()

            handler(QLThumbnailReply(contextSize: request.maximumSize, currentContextDrawing: { () -> Bool in
                // Draw the thumbnail here.
                newImage.draw(in: NSRect(origin: .zero, size: request.maximumSize))
                // Return true if the thumbnail was successfully drawn inside this block.
                return true
            }), nil)
        }
        
        /*
        
        // Second way: Draw the thumbnail into a context passed to your block, set up with Core Graphics's coordinate system.
        handler(QLThumbnailReply(contextSize: request.maximumSize, drawing: { (context) -> Bool in
            // Draw the thumbnail here.
         
            // Return true if the thumbnail was successfully drawn inside this block.
            return true
        }), nil)
         
        // Third way: Set an image file URL.
        handler(QLThumbnailReply(imageFileURL: Bundle.main.url(forResource: "fileThumbnail", withExtension: "jpg")!), nil)
        
        */
    }

    private func parseRoot(from url: URL) -> GPXRoot? {
        if url.pathExtension.lowercased() == "rgp" {
            guard let data = try? Data(contentsOf: url) else { return nil }
            return Self.parseRGPData(data, fileName: url.lastPathComponent)
        }

        guard let parser = GPXParser(withURL: url) else { return nil }
        return parser.parsedData()
    }
}

private extension ThumbnailProvider {
    static func parseRGPData(_ data: Data, fileName: String) -> GPXRoot? {
        guard let text = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .ascii) else {
            return nil
        }

        let lines = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .split(separator: "\n", omittingEmptySubsequences: true)
            .map(String.init)

        guard lines.count >= 2 else { return nil }

        let headers = parseCSVRow(lines[0]).map { $0.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) }
        guard let latitudeIndex = headers.firstIndex(of: "latitude"),
              let longitudeIndex = headers.firstIndex(of: "longitude") else {
            return nil
        }
        let datetimeIndex = headers.firstIndex(of: "datetime")
        let altitudeIndex = headers.firstIndex(of: "height")
        let timestampConverter = RGPTimestampConverter()
        var trackPoints = [GPXTrackPoint]()
        trackPoints.reserveCapacity(lines.count - 1)

        for rawLine in lines.dropFirst() {
            let columns = parseCSVRow(rawLine)
            guard latitudeIndex < columns.count, longitudeIndex < columns.count else { continue }
            guard let latitude = Double(columns[latitudeIndex]), let longitude = Double(columns[longitudeIndex]) else { continue }
            guard (-90.0...90.0).contains(latitude), (-180.0...180.0).contains(longitude) else { continue }

            let trackPoint = GPXTrackPoint(latitude: latitude, longitude: longitude)

            if let altitudeIndex, altitudeIndex < columns.count,
               let altitude = Double(columns[altitudeIndex]) {
                trackPoint.elevation = altitude
            }

            if let datetimeIndex, datetimeIndex < columns.count,
               let date = timestampConverter.parse(columns[datetimeIndex]) {
                trackPoint.time = date
            }

            trackPoints.append(trackPoint)
        }

        guard !trackPoints.isEmpty else { return nil }

        let root = GPXRoot(creator: "Avenue-RGP-Importer")
        let track = GPXTrack()
        track.name = fileName

        let segment = GPXTrackSegment()
        segment.add(trackpoints: trackPoints)

        track.add(trackSegment: segment)
        root.add(track: track)
        return root
    }

    static func parseCSVRow(_ line: String) -> [String] {
        if !line.contains("\"") {
            return line
                .split(separator: ",", omittingEmptySubsequences: false)
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        }

        var result = [String]()
        var current = ""
        var inQuotes = false
        var index = line.startIndex

        while index < line.endIndex {
            let char = line[index]

            if char == "\"" {
                let nextIndex = line.index(after: index)
                if inQuotes, nextIndex < line.endIndex, line[nextIndex] == "\"" {
                    current.append("\"")
                    index = nextIndex
                } else {
                    inQuotes.toggle()
                }
            } else if char == "," && !inQuotes {
                result.append(current.trimmingCharacters(in: .whitespacesAndNewlines))
                current = ""
            } else {
                current.append(char)
            }

            index = line.index(after: index)
        }

        result.append(current.trimmingCharacters(in: .whitespacesAndNewlines))
        return result
    }

    final class RGPTimestampConverter {
        private let parserWithFractionalSeconds = DateFormatter()
        private let parserWithoutFractionalSeconds = DateFormatter()

        init() {
            parserWithFractionalSeconds.locale = Locale(identifier: "en_US_POSIX")
            parserWithFractionalSeconds.timeZone = TimeZone(secondsFromGMT: 0)
            parserWithFractionalSeconds.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"

            parserWithoutFractionalSeconds.locale = Locale(identifier: "en_US_POSIX")
            parserWithoutFractionalSeconds.timeZone = TimeZone(secondsFromGMT: 0)
            parserWithoutFractionalSeconds.dateFormat = "yyyy-MM-dd HH:mm:ss"
        }

        func parse(_ value: String) -> Date? {
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return nil }

            if let date = parserWithFractionalSeconds.date(from: trimmed) {
                return date
            }
            if let date = parserWithoutFractionalSeconds.date(from: trimmed) {
                return date
            }
            return nil
        }
    }
}
