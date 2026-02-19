//
//  MapView.swift
//  Avenue
//
//  Created by Vincent on 8/7/19.
//  Copyright © 2019 Vincent. All rights reserved.
//

import Cocoa
import MapKit
import CoreGPX

class MapView: MKMapView {
    
    var document: Document? {
        return self.window?.windowController?.document as? Document
    }
    
    private var trackLength = 0.0
    private var trackDuration = 0.0

    private struct PreparedMapContent {
        let overlays: [MKPolyline]
        let annotations: [GPXWaypointAnnotation]
        let extent: GPXExtentCoordinates
        let trackLength: Double
        let trackDuration: Double
    }
    
    func loadedGPXData(_ data: Data, fileURL: URL?, _ windowCon: WindowController) {
        let indicator = NSProgressIndicator(frame: self.frame)
        let visualView = NSVisualEffectView(frame: self.frame)
        visualView.blendingMode = .withinWindow
        visualView.material = .popover

        indicator.style = .spinning
        indicator.startAnimation(self)
        
        DispatchQueue.global(qos: .userInitiated).async {
            
            // UI start parse indication
            DispatchQueue.main.sync {
                self.setUserInteraction(state: false)
                windowCon.contentViewController?.view.addSubview(visualView)
                windowCon.contentViewController?.view.addSubview(indicator)
                indicator.translatesAutoresizingMaskIntoConstraints = false
                visualView.translatesAutoresizingMaskIntoConstraints = false
                NSLayoutConstraint(item: indicator, attribute: .centerX, relatedBy: .equal, toItem: self, attribute: .centerX, multiplier: 1, constant: 0).isActive = true
                NSLayoutConstraint(item: indicator, attribute: .centerY, relatedBy: .equal, toItem: self, attribute: .centerY, multiplier: 1, constant: 0).isActive = true
                NSLayoutConstraint(item: visualView, attribute: .width, relatedBy: .equal, toItem: self, attribute: .width, multiplier: 1, constant: 0).isActive = true
                NSLayoutConstraint(item: visualView, attribute: .height, relatedBy: .equal, toItem: self, attribute: .height, multiplier: 1, constant: 0).isActive = true
            }

            // Parsing. Async as it may take a long time, dependent on file.
            let fileGPX: GPXRoot?
            if fileURL?.pathExtension.lowercased() == "rgp" {
                fileGPX = Self.parseRGPData(data, fileName: fileURL?.lastPathComponent ?? "RGP Track")
            } else {
                fileGPX = GPXParser(withData: data).parsedData()
            }

            let preparedContent = fileGPX.map { Self.prepareMapContent(from: $0) }
            
            // UI end parse release
            DispatchQueue.main.sync {
                
                self.setUserInteraction(state: true)
                indicator.removeFromSuperview()
                visualView.removeFromSuperview()
                indicator.stopAnimation(self)
                guard let fileGPX = fileGPX,
                      let preparedContent = preparedContent,
                      let document = self.document else { return }

                self.applyPreparedMapContent(preparedContent, root: fileGPX, document: document)
                NotificationCenter.default.post(Notification(name: Notification.Name("GPXFileFinishedLoading")))
            }

        }
    }
    
    func updateBarInfo() {
        let timeText = self.trackDuration > 0 ? "\(ElapsedTime.getString(from: self.trackDuration))｜": ""
        if let windowController = window?.windowController as? WindowController {
            windowController.barDistance.stringValue = "\(timeText)\(self.trackLength.toDistance(type: Preferences.shared.distanceUnitType))"
        }
    }
    
    func loadedGPXFile() {
        guard let document = document, let root = document.gpx else { fatalError("this shouldn't happen...") }
        let preparedContent = Self.prepareMapContent(from: root)
        self.applyPreparedMapContent(preparedContent, root: root, document: document)
    }

    private func applyPreparedMapContent(_ preparedContent: PreparedMapContent, root: GPXRoot, document: Document) {
        self.trackLength = preparedContent.trackLength
        self.trackDuration = preparedContent.trackDuration
        self.updateBarInfo()

        document.gpx = root
        document.extent = preparedContent.extent

        let polylineOverlays = self.overlays.filter { $0 is MKPolyline }
        if !polylineOverlays.isEmpty {
            self.removeOverlays(polylineOverlays)
        }
        let waypointAnnotations = self.annotations.filter { $0 is GPXWaypointAnnotation }
        if !waypointAnnotations.isEmpty {
            self.removeAnnotations(waypointAnnotations)
        }

        if !preparedContent.overlays.isEmpty {
            self.addOverlays(preparedContent.overlays, level: .aboveLabels)
        }
        if !preparedContent.annotations.isEmpty {
            self.addAnnotations(preparedContent.annotations)
        }

        self.setRegion(preparedContent.extent.region, animated: true)
    }
    
