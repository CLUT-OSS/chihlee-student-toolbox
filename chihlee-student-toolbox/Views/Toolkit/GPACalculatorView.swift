import SwiftUI

struct GPACalculatorView: View {
    @State private var viewModel = ToolkitViewModel()

    private let gradeOptions: [(label: String, point: Double)] = [
        ("A+ (4.3)", 4.3),
        ("A  (4.0)", 4.0),
        ("A- (3.7)", 3.7),
        ("B+ (3.3)", 3.3),
        ("B  (3.0)", 3.0),
        ("B- (2.7)", 2.7),
        ("C+ (2.3)", 2.3),
        ("C  (2.0)", 2.0),
        ("C- (1.7)", 1.7),
        ("D  (1.0)", 1.0),
        ("F  (0.0)", 0.0),
    ]

    var body: some View {
        Form {
            Section {
                ForEach(Array(viewModel.gpaEntries.enumerated()), id: \.element.id) { index, _ in
                    VStack(spacing: 8) {
                        TextField("課程名稱", text: $viewModel.gpaEntries[index].courseName)

                        HStack {
                            Stepper("學分: \(viewModel.gpaEntries[index].credits)", value: $viewModel.gpaEntries[index].credits, in: 1...6)
                        }

                        Picker("等第", selection: $viewModel.gpaEntries[index].gradePoint) {
                            ForEach(gradeOptions, id: \.point) { option in
                                Text(option.label).tag(option.point)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
                .onDelete { viewModel.removeGPAEntry(at: $0) }

                Button {
                    viewModel.addGPAEntry()
                } label: {
                    Label("新增課程", systemImage: "plus.circle")
                }
            }

            Section("計算結果") {
                HStack {
                    Text("GPA")
                        .font(.headline)
                    Spacer()
                    Text(String(format: "%.2f", viewModel.calculatedGPA))
                        .font(.title.bold())
                        .foregroundStyle(.blue)
                }

                let totalCredits = viewModel.gpaEntries.reduce(0) { $0 + $1.credits }
                HStack {
                    Text("總學分")
                    Spacer()
                    Text("\(totalCredits)")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("GPA 計算機")
        .navigationBarTitleDisplayMode(.inline)
    }
}
