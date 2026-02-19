<p align="center">
  <img width=65% height=65% src="https://github.com/changjo/Avenue-GPX-Viewer-Extended/blob/master/Resources/AvenueNewBadge.png"/>
  <br/>
  <b> A simple GPS exchange format viewer for macOS. </b>
  <br/>
  <a href="https://github.com/changjo/Avenue-GPX-Viewer-Extended/actions">
    <img src="https://github.com/changjo/Avenue-GPX-Viewer-Extended/actions/workflows/swift.yml/badge.svg"/>
  </a>
  <a href="https://github.com/vincentneo/CoreGPX">
    <img src="https://img.shields.io/badge/CoreGPX-v0.9.0-yellow.svg"/>
  </a>
  <a href="https://swift.org">
    <img src="https://img.shields.io/badge/Swift-5.2-orange.svg"/>
  </a>
  <a href="https://github.com/changjo/Avenue-GPX-Viewer-Extended/blob/master/LICENSE">
    <img src="https://img.shields.io/badge/license-GPLv3-red.svg"/>
  </a>
  <a href="https://support.apple.com/en-us/HT208202">
    <img src="https://img.shields.io/badge/platform-macOS >= 11.0-purple.svg"/>
  </a>
  <a href="https://github.com/changjo/Avenue-GPX-Viewer-Extended/releases/latest">
    <img src="https://img.shields.io/github/v/release/changjo/Avenue-GPX-Viewer-Extended?include_prereleases"/>
  </a>
  
</p>

Avenue is a GPX file viewer that aims to allow quick and easy access to the data in a GPX file. 

Avenue Extended supports macOS 11.0 Big Sur and above.
<p align="center">
  <img width=65% height=65% src="https://github.com/changjo/Avenue-GPX-Viewer-Extended/blob/master/Resources/Screenshot.png"/>
</p>

Avenue is based on some codes over at [iOS-Open-GPX-Tracker](https://github.com/merlos/iOS-Open-GPX-Tracker).
This application was developed by the contributor of the project (me), initally as a personal use app,
eventually it is developed to being more complete, and that it can be expected to be improved on as time goes by.

## Features
- Shows GPX file contents on Apple Maps (Waypoint and Track point support)
- Display of total distance of the tracks 
- Dark mode support
- Minimap for easier locating in complicated tracks (can be disabled)
- Auto restore of previous settings when reopened (like chosen map source, etc)
- Support for third-party map sources
  - Open Street Map
  - Carto DB (with Retina Support)
  - OpenTopoMap
  - Wikimedia Foundation (with Retina Support)

## Avenue Extended Additions
- Added `.rgp` file support in the app (CSV-based route logs parsed into tracks)
- Added Quick Look preview support for both `.gpx` and `.rgp`
- Added Quick Look thumbnail support for both `.gpx` and `.rgp`
- Improved GPX/RGP loading performance for large files
- Added tag-based release automation in GitHub Actions (`v*` tag -> Intel/ARM DMG build -> GitHub Release publish)
- Minimum supported macOS version updated to `11.0+`

## Install
1. Download the latest DMG from [Releases](https://github.com/changjo/Avenue-GPX-Viewer-Extended/releases/latest).
2. Open the DMG and drag `Avenue Extended.app` to `/Applications`.
3. First launch:
   - Right-click `Avenue Extended.app` and choose `Open` (one time).
   - If macOS still blocks it, open `System Settings -> Privacy & Security`, click `Open Anyway`, then open the app again.

## Release Process
- This repository builds and publishes DMG only when a tag matching `v*` is pushed.
- Keep `MARKETING_VERSION` equal to the release version (for example, `1.0.1`).
- Increment `CURRENT_PROJECT_VERSION` as an integer build number (for example, `2`, `3`, ...).
- Create a matching tag (for example, `v1.0.1`) and push it to trigger release automation.

## Upcoming features
- Display of total tracked time
- Documentation

## Contributing
Contributions to this project will be more than welcomed. Feel free to add a pull request or open an issue.
If you require a feature that has yet to be available, do open an issue, describing why and what the feature could bring and how it would help you!

## Like the project? Check out these too!
- [iOS-Open-GPX-Tracker](https://github.com/merlos/iOS-Open-GPX-Tracker), an awesome open-sourced GPS tracker for iOS and watchOS.
- [LocaleComplete](https://github.com/vincentneo/LocaleComplete), a small library to make `Locale` identifier hunting more easy and straightforward.
- [CoreGPX](https://github.com/vincentneo/CoreGPX), a library for parsing and creation of GPX files.

## License
Avenue GPX Viewer for macOS. 

Copyright © 2020-2023 Vincent Neo, with certain codes belonging to Juan M. Merlos (@merlos) from [iOS-Open-GPX-Tracker](https://github.com/merlos/iOS-Open-GPX-Tracker), used with permission.

Modifications and maintenance in this fork are Copyright © 2025-2026 Changjo.

This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this program. If not, see http://www.gnu.org/licenses/.

Please note that this source code was released under the GPL license. So any change on the code shall be made publicly available and distributed under the GPL license (this does not apply to the swift packages included in the project which have their own license).

## Dependency
- [CoreGPX](https://github.com/vincentneo/CoreGPX), used for parsing and handling of GPX files.
- [MapCache](https://github.com/merlos/MapCache), awesome third-party map caching library.
- [Iconizer](https://github.com/raphaelhanneken/iconizer), for the draggable file icon on toolbar, for v1.4.x and above. 
