import SwiftUI

struct QuickLinksView: View {
    private let links: [(name: String, url: String, icon: String)] = [
        ("致理科技大學首頁", "https://www.chihlee.edu.tw", "building.columns"),
        ("校務行政系統", "https://aps.chihlee.edu.tw", "server.rack"),
        ("數位學習平台", "https://elearning.chihlee.edu.tw", "laptopcomputer"),
        ("圖書館", "https://lib.chihlee.edu.tw", "books.vertical"),
        ("學生信箱", "https://mail.google.com", "envelope"),
        ("選課系統", "https://aps.chihlee.edu.tw", "list.clipboard"),
    ]

    var body: some View {
        List {
            ForEach(links, id: \.url) { link in
                if let url = URL(string: link.url) {
                    Link(destination: url) {
                        Label {
                            Text(link.name)
                                .foregroundStyle(.primary)
                        } icon: {
                            Image(systemName: link.icon)
                                .foregroundStyle(.blue)
                        }
                    }
                }
            }
        }
        .navigationTitle("常用連結")
        .navigationBarTitleDisplayMode(.inline)
    }
}
