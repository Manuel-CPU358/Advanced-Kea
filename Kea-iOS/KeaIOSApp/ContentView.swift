import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @StateObject private var vm = MainViewModel()
    @State private var isImporterPresented = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Webtoon Links") {
                    TextEditor(text: $vm.urlInput)
                        .frame(minHeight: 90)
                    HStack {
                        Button("Add all to queue") { vm.addToQueue() }
                        Spacer()
                        Button("Remove all", role: .destructive) { vm.removeAll() }
                    }
                }

                Section("Queue") {
                    if vm.queue.isEmpty {
                        Text("No titles in queue")
                            .foregroundStyle(.secondary)
                    } else {
                        List {
                            ForEach(vm.queue) { item in
                                VStack(alignment: .leading) {
                                    Text("(\(item.titleNo)) \(item.toonTitleName)")
                                        .font(.headline)
                                    Text("Language: \(item.toonTranslationLanguageCode), Team: \(item.toonTranslationTeamVersion)")
                                        .font(.caption)
                                }
                            }
                            .onDelete(perform: vm.removeSelected)
                        }
                        .frame(height: 220)
                    }
                }

                Section("Saving") {
                    Picker("Save as", selection: $vm.saveAs) {
                        ForEach(SaveAsOption.allCases) { option in
                            Text(option.rawValue).tag(option)
                        }
                    }
                    .onChange(of: vm.saveAs) { _, newValue in
                        vm.chapterFolders = newValue == .multipleImages
                    }

                    Toggle("Each cartoon folder", isOn: $vm.cartoonFolders)
                    Toggle("Each chapter folder", isOn: $vm.chapterFolders)
                        .disabled(vm.saveAs != .multipleImages)
                    Toggle("High quality", isOn: $vm.highestQuality)
                    Toggle("Skip downloaded chapters", isOn: $vm.skipDownloadedChapters)
                        .disabled(vm.saveAs == .multipleImages)

                    Button(vm.saveFolder?.path ?? "Select save folder") {
                        isImporterPresented = true
                    }
                    .fileImporter(
                        isPresented: $isImporterPresented,
                        allowedContentTypes: [UTType.folder],
                        allowsMultipleSelection: false
                    ) { result in
                        if case let .success(urls) = result {
                            vm.saveFolder = urls.first
                        }
                    }
                }

                Section("Status") {
                    Text(vm.processInfo)
                    ProgressView(value: vm.progress)
                }

                Section {
                    Button(vm.isDownloading ? "Downloading..." : "Start") {
                        Task { await vm.startDownload() }
                    }
                    .disabled(vm.isDownloading || vm.queue.isEmpty)
                }
            }
            .navigationTitle("Kea iOS")
        }
    }
}

#Preview {
    ContentView()
}
