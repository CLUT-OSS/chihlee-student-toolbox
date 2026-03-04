import SwiftUI

struct QuickNotesView: View {
    @AppStorage("quickNotes") private var notes = ""

    var body: some View {
        VStack {
            TextEditor(text: $notes)
                .padding(4)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(Color(.systemGray4))
                )
                .padding()

            HStack {
                Text("自動儲存")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(notes.count) 字")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal)
            .padding(.bottom)
        }
        .navigationTitle("快速備忘錄")
        .navigationBarTitleDisplayMode(.inline)
    }
}
