//
//  MainlandLocalNetworkPermission.swift
//  MileMate
//

import Foundation
import Network

/// iOS 无单独的「互联网」弹窗；本地网络权限是常见的网络相关隐私授权。
/// 在中国大陆区域机型上，于用户首次同意定位后触发一次，以满足部分合规与上架说明场景。
enum MainlandLocalNetworkPermission {
    private static let defaultsKey = "MileMate.didTriggerLocalNetworkAfterFirstLocationGrant"

    static var isMainlandChinaUserRegion: Bool {
        Locale.current.region?.identifier == "CN"
    }

    /// 在用户首次从「未决定」变为已定位授权时调用（仅中国大陆区域设置下尝试一次）。
    static func requestAfterFirstLocationGrantIfNeeded() {
        guard isMainlandChinaUserRegion else { return }
        guard !UserDefaults.standard.bool(forKey: defaultsKey) else { return }
        UserDefaults.standard.set(true, forKey: defaultsKey)

        let browser = NWBrowser(for: .bonjour(type: "_http._tcp", domain: nil), using: .tcp)
        browser.start(queue: .main)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            browser.cancel()
        }
    }
}
