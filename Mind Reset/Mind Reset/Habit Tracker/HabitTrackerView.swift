//
//  HabitTrackerView.swift
//  Mind Reset
//
//  Serves as the main user interface for the habit-tracking feature of the app.
//  Displays a list of habits, allows users to add new habits, mark them as completed,
//  and delete them.
//
//  Created by Andika Yudhatrisna on 12/1/24.
//

import SwiftUI
import FirebaseAuth
import Combine

@available(iOS 16.0, *)
struct HabitTrackerView: View {
    // MARK: - Appearance tweak
    init() {
        let black = UIColor.black
        UITableView.appearance().backgroundColor     = black
        UITableViewCell.appearance().backgroundColor = black
        UITableViewCell.appearance().selectionStyle  = .none

        // ensure both table and its cells use a white tint for reorder handles
        UITableView.appearance().tintColor          = .white
        UITableViewCell.appearance().tintColor      = .white    // ← add this
    }
    // MARK: - Environment Objects
    @EnvironmentObject var viewModel: HabitViewModel
    @EnvironmentObject var session: SessionStore
    
    
    @State private var listEditMode: EditMode = .inactive
    @State private var showingAddHabit = false
    @State private var habitsFinishedToday: Int = 0
    @State private var cancellables = Set<AnyCancellable>()
    @State private var habitToDelete: Habit?
    @State private var showingDeleteAlert: Bool = false
    
    // New state variable for controlling the loading state.
    @State private var isLoaded: Bool = false


    // NEW: State variable to control the sort order.
    @State private var sortAscending: Bool = true

    // Dark theme & accent
    let backgroundBlack = Color.black
    let accentCyan      = Color(red: 0, green: 1, blue: 1)
    
    // Updated messages for Habit Tracker will now be computed.
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
    
    // Computed property to cycle through greetings based on the day of the year.
    private var dailyGreeting: String {
        let dayOfYear = Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 1
        return greetings[(dayOfYear - 1) % greetings.count]
    }
    
    // Computed property to cycle through habit quotes based on the day of the year.
    private var dailyQuote: String {
        let dayOfYear = Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 1
        return habitQuotes[(dayOfYear - 1) % habitQuotes.count]
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                backgroundBlack
                    .ignoresSafeArea()
                
                Group {
                    if isLoaded {
                        VStack(alignment: .leading, spacing: 16) {
                            // Habit-Focused Greeting using computed properties.
                            Text(dailyGreeting)
                                .font(.title)
                                .fontWeight(.heavy)
                                .foregroundColor(.white)
                                .shadow(color: .white.opacity(0.8), radius: 4)
                            
                            Text(dailyQuote)
                                .font(.subheadline)
                                .foregroundColor(accentCyan)
                            
                            HStack {
                                Text("Habits Finished Today: \(habitsFinishedToday)")
                                    .foregroundColor(.white)
                            }
                            .padding(.vertical, 10)
                            
                            List {
                                ForEach(Array(viewModel.habits.enumerated()), id: \.element.id) { (index, habit) in
                                    // binding into the array without relying on the index for identity
                                    NavigationLink {
                                        HabitDetailView(
                                            habit: Binding(
                                                get: { viewModel.habits[index] },
                                                set: { viewModel.habits[index] = $0 }
                                            )
                                        )
                                    } label: {
                                        HabitRow(
                                            habit: habit,
                                            completedToday: habit.dailyRecords.contains { record in
                                                Calendar.current.isDate(record.date, inSameDayAs: Date()) &&
                                                ((record.value ?? 0) > 0)
                                            },
                                            accentCyan: accentCyan,
                                            onDelete: { deleted in
                                                habitToDelete = deleted
                                                showingDeleteAlert = true
                                            },
                                            onToggleCompletion: { toggleHabitCompletion(habit) }
                                        )
                                    }
                                    .listRowBackground(Color.clear)
                                    .listRowSeparator(.hidden)
                                }

                                // ⬇︎ Drag-to-reorder handler
                                .onMove { indices, newOffset in
                                    viewModel.moveHabits(indices: indices, to: newOffset)
                                }
                            }
                            .environment(\.editMode, $listEditMode)   // ← feed the state into the List
                            .listStyle(.plain)
                            .background(backgroundBlack)

                            
                            Spacer()
                        }
                        .padding()
                        .onAppear {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                updateHabitsFinishedToday()
                            }
                            viewModel.$habits
                                .sink { _ in
                                    updateHabitsFinishedToday()
                                }
                                .store(in: &cancellables)
                        }
                    } else {
                        // Loading indicator while waiting for habits to load.
                        ProgressView("Loading habits...")
                            .foregroundColor(.white)
                    }
                }
                .id(isLoaded ? "loaded" : "loading")
                
                // Floating Add Button (always visible)
//                VStack {
//                    Spacer()
//                    HStack {
//                        Spacer()
//                        Button {
//                            showingAddHabit = true
//                        } label: {
//                            Image(systemName: "plus")
//                                .resizable()
//                                .scaledToFit()
//                                .frame(width: 20, height: 20)
//                                .foregroundColor(.black)
//                                .padding()
//                                .background(accentCyan)
//                                .clipShape(Circle())
//                                .shadow(color: accentCyan.opacity(0.6), radius: 5)
//                        }
//                        .padding()
//                    }
//                }
            }
            .sheet(isPresented: $showingAddHabit) {
                AddHabitView(viewModel: viewModel)
                    .environmentObject(session)
                    .environmentObject(viewModel)
            }
            .alert(isPresented: $showingDeleteAlert) {
                Alert(
                    title: Text("Delete Habit"),
                    message: Text("Are you sure you want to delete this habit?"),
                    primaryButton: .destructive(Text("Delete")) {
                        if let habit = habitToDelete {
                            deleteHabit(habit)
                        }
                        habitToDelete = nil
                    },
                    secondaryButton: .cancel {
                        habitToDelete = nil
                    }
                )
            }
            .toolbar {
                // ─── Custom Edit/Done toggle ───────────────────────────────
                ToolbarItem(placement: .navigationBarLeading) {
                        Button {
                            withAnimation {
                                listEditMode = (listEditMode == .active ? .inactive : .active)
                            }
                        } label: {
                            Text(listEditMode == .active ? "Done" : "Edit Order")
                                .foregroundColor(.white)
                        }
                    }

                // Right-side “+” button (unchanged)
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingAddHabit = true
                    } label: {
                        Image(systemName: "plus")
                            .foregroundColor(accentCyan)
                    }
                }
            }
            //.navigationBarHidden(true)
            .onAppear {
                guard let userId = session.current_user?.uid else {
                    print("No authenticated user found; cannot fetch habits.")
                    return
                }
                viewModel.fetchHabits(for: userId)
                viewModel.setupDefaultHabitsIfNeeded(for: userId)
            }
            // Timer publisher that fires every 0.5 seconds.
            .onReceive(Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()) { _ in
                updateIsLoaded()
            }
        }
    }
    
    // MARK: - Helpers
    
    private func updateHabitsFinishedToday() {
        habitsFinishedToday = viewModel.habits.filter { habit in
            Calendar.current.isDateInToday(Date()) &&
            habit.dailyRecords.contains { record in
                Calendar.current.isDate(record.date, inSameDayAs: Date()) && ((record.value ?? 0) > 0)
            }
        }.count
    }
    
    private func toggleHabitCompletion(_ habit: Habit) {
        viewModel.toggleHabitCompletion(habit, userId: habit.ownerId)
    }
    
    private func deleteHabit(_ habit: Habit) {
        viewModel.deleteHabit(habit)
    }
    
    private func sortHabits() {
        viewModel.habits.sort {
            sortAscending
                ? $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
                : $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedDescending
        }
        sortAscending.toggle()
    }
    
    private func updateIsLoaded() {
        withAnimation {
            isLoaded = viewModel.defaultsLoaded && !viewModel.habits.isEmpty
        }
        if viewModel.defaultsLoaded && viewModel.habits.isEmpty, let userId = session.current_user?.uid {
            viewModel.fetchHabits(for: userId)
        }
    }
    
    private func moveHabitUp(_ habit: Habit) {
        if let index = viewModel.habits.firstIndex(where: { $0.id == habit.id }), index > 0 {
            viewModel.habits.swapAt(index, index - 1)
        }
    }
    
    private func moveHabitDown(_ habit: Habit) {
        if let index = viewModel.habits.firstIndex(where: { $0.id == habit.id }),
           index < viewModel.habits.count - 1 {
            viewModel.habits.swapAt(index, index + 1)
        }
    }
}

struct HabitRow: View {
    let habit: Habit
    let completedToday: Bool
    let accentCyan: Color
    let onDelete: (Habit) -> Void
    let onToggleCompletion: () -> Void

    @Environment(\.editMode) private var editMode

    var body: some View {
        HStack(spacing: 12) {

            // (1) Main title / goal
            VStack(alignment: .leading, spacing: 4) {
                Text(habit.title)
                    .font(.headline)
                    .foregroundColor(.white)
                Text(habit.goal)
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.7))
            }

            Spacer()

            // (2) Toggle-completion button
            Button(action: onToggleCompletion) {
                Image(systemName: completedToday
                        ? "checkmark.circle.fill"
                        : "circle")
                    .font(.headline)
                    .foregroundColor(completedToday ? .green : accentCyan)
                    .frame(width: 30, height: 30)
                    .background(
                        (completedToday ? Color.green : accentCyan)
                            .opacity(0.2)
                    )
                    .clipShape(Circle())
            }
            .buttonStyle(PlainButtonStyle())

            // (3) Delete button (optional – keep if you still use it)
            Button {
                onDelete(habit)
            } label: {
                Image(systemName: "trash")
                    .foregroundColor(.red)
            }
            .buttonStyle(BorderlessButtonStyle())
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


struct StreakBadge: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.caption2)
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color)
            .clipShape(Capsule())
    }
}
