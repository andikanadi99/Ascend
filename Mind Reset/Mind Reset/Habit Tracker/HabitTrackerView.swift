//
//  HabitTrackerView.swift
//  Mind Reset
//
//

import SwiftUI
import FirebaseAuth
import Combine

@available(iOS 16.0, *)
struct HabitTrackerView: View {

    // ───────────────────────────────────── Appearance tweaks
    init() {
        let blk = UIColor.black
        UITableView.appearance().backgroundColor     = blk
        UITableViewCell.appearance().backgroundColor = blk
        UITableView.appearance().tintColor           = .white
        UITableViewCell.appearance().tintColor       = .white
        UITableViewCell.appearance().selectionStyle  = .none
    }

    // ───────────────────────────────────── Environment
    @EnvironmentObject var viewModel: HabitViewModel
    @EnvironmentObject var session:   SessionStore

    // ───────────────────────────────────── Local state
    @State private var editMode:      EditMode = .inactive
    @State private var showingAddHabit          = false
    @State private var habitToDelete: Habit?    = nil
    @State private var showingDeleteAlert       = false
    @State private var isLoaded                 = false
    @State private var cancellables             = Set<AnyCancellable>()

    // ───────────────────────────────────── Theme
    private let backgroundBlack = Color.black
    private let accentCyan      = Color(red: 0, green: 1, blue: 1)

    // Greetings & quotes
    private let greetings = [
        "Welcome back! Let's build powerful habits today.",
        "Welcome back! Every habit fuels progress.",
        "Welcome back! Consistency drives success.",
        "Welcome back! Small habits, big impact.",
        "Welcome back! Every routine counts."
    ]
    private let habitQuotes = [
        "Stay consistent—habits shape your future.",
        "Small daily actions lead to lasting outcomes.",
        "Success is built on daily discipline.",
        "Every small habit contributes to a bigger change.",
        "Focus on progress, one habit at a time."
    ]
    private var dailyGreeting: String {
        let d = Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 1
        return greetings[(d - 1) % greetings.count]
    }
    private var dailyQuote: String {
        let d = Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 1
        return habitQuotes[(d - 1) % habitQuotes.count]
    }

    // ───────────────────────────────────── Body
    var body: some View {
        NavigationView {
            ZStack {
                backgroundBlack.ignoresSafeArea()

                Group {
                    if isLoaded {
                        VStack(alignment: .leading, spacing: 16) {
                            // Top greeting
                            Text(dailyGreeting)
                                .font(.title)
                                .fontWeight(.heavy)
                                .foregroundColor(.white)
                                .shadow(color: .white.opacity(0.8), radius: 4)

                            Text(dailyQuote)
                                .font(.subheadline)
                                .foregroundColor(accentCyan)

                            // Spacer pushes list downward to centre it vertically
                            Spacer(minLength: 0)

                            // Habit list (vertically centred)
                            habitList
                                .frame(maxWidth: .infinity)
                                .padding(.bottom, 8)

                            // Matching spacer below list
                            Spacer(minLength: 0)
                        }
                        .padding()
                    } else {
                        ProgressView("Loading habits…")
                            .foregroundColor(.white)
                    }
                }

                // Floating add button
                addButtonOverlay
            }
            .sheet(isPresented: $showingAddHabit) {
                AddHabitView(viewModel: viewModel)
                    .environmentObject(session)
                    .environmentObject(viewModel)
            }
            .alert(isPresented: $showingDeleteAlert) { deleteAlert }
            .onAppear(perform: fetchHabitsIfNeeded)
            .onReceive(
                Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()
            ) { _ in
                withAnimation { isLoaded = viewModel.defaultsLoaded }
            }
        }
    }

    // ───────────────────────── Habit list
    private var habitList: some View {
        List {
            ForEach(Array(viewModel.habits.enumerated()), id: \.element.id) { (idx, habit) in
                let finished = habit.dailyRecords.contains {
                    Calendar.current.isDate($0.date, inSameDayAs: Date()) &&
                    (($0.value ?? 0) > 0)
                }

                NavigationLink {
                    HabitDetailView(
                        habit: Binding(
                            get: { viewModel.habits[idx] },
                            set: { viewModel.habits[idx] = $0 }
                        )
                    )
                } label: {
                    HabitRow(
                        habit: habit,
                        completedToday: finished,
                        accentCyan: accentCyan,
                        onDelete: { h in
                            habitToDelete = h
                            showingDeleteAlert = true
                        }
                    )
                }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }
            .onMove { idx, new in viewModel.moveHabits(indices: idx, to: new) }
        }
        .environment(\.editMode, $editMode)
//        .scrollDisabled(true)
        .listStyle(.plain)
        .background(backgroundBlack)
    }

    // ───────────────────────── Floating “+”
    private var addButtonOverlay: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                Button { showingAddHabit = true } label: {
                    Image(systemName: "plus")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 20, height: 20)
                        .foregroundColor(.black)
                        .padding()
                        .background(accentCyan)
                        .clipShape(Circle())
                        .shadow(color: accentCyan.opacity(0.6), radius: 5)
                }
                .padding()
            }
        }
    }

    // ───────────────────────── Delete alert
    private var deleteAlert: Alert {
        Alert(
            title: Text("Delete Habit"),
            message: Text("Are you sure you want to delete this habit?"),
            primaryButton: .destructive(Text("Delete")) {
                if let h = habitToDelete { viewModel.deleteHabit(h) }
                habitToDelete = nil
            },
            secondaryButton: .cancel { habitToDelete = nil }
        )
    }

    // ───────────────────────── Data fetch
    private func fetchHabitsIfNeeded() {
        if let uid = session.current_user?.uid {
            viewModel.fetchHabits(for: uid)
            viewModel.setupDefaultHabitsIfNeeded(for: uid)
        }
    }
}

// ─────────────────────────────────────────────────────────
// MARK: – HabitRow (read-only check icon + trash)
// ─────────────────────────────────────────────────────────
private struct HabitRow: View {
    let habit: Habit
    let completedToday: Bool
    let accentCyan: Color
    let onDelete: (Habit) -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Title & goal
            VStack(alignment: .leading, spacing: 4) {
                Text(habit.title)
                    .font(.headline)
                    .foregroundColor(.white)
                Text(habit.goal)
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.7))
            }

            Spacer()

            // Completion icon (read-only)
            Image(systemName: completedToday ? "checkmark.circle.fill" : "circle")
                .font(.headline)
                .foregroundColor(completedToday ? .green : accentCyan)
                .frame(width: 30, height: 30)

            // Trash
            Button(role: .destructive) { onDelete(habit) } label: {
                Image(systemName: "trash")
                    .foregroundColor(.red)
            }
            .buttonStyle(.borderless)
        }
        .padding()
        .background(
            Color(red: 0.15, green: 0.15, blue: 0.15)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(accentCyan.opacity(0.7), lineWidth: 1)
                )
        )
        .cornerRadius(8)
    }
}
