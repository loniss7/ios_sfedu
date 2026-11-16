import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = HangmanViewModel()

    private let adaptiveColumns = [GridItem(.adaptive(minimum: 148), spacing: 12)]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    intro
                    gameControls
                    gameFacts

                    if !viewModel.scores.isEmpty {
                        scoreboard
                    }

                    transcript
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 24)
                .frame(maxWidth: 720)
                .frame(maxWidth: .infinity)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("Виселица")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var intro: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(viewModel.gameFinished ? "Партия завершена" : "Соревновательная виселица")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .fixedSize(horizontal: false, vertical: true)

            Text("Два игрока по очереди открывают буквы. За правильные ответы начисляются очки, за ошибки — снимаются.")
                .font(.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var gameControls: some View {
        VStack(spacing: 10) {
            Button(action: viewModel.startNewGame) {
                Label(viewModel.gameFinished ? "Сыграть ещё раз" : "Начать игру", systemImage: "play.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 5)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(viewModel.isRunning)
            .accessibilityHint("Запускает пять автоматических раундов и показывает текстовый журнал партии")

            if viewModel.gameFinished {
                Button(action: viewModel.resetGame) {
                    Label("Сбросить результаты", systemImage: "arrow.counterclockwise")
                }
                    .buttonStyle(.bordered)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var gameFacts: some View {
        LazyVGrid(columns: adaptiveColumns, alignment: .leading, spacing: 12) {
            FactCard(title: "Игроки", value: "2", symbol: "person.2.fill")
            FactCard(title: "Раунды", value: "5", symbol: "arrow.2.circlepath")
            FactCard(title: "Ошибки на слово", value: "6", symbol: "xmark.circle")
        }
    }

    private var scoreboard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Счёт")
                .font(.title3.weight(.bold))

            LazyVGrid(columns: adaptiveColumns, alignment: .leading, spacing: 12) {
                ForEach(viewModel.scores, id: \.playerID) { score in
                    HStack {
                        Text(score.playerName)
                            .font(.headline)
                        Spacer(minLength: 8)
                        Text("\(score.score)")
                            .font(.system(.title3, design: .rounded).weight(.bold))
                            .monospacedDigit()
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .surfaceCard()
                }
            }
        }
    }

    private var transcript: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Ход игры")
                    .font(.title3.weight(.bold))
                Spacer()
                if viewModel.roundsPlayed > 0 {
                    Text("Раундов: \(viewModel.roundsPlayed)/5")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                }
            }

            if viewModel.transcript.isEmpty {
                Text("Журнал партии появится здесь после запуска игры.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .surfaceCard()
            } else {
                Text(viewModel.transcript)
                    .font(.system(.footnote, design: .monospaced))
                    .lineSpacing(4)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .surfaceCard()
            }
        }
    }
}

private struct FactCard: View {
    let title: String
    let value: String
    let symbol: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: symbol)
                .foregroundStyle(.tint)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 3) {
                Text(value)
                    .font(.headline.monospacedDigit())
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .surfaceCard()
    }
}

private struct SurfaceCard: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private extension View {
    func surfaceCard() -> some View {
        modifier(SurfaceCard())
    }
}
