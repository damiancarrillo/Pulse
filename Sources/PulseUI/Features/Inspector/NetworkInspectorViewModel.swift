// The MIT License (MIT)
//
// Copyright (c) 2020–2022 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import CoreData
import PulseCore
import Combine

final class NetworkInspectorViewModel: ObservableObject {
    private(set) var title: String = ""
    let request: LoggerNetworkRequestEntity
    private let objectId: NSManagedObjectID
    let store: LoggerStore // TODO: make it private
    @Published private var summary: NetworkLoggerSummary
    private var cancellable: AnyCancellable?
    let progress: ProgressViewModel

    let summaryViewModel: NetworkInspectorSummaryViewModel
    let responseViewModel: NetworkInspectorResponseViewModel

    init(request: LoggerNetworkRequestEntity, store: LoggerStore) {
        self.objectId = request.objectID
        self.request = request
        self.store = store
        self.summary = NetworkLoggerSummary(request: request, store: store)

        #warning("REMIVE")
        self.progress = ProgressViewModel(request: request)

        if let url = request.url.flatMap(URL.init(string:)) {
            self.title = url.lastPathComponent
        }

        self.summaryViewModel = NetworkInspectorSummaryViewModel(request: request, store: store)
        self.responseViewModel = NetworkInspectorResponseViewModel(request: request, store: store)

        self.cancellable = request.objectWillChange.sink { [weak self] in
            withAnimation {
                self?.refresh()
            }
        }
    }

    private func refresh() {
        _requestViewModel = nil
        summary = NetworkLoggerSummary(request: request, store: store)
    }

    var pin: PinButtonViewModel? {
        request.message.map {
            PinButtonViewModel(store: store, message: $0)
        }
    }

    #warning("TEMO")
    var isCompleted: Bool {
        request.state == .failure || request.state == .success
    }

    var hasRequestBody: Bool {
        request.requestBodyKey != nil
    }

    var hasResponseBody: Bool {
        request.requestBodyKey != nil
    }

    // MARK: - Tabs

    #warning("TODO: the body should be ready lazily AND text view to load lazily too")

    // important:
    private var _requestViewModel: FileViewerViewModel?

    func makeRequestBodyViewModel() -> FileViewerViewModel? {
        if let viewModel = _requestViewModel {
            return viewModel
        }
        guard let requestBody = summary.requestBody, !requestBody.isEmpty else { return nil }
        let viewModel = FileViewerViewModel(title: "Request", data: { requestBody })
        _requestViewModel = viewModel
        return viewModel
    }

    func makeHeadersModel() -> NetworkInspectorHeaderViewModel {
        NetworkInspectorHeaderViewModel(summary: summary)
    }

#if !os(watchOS)
    func makeMetricsModel() -> NetworkInspectorMetricsViewModel? {
        summary.metrics.map(NetworkInspectorMetricsViewModel.init)
    }
#endif

    // MARK: Sharing

    func prepareForSharing() -> String {
        ConsoleShareService(store: store).share(summary, output: .plainText)
    }

    var shareService: ConsoleShareService {
        ConsoleShareService(store: store)
    }
}

#warning("TODO: parse request/respones/metrics lazily")