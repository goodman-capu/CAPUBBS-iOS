//
//  CAPUBBS_Widget.swift
//  CAPUBBS Widget
//
//  Created by Zhikang Fan on 7/6/26.
//  Copyright © 2026 熊典. All rights reserved.
//

import WidgetKit
import SwiftUI

let DATA_FRESHNESS = 15 * 60.0

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> WidgetEntry {
        WidgetEntry(date: Date(), username: "", newmsg: 0, hotPosts: [], globalTopCount: 0)
    }

    func getSnapshot(in context: Context, completion: @escaping (WidgetEntry) -> ()) {
        let (username, newmsg) = getUserInfo()
        let (hotPosts, globalTopCount) = getHotPosts()
        let displayDate = self.getEarliestUpdateTime() ?? Date()
        let entry = WidgetEntry(date: displayDate, username: username, newmsg: newmsg, hotPosts: hotPosts, globalTopCount: globalTopCount)
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        let currentDate = Date()
        let group = DispatchGroup()
        // 默认的下一次刷新时间（如果发了网络请求）
        var nextTimelineRefresh = currentDate.addingTimeInterval(DATA_FRESHNESS)
        
        // 检查数据新鲜度
        if let earliestUpdateTime = getEarliestUpdateTime(),
           currentDate.timeIntervalSince(earliestUpdateTime) < DATA_FRESHNESS {
            nextTimelineRefresh = max(currentDate, earliestUpdateTime.addingTimeInterval(DATA_FRESHNESS))
        } else {
            group.enter()
            NSLog("Starting to fetch user info and hot posts")
            Helper.fetchCurrentUserInfo { _, err in
                if err != nil {
                    NSLog("Fetch user info failed with error: \(String(describing: err))")
                } else {
                    NSLog("Finish fetching user info")
                }
                group.leave()
            }
            group.enter()
            Helper.fetchHotPosts { _, _, err in
                if err != nil {
                    NSLog("Fetch hot posts failed with error: \(String(describing: err))")
                } else {
                    NSLog("Finish fetching hot posts")
                }
                group.leave()
            }
        }
        
        group.notify(queue: .main) {
            let (username, newmsg) = self.getUserInfo()
            let (hotPosts, globalTopCount) = self.getHotPosts()
            
            // 重新取两者更早的时间作为重新 render 的展示时间
            let displayDate = self.getEarliestUpdateTime() ?? currentDate
            
            let entry = WidgetEntry(date: displayDate, username: username, newmsg: newmsg, hotPosts: hotPosts, globalTopCount: globalTopCount)
            let timeline = Timeline(entries: [entry], policy: .after(nextTimelineRefresh))
            completion(timeline)
        }
    }
    
    private func getEarliestUpdateTime() -> Date? {
        guard let sharedDefaults = UserDefaults(suiteName: APP_GROUP_IDENTIFIER) else {
            return nil
        }
        
        let userTimeRaw = sharedDefaults.double(forKey: "userInfoUpdateTime")
        let hotTimeRaw = sharedDefaults.double(forKey: "hotPostsUpdateTime")
        
        // 确保两个时间均存在且大于0，如果某一个没保存过，使用另一个
        if userTimeRaw > 0 && hotTimeRaw > 0 {
            let minTimestamp = min(userTimeRaw, hotTimeRaw)
            return Date(timeIntervalSince1970: minTimestamp)
        } else if userTimeRaw > 0 {
            return Date(timeIntervalSince1970: userTimeRaw)
        } else if hotTimeRaw > 0 {
            return Date(timeIntervalSince1970: hotTimeRaw)
        }
        
        return nil
    }

    private func getUserInfo() -> (username: String, newmsg: Int) {
        guard let sharedDefaults = UserDefaults(suiteName: APP_GROUP_IDENTIFIER) else {
            return ("", 0)
        }
                
        if let userInfo = sharedDefaults.dictionary(forKey: "userInfo") {
            if let username = userInfo["username"] as? String {
                return (username, Int(userInfo["newmsg"] as? String ?? "0") ?? 0)
            }
        }
        return ("", 0)
    }
    
    private func getHotPosts() -> (hotPosts: [[String: Any]], globalTopCount: Int) {
        guard let sharedDefaults = UserDefaults(suiteName: APP_GROUP_IDENTIFIER) else {
            return ([[String: Any]](), 0)
        }
        if let rawArray = sharedDefaults.array(forKey: "hotPosts"), let hotPosts = rawArray as? [[String: Any]] {
            let globalTopCount = sharedDefaults.integer(forKey: "globalTopCount")
            return (hotPosts, globalTopCount)
        }
        return ([[String: Any]](), 0)
    }
}

struct WidgetEntry: TimelineEntry {
    let date: Date
    let username: String
    let newmsg: Int
    let hotPosts: [[String: Any]]
    let globalTopCount: Int
}

