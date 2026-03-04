import SwiftUI

struct ClassSessionCell: View {
    let sessions: [ClassSession]
    var isCurrent: Bool = false

    private var primarySession: ClassSession? {
        sessions.first(where: { $0.course != nil }) ?? sessions.first
    }

    var body: some View {
        Group {
            if let session = primarySession, let course = session.course {
                VStack(spacing: 2) {
                    if let url = URL(string: session.syllabusURL), !session.syllabusURL.isEmpty {
                        Link(destination: url) {
                            Text(course.name)
                                .font(.system(size: 9, weight: .medium))
                                .lineLimit(2)
                                .multilineTextAlignment(.center)
                        }
                        .foregroundStyle(.primary)
                    } else {
                        Text(course.name)
                            .font(.system(size: 9, weight: .medium))
                            .lineLimit(2)
                            .multilineTextAlignment(.center)
                    }
                    Text(session.classroom)
                        .font(.system(size: 7))
                        .foregroundStyle(.secondary)
                    if sessions.count > 1 {
                        Text("+\(sessions.count - 1) 門")
                            .font(.system(size: 7, weight: .bold))
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 44)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .strokeBorder(isCurrent ? .blue : .clear, lineWidth: 2)
                )
            } else {
                Color.clear
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }
}