    /// Sets all user interactable UI enabledness based on state parameter.
    func setUserInteraction(state: Bool) {
        self.isZoomEnabled = state
        self.isPitchEnabled = state
        self.isRotateEnabled = state
        self.isScrollEnabled = state
    }
    
}

private extension MapView {
    private static func prepareMapContent(from root: GPXRoot) -> PreparedMapContent {
        var overlays = [MKPolyline]()
        let estimatedOverlayCount = root.routes.count + root.tracks.reduce(0) { $0 + $1.segments.count }
        overlays.reserveCapacity(estimatedOverlayCount)

        var annotations = [GPXWaypointAnnotation]()
        annotations.reserveCapacity(root.waypoints.count)

        let extent = GPXExtentCoordinates()
        var length = 0.0
        var duration = 0.0

        for waypoint in root.waypoints {
            guard let coordinate = GPXWaypointAdapter.coordinate(from: waypoint) else { continue }
            extent.extendAreaToIncludeLocation(coordinate)
            if let annotation = GPXWaypointAnnotation(waypoint: waypoint) {
                annotations.append(annotation)
            }
        }

        for route in root.routes {
            let coordinates = coordinatesAndUpdateMetrics(from: route.points, extent: extent, totalLength: &length)
            if coordinates.count > 1 {
                var mutableCoordinates = coordinates
                overlays.append(MKPolyline(coordinates: &mutableCoordinates, count: mutableCoordinates.count))
            }
            if let startTime = route.points.first?.time,
               let endTime = route.points.last?.time {
                duration += endTime.timeIntervalSince(startTime)
            }
        }

        for track in root.tracks {
            for segment in track.segments {
                let coordinates = coordinatesAndUpdateMetrics(from: segment.points, extent: extent, totalLength: &length)
                if coordinates.count > 1 {
                    var mutableCoordinates = coordinates
                    overlays.append(MKPolyline(coordinates: &mutableCoordinates, count: mutableCoordinates.count))
                }
                if let startTime = segment.points.first?.time,
                   let endTime = segment.points.last?.time {
                    duration += endTime.timeIntervalSince(startTime)
                }
            }
        }

        extent.region.span.latitudeDelta *= 1.25
        extent.region.span.longitudeDelta *= 1.25

        return PreparedMapContent(
            overlays: overlays,
            annotations: annotations,
            extent: extent,
            trackLength: length,
            trackDuration: duration
        )
    }

    static func coordinatesAndUpdateMetrics(
        from points: [GPXTrackPoint],
        extent: GPXExtentCoordinates,
        totalLength: inout Double
    ) -> [CLLocationCoordinate2D] {
        var coordinates = [CLLocationCoordinate2D]()
        coordinates.reserveCapacity(points.count)

        var previousMapPoint: MKMapPoint?
        for point in points {
            guard let coordinate = GPXWaypointAdapter.coordinate(from: point) else { continue }
            coordinates.append(coordinate)
            extent.extendAreaToIncludeLocation(coordinate)

            let mapPoint = MKMapPoint(coordinate)
            if let previousMapPoint = previousMapPoint {
                totalLength += previousMapPoint.distance(to: mapPoint)
            }
            previousMapPoint = mapPoint
        }

        return coordinates
    }

    static func coordinatesAndUpdateMetrics(
        from points: [GPXRoutePoint],
        extent: GPXExtentCoordinates,
        totalLength: inout Double
    ) -> [CLLocationCoordinate2D] {
        var coordinates = [CLLocationCoordinate2D]()
        coordinates.reserveCapacity(points.count)

        var previousMapPoint: MKMapPoint?
        for point in points {
            guard let coordinate = GPXWaypointAdapter.coordinate(from: point) else { continue }
            coordinates.append(coordinate)
            extent.extendAreaToIncludeLocation(coordinate)

            let mapPoint = MKMapPoint(coordinate)
            if let previousMapPoint = previousMapPoint {
                totalLength += previousMapPoint.distance(to: mapPoint)
            }
            previousMapPoint = mapPoint
        }

        return coordinates
    }

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
