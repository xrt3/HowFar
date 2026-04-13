//
//  MapCoordinateAlignment.swift
//  MileMate
//
//  中国大陆区域 WGS-84 → GCJ-02（火星坐标）可选转换，用于轨迹与 Apple 地图底图对齐。
//  默认关闭：部分环境下 Core Location 已与底图一致，开启可能导致重复偏移。
//

import CoreLocation
import Foundation

enum MapCoordinateAlignment {
    /// 为 `true` 时，在中国大陆近似范围内将坐标按 WGS-84→GCJ-02 转换后用于地图绘制。
    static var convertWGS84ToGCJ02ForMainlandDisplay = false

    static func displayCoordinate(_ coordinate: CLLocationCoordinate2D) -> CLLocationCoordinate2D {
        guard convertWGS84ToGCJ02ForMainlandDisplay else { return coordinate }
        return MainlandGCJ02Transform.wgs84ToGCJ02IfInChinaRegion(coordinate)
    }

    static func displayCoordinate(latitude: Double, longitude: Double) -> CLLocationCoordinate2D {
        displayCoordinate(CLLocationCoordinate2D(latitude: latitude, longitude: longitude))
    }
}

private enum MainlandGCJ02Transform {
    private static let a: Double = 6_378_245.0
    private static let ee: Double = 0.00669342162296594323

    /// 与常见开源实现一致的「境外」判断矩形（含大陆主体，排除部分海岛边界以简化）。
    static func wgs84ToGCJ02IfInChinaRegion(_ wgs: CLLocationCoordinate2D) -> CLLocationCoordinate2D {
        guard !isOutsideChinaRegion(wgs) else { return wgs }
        return wgs84ToGCJ02(wgs)
    }

    private static func isOutsideChinaRegion(_ coord: CLLocationCoordinate2D) -> Bool {
        if coord.longitude < 72.004 || coord.longitude > 137.8347 { return true }
        if coord.latitude < 0.8293 || coord.latitude > 55.8271 { return true }
        return false
    }

    private static func wgs84ToGCJ02(_ wgs: CLLocationCoordinate2D) -> CLLocationCoordinate2D {
        var dLat = transformLatitude(x: wgs.longitude - 105.0, y: wgs.latitude - 35.0)
        var dLon = transformLongitude(x: wgs.longitude - 105.0, y: wgs.latitude - 35.0)
        let radLat = wgs.latitude / 180.0 * .pi
        var magic = sin(radLat)
        magic = 1 - ee * magic * magic
        let sqrtMagic = sqrt(magic)
        dLat = (dLat * 180.0) / ((a * (1 - ee)) / (magic * sqrtMagic) * .pi)
        dLon = (dLon * 180.0) / (a / sqrtMagic * cos(radLat) * .pi)
        return CLLocationCoordinate2D(
            latitude: wgs.latitude + dLat,
            longitude: wgs.longitude + dLon
        )
    }

    private static func transformLatitude(x: Double, y: Double) -> Double {
        var ret = -100.0 + 2.0 * x + 3.0 * y + 0.2 * y * y + 0.1 * x * y + 0.2 * sqrt(abs(x))
        ret += (20.0 * sin(6.0 * x * .pi) + 20.0 * sin(2.0 * x * .pi)) * 2.0 / 3.0
        ret += (20.0 * sin(y * .pi) + 40.0 * sin(y / 3.0 * .pi)) * 2.0 / 3.0
        ret += (160.0 * sin(y / 12.0 * .pi) + 320 * sin(y * .pi / 30.0)) * 2.0 / 3.0
        return ret
    }

    private static func transformLongitude(x: Double, y: Double) -> Double {
        var ret = 300.0 + x + 2.0 * y + 0.1 * x * x + 0.1 * x * y + 0.1 * sqrt(abs(x))
        ret += (20.0 * sin(6.0 * x * .pi) + 20.0 * sin(2.0 * x * .pi)) * 2.0 / 3.0
        ret += (20.0 * sin(x * .pi) + 40.0 * sin(x / 3.0 * .pi)) * 2.0 / 3.0
        ret += (150.0 * sin(x / 12.0 * .pi) + 300.0 * sin(x / 30.0 * .pi)) * 2.0 / 3.0
        return ret
    }
}