struct CAPUBBS_WidgetEntryView : View {
    var entry: Provider.Entry
    @Environment(\.widgetFamily) var family
    
    var body: some View {
        VStack {
            Spacer()
            
            Link(destination: URL(string: "capubbs://?open=message")!) {
                HStack {
                    Text(entry.username.isEmpty ? "未登录" : entry.username)
                        .font(.system(size: 12, weight: .medium))
                    if !entry.username.isEmpty {
                        Text(entry.newmsg > 0 ? "\(entry.newmsg)条新消息" : "暂无新消息")
                            .font(.system(size: 11))
                            .foregroundColor(entry.newmsg > 0 ? .primary : .secondary)
                    }
                }
            }
            
            Spacer()
            Divider()
            
            let maxCount = isSmallHeight() ? 3 : 9
            let displayPosts = getFilteredPosts().prefix(maxCount)
            
            if displayPosts.isEmpty {
                Text("暂无论坛热点")
                    .font(.caption)
                    .foregroundColor(.gray)
                    .frame(maxHeight: .infinity, alignment: .center)
                
                Divider()
            } else {
                VStack(alignment: .leading, spacing: 3) {
                    ForEach(displayPosts, id: \.offset) { offset, post in
                        Link(destination: getLink(post: post, offset: offset)) {
                            HStack(alignment: .center) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(formatTitle(post: post, offset: offset))
                                        .font(.system(size: 12))
                                        .lineLimit(1)
                                    Text(formatAuthor(post: post))
                                        .font(.system(size: 9))
                                        .foregroundColor(.brown)
                                        .lineLimit(1)
                                }
                                
                                Spacer()
                                
                                let dateTime = parseDateTime(timeStr: post["time"] as? String)
                                
                                VStack(alignment: .trailing, spacing: 0) {
                                    Text(dateTime.date)
                                        .font(.system(size: 8))
                                        .foregroundColor(.secondary)
                                    
                                    Text(dateTime.time)
                                        .font(.system(size: 8))
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        Divider()
                    }
                }
            }

            Spacer()
            
            HStack {
                Text("更新于：")
                    .font(.system(size: 8))
                    .foregroundColor(.gray)
                Text(entry.date, style: .relative)
                    .font(.system(size: 8))
                    .foregroundColor(.gray)
            }
            
            Spacer()
        }
    }
    
    private func isSmallHeight() -> Bool {
        return family == .systemSmall || family == .systemMedium
    }
    
    private func getLink(post: [String: Any], offset: Int) -> URL {
        var floor = 0
        if isSmallHeight() || offset >= entry.globalTopCount {
            let pid = Int(post["pid"] as? String ?? "0") ?? 0
            floor = pid + 1
        }
        let title = formatTitle(post: post, offset: offset)
        var components = URLComponents()
        components.scheme = "capubbs"
        components.host = ""
        components.queryItems = [
            URLQueryItem(name: "open", value: "post"),
            URLQueryItem(name: "bid", value: post["bid"] as? String ?? ""),
            URLQueryItem(name: "tid", value: post["tid"] as? String ?? ""),
            URLQueryItem(name: "floor", value: String(floor)),
            URLQueryItem(name: "naviTitle", value: title)
        ]
        return components.url ?? URL(string: "capubbs://?open=hot")!
    }
    
    private func getFilteredPosts() -> [EnumeratedSequence<[[String: Any]]>.Element] {
        let enumerated = Array(entry.hotPosts.enumerated())
        if isSmallHeight() {
            return enumerated.filter { $0.offset >= entry.globalTopCount }
        }
        return enumerated
    }
    
    private func formatTitle(post: [String: Any], offset: Int) -> String {
        var prefix = "";
        if !isSmallHeight() && offset < entry.globalTopCount {
            prefix = "⬆️ "
        }
        return prefix + Helper.restoreTitle(post["text"] as? String ?? "")
    }

    private func formatAuthor(post: [String: Any]) -> String {
        let author = post["author"] as? String ?? "匿名"
        let replyer = post["replyer"] as? String ?? ""
        let pid = Int(post["pid"] as? String ?? "0") ?? 0
        if pid == 0 || replyer == "Array" || replyer.isEmpty {
            return author
        } else {
            return "\(author) / \(replyer)"
        }
    }
    
    private func parseDateTime(timeStr: String?) -> (date: String, time: String) {
        guard let time = timeStr, time.count > 15 else { return ("", "") }
        
        // 提取月-日 -> "01-01"
        let dateStart = time.index(time.startIndex, offsetBy: 5)
        let dateEnd = time.index(time.startIndex, offsetBy: 10)
        let datePart = String(time[dateStart..<dateEnd])
        
        // 提取时:分 -> "12:00"
        let timeStart = time.index(time.startIndex, offsetBy: 11)
        let timeEnd = time.index(time.startIndex, offsetBy: 16)
        let timePart = String(time[timeStart..<timeEnd])
        
        return (datePart, timePart)
    }
}

struct CAPUBBS_Widget: Widget {
    let kind: String = "CAPUBBS_Widget"
    let backgroundColor = Color(hue: 142.0/360, saturation: 0.64, brightness: 0.58, opacity: 0.15)
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            if #available(iOS 17.0, *) {
                CAPUBBS_WidgetEntryView(entry: entry)
                    .containerBackground(backgroundColor, for: .widget)
            } else {
                CAPUBBS_WidgetEntryView(entry: entry)
                    .padding()
                    .background(backgroundColor)
            }
        }
        .configurationDisplayName("CAPUBBS 小组件")
        .description("展示用户消息数和论坛热点")
    }
}

