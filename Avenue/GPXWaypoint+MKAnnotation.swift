//
//  GPXWaypoint+MKAnnotation.swift
//  Avenue
//
//  Safe waypoint adapters used by map and quick look targets.
//

import MapKit
import CoreGPX

enum GPXWaypointAdapter {
    static func coordinate(from waypoint: GPXWaypoint) -> CLLocationCoordinate2D? {
        guard let latitude = waypoint.latitude, let longitude = waypoint.longitude else {
            return nil
        }
        return CLLocationCoordinate2D(latitude: latitude, longitude: CLLocationDegrees(longitude))
    }

    static func coordinate(from point: GPXTrackPoint) -> CLLocationCoordinate2D? {
        guard let latitude = point.latitude, let longitude = point.longitude else {
            return nil
        }
        return CLLocationCoordinate2D(latitude: latitude, longitude: CLLocationDegrees(longitude))
    }

    static func coordinate(from point: GPXRoutePoint) -> CLLocationCoordinate2D? {
        guard let latitude = point.latitude, let longitude = point.longitude else {
            return nil
        }
        return CLLocationCoordinate2D(latitude: latitude, longitude: CLLocationDegrees(longitude))
    }
}

final class GPXWaypointAnnotation: NSObject, MKAnnotation {
    let waypoint: GPXWaypoint
    let coordinate: CLLocationCoordinate2D

    var title: String? {
        waypoint.name
    }

    var subtitle: String? {
        waypoint.desc
    }

    init?(waypoint: GPXWaypoint) {
        guard let coordinate = GPXWaypointAdapter.coordinate(from: waypoint) else {
            return nil
        }
        self.waypoint = waypoint
        self.coordinate = coordinate
    }
}
