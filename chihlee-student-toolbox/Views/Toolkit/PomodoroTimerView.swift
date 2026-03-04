import SwiftUI

struct PomodoroTimerView: View {
    @State private var viewModel = ToolkitViewModel()

    var body: some View {
        VStack(spacing: 32) {
            Text(viewModel.isWorking ? "專注時間" : "休息時間")
                .font(.title2.bold())
                .foregroundStyle(viewModel.isWorking ? .red : .green)

            ZStack {
                Circle()
                    .stroke(Color(.systemGray5), lineWidth: 12)

                Circle()
                    .trim(from: 0, to: viewModel.timerProgress)
                    .stroke(
                        viewModel.isWorking ? Color.red : Color.green,
                        style: StrokeStyle(lineWidth: 12, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 1), value: viewModel.timerProgress)

                Text(viewModel.timerDisplay)
                    .font(.system(size: 48, weight: .bold, design: .monospaced))
            }
            .frame(width: 220, height: 220)

            HStack(spacing: 24) {
                Button {
                    viewModel.resetTimer()
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }

                Button {
                    viewModel.toggleTimer()
                } label: {
                    Image(systemName: viewModel.isTimerRunning ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 64))
                        .foregroundStyle(viewModel.isWorking ? .red : .green)
                }
            }

            // Settings
            VStack(spacing: 12) {
                Stepper("工作 \(viewModel.pomodoroMinutes) 分鐘", value: $viewModel.pomodoroMinutes, in: 1...60)
                    .onChange(of: viewModel.pomodoroMinutes) { _, _ in
                        if !viewModel.isTimerRunning { viewModel.resetTimer() }
                    }
                Stepper("休息 \(viewModel.breakMinutes) 分鐘", value: $viewModel.breakMinutes, in: 1...30)
            }
            .padding(.horizontal, 32)

            Spacer()
        }
        .padding(.top, 32)
        .navigationTitle("番茄鐘")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: viewModel.isTimerRunning) {
            guard viewModel.isTimerRunning else { return }
            let clock = ContinuousClock()

            while !Task.isCancelled && viewModel.isTimerRunning {
                try? await clock.sleep(for: .seconds(1))
                if Task.isCancelled || !viewModel.isTimerRunning { break }
                await MainActor.run {
                    viewModel.tick()
                }
            }
        }
    }
}
