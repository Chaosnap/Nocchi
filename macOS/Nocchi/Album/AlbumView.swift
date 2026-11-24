import AppKit
import NocchiKit
import NocchiUI
import SwiftUI

/// 相册窗口：顶栏（字标、四种看法、搜索、冲印）+ 当前看法。
///
/// 搜索对四种看法都生效（`PhotoSearch`）：软木板、胶卷、日历直接只显示命中的照片，
/// 卡片盒把命中的照片从盒子里抽出来摊开。
struct AlbumView: View {
    @ObservedObject private var store = LibraryStore.shared
    @ObservedObject private var router = AlbumRouter.shared
    @State private var query = ""
    @FocusState private var searchFocused: Bool
    @ObservedObject private var cardBox: CardBoxModel = AlbumRouter.shared.cardBox

    var body: some View {
        let results = PhotoSearch.filter(store.records, query: query)
        let searching = !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        VStack(spacing: 0) {
            AlbumHeader(mode: $router.mode, query: $query, searchFocused: $searchFocused, indexMode: $cardBox.indexMode)
            ZStack {
                content(results)
                    .id(router.mode)
                    .transition(.opacity)
                if searching, results.isEmpty, !store.records.isEmpty {
                    NoResultsSlip(query: query)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .animation(.easeOut(duration: 0.22), value: router.mode)
        }
        .background(Palette.paper)
        .ignoresSafeArea(.container, edges: .top)
        .frame(minWidth: 980, minHeight: 700)
        .onAppear {
            store.reload()
            cardBox.update(records: store.records)
        }
        .onReceive(store.$records) { records in
            cardBox.update(records: records)
        }
        .task(id: query) {
            // 边打字边搜：停顿一下再让卡片盒抽卡，免得卡片来回飞。
            try? await Task.sleep(nanoseconds: 320_000_000)
            guard !Task.isCancelled else { return }
            cardBox.applySearch(query)
        }
        .onChange(of: router.searchRequest) { _, _ in
            searchFocused = true
        }
    }

    @ViewBuilder
    private func content(_ results: [PhotoRecord]) -> some View {
        switch router.mode {
        case .cork:
            CorkBoardView(records: results, libraryIsEmpty: store.records.isEmpty)
        case .cardBox:
            CardBoxView(model: cardBox) { record in
                AlbumContextMenu(record: record)
            }
        case .film:
            FilmLightTable(records: results, libraryIsEmpty: store.records.isEmpty)
        case .calendar:
            CalendarWallView(records: results, libraryIsEmpty: store.records.isEmpty)
        }
    }
}
