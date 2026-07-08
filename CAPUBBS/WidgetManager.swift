//
//  WidgetBridge.swift
//  CAPUBBS
//
//  Created by Zhikang Fan on 7/6/26.
//  Copyright © 2026 熊典. All rights reserved.
//

import Foundation
import WidgetKit

@objc class WidgetManager: NSObject {
    @objc static func reloadWidgets() {
        WidgetCenter.shared.reloadAllTimelines()
    }
}
