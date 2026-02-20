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
        snapshotter.start { snapshot, _ in
            let newImage: NSImage
            if let snapshot {
                let drawer = MKSnapshotDrawer(snapshot, gpx: gpx)
                newImage = drawer.processImage()
            } else {
                newImage = self.makeFallbackImage(size: request.maximumSize, gpx: gpx)
            }

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

    private func makeFallbackImage(size: CGSize, gpx: GPXRoot) -> NSImage {
        let image = NSImage(size: size)
        image.lockFocus()
        defer { image.unlockFocus() }

        NSColor.windowBackgroundColor.setFill()
        NSBezierPath(rect: NSRect(origin: .zero, size: size)).fill()

        let lines = allLineCoordinates(from: gpx)
        let waypoints = gpx.waypoints.compactMap { GPXWaypointAdapter.coordinate(from: $0) }
        let allCoordinates = lines.flatMap { $0 } + waypoints

        guard let bounds = coordinateBounds(for: allCoordinates) else {
            return image
        }

        let inset = max(6.0, min(size.width, size.height) * 0.08)
        let drawableWidth = max(1.0, size.width - (inset * 2))
        let drawableHeight = max(1.0, size.height - (inset * 2))
        let spanLon = max(0.000001, bounds.maxLon - bounds.minLon)
        let spanLat = max(0.000001, bounds.maxLat - bounds.minLat)
        let scale = min(drawableWidth / spanLon, drawableHeight / spanLat)
        let xOffset = (size.width - (spanLon * scale)) / 2.0
        let yOffset = (size.height - (spanLat * scale)) / 2.0

        func project(_ coordinate: CLLocationCoordinate2D) -> NSPoint {
            let x = xOffset + ((coordinate.longitude - bounds.minLon) * scale)
            let y = yOffset + ((coordinate.latitude - bounds.minLat) * scale)
            return NSPoint(x: x, y: y)
        }

        NSColor.systemRed.withAlphaComponent(0.75).setStroke()
        for line in lines {
            guard let first = line.first else { continue }
            let path = NSBezierPath()
            path.lineJoinStyle = .round
            path.lineCapStyle = .round
            path.lineWidth = max(2.0, min(size.width, size.height) * 0.02)
            path.move(to: project(first))
            for coordinate in line.dropFirst() {
                path.line(to: project(coordinate))
            }
            path.stroke()
        }

        NSColor.systemBlue.withAlphaComponent(0.8).setFill()
        for waypoint in waypoints {
            let point = project(waypoint)
            let diameter = max(3.0, min(size.width, size.height) * 0.03)
            let rect = NSRect(x: point.x - (diameter / 2.0), y: point.y - (diameter / 2.0), width: diameter, height: diameter)
            NSBezierPath(ovalIn: rect).fill()
        }

        return image
    }

    private func allLineCoordinates(from gpx: GPXRoot) -> [[CLLocationCoordinate2D]] {
        var lines = [[CLLocationCoordinate2D]]()

        for route in gpx.routes {
            let coordinates = route.points.compactMap { GPXWaypointAdapter.coordinate(from: $0) }
            if !coordinates.isEmpty {
                lines.append(coordinates)
            }
        }

        for track in gpx.tracks {
            for segment in track.segments {
                let coordinates = segment.points.compactMap { GPXWaypointAdapter.coordinate(from: $0) }
                if !coordinates.isEmpty {
                    lines.append(coordinates)
                }
            }
        }

        return lines
    }

    private func coordinateBounds(for coordinates: [CLLocationCoordinate2D]) -> (minLat: Double, maxLat: Double, minLon: Double, maxLon: Double)? {
        guard let first = coordinates.first else { return nil }

        var minLat = first.latitude
        var maxLat = first.latitude
        var minLon = first.longitude
        var maxLon = first.longitude

        for coordinate in coordinates.dropFirst() {
            minLat = min(minLat, coordinate.latitude)
            maxLat = max(maxLat, coordinate.latitude)
            minLon = min(minLon, coordinate.longitude)
            maxLon = max(maxLon, coordinate.longitude)
        }

        return (minLat, maxLat, minLon, maxLon)
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