private struct PreviewData {
    static let hotPosts: [[String: Any]] = [
            [
                "tid": "10722", "pid": "9", "bid": "1",
                "text": "【2026暑期远征筹备】暑期远征口号公布",
                "author": "理事会", "replyer": "牛肉汤圆", "time": "2026-07-06 20:22:47"
            ],
            [
                "tid": "10723", "pid": "18", "bid": "1",
                "text": "【2026暑期远征】送站攻略",
                "author": "HL", "replyer": "SDNetFriend", "time": "2026-07-02 17:24:17"
            ],
            [
                "tid": "152", "pid": "10", "bid": "28",
                "text": "邮箱验证能力上线预告及建议收集（已上线）",
                "author": "好蛋", "replyer": "芒果_mangle", "time": "2026-06-26 19:32:41"
            ],
            [
                "tid": "10730", "pid": "4", "bid": "1",
                "text": "【26黑分解】队长总结",
                "author": "铃兰", "replyer": "橄榄", "time": "2026-07-08 22:54:17"
            ],
            [
                "tid": "8847", "pid": "148", "bid": "2",
                "text": "【25骑行团】暑期日志·多幸运有个我们 【Day17 清涧--延安】",
                "author": "2025骑行团", "replyer": "crashed", "time": "2026-07-08 20:52:50"
            ],
            [
                "tid": "8571", "pid": "130", "bid": "2",
                "text": "【24飞行团】暑期日志·公路尽头是夏日未了的梦【昆明-禄丰】【小暑篇】",
                "author": "2024飞行团", "replyer": "温瑶", "time": "2026-07-08 20:13:52"
            ],
            [
                "tid": "5131", "pid": "98", "bid": "3",
                "text": "【实践部】25-26年度押后考挂标准＆新增押后名单",
                "author": "实践部", "replyer": "马Boy", "time": "2026-07-08 20:04:44"
            ],
            [
                "tid": "10729", "pid": "12", "bid": "1",
                "text": "【26黑龙潭】队长总结",
                "author": "浅斟低唱", "replyer": "温瑶", "time": "2026-07-08 19:54:40"
            ],
            [
                "tid": "1241", "pid": "7", "bid": "7",
                "text": "【2026骑行团】暑期押后日志",
                "author": "石人", "replyer": "大米豆", "time": "2026-07-08 19:23:17"
            ],
            [
                "tid": "1243", "pid": "0", "bid": "7",
                "text": "【2026飞九团】暑期押后日志",
                "author": "后藤", "replyer": "", "time": "2026-07-08 14:46:54"
            ],
            [
                "tid": "20276", "pid": "7", "bid": "4",
                "text": "我要在暑期出发前更完队长总结",
                "author": "后藤", "replyer": "墨", "time": "2026-07-08 12:08:18"
            ],
            [
                "tid": "1239", "pid": "7", "bid": "7",
                "text": "【2026骑行团】暑期队医日志",
                "author": "Annan", "replyer": "马良", "time": "2026-07-08 01:00:00"
            ]
        ]
    static let timeline = [
        WidgetEntry(date: .now, username: "", newmsg: 0, hotPosts: [], globalTopCount: 0),
        WidgetEntry(date: .now, username: "好男人", newmsg: 0, hotPosts: hotPosts, globalTopCount: 3),
        WidgetEntry(date: .now, username: "这是一个很长很长很长很长很长很长很长很长的ID", newmsg: 10086, hotPosts: hotPosts, globalTopCount: 3)
    ]
}

@available(iOS 17.0, *)
#Preview("Small Widgets", as: .systemSmall) {
    CAPUBBS_Widget()
} timeline: {
    for entry in PreviewData.timeline {
        entry
    }
}

@available(iOS 17.0, *)
#Preview("Medium Widgets", as: .systemMedium) {
    CAPUBBS_Widget()
} timeline: {
    for entry in PreviewData.timeline {
        entry
    }
}

@available(iOS 17.0, *)
#Preview("Large Widgets", as: .systemLarge) {
    CAPUBBS_Widget()
} timeline: {
    for entry in PreviewData.timeline {
        entry
    }
}
