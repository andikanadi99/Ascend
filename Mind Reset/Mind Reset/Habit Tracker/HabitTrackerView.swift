//
//  HabitTrackerView.swift
//  Mind Reset
//
//  Objective: Serves as the main user interface for the habit-tracking feature of the app.
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
    // MARK: - Environment Objects
    @EnvironmentObject var viewModel: HabitViewModel
    @EnvironmentObject var session: SessionStore

    @State private var showingAddHabit = false

    // Dark theme & accent
    let backgroundBlack = Color.black
    let accentCyan      = Color(red: 0, green: 1, blue: 1)

    // Placeholder daily quote
    let dailyQuote = "Focus on what matters today."

    // Tracks how many habits were finished today
    @State private var habitsFinishedToday: Int = 0

    // Combine Cancellables
    @State private var cancellables = Set<AnyCancellable>()

    var body: some View {
        NavigationView {
            ZStack {
                backgroundBlack.ignoresSafeArea()

                VStack(alignment: .leading, spacing: 16) {
                    // Personalized Greeting
                    Text(greetingMessage)
                        .font(.title)
                        .fontWeight(.heavy)
                        .foregroundColor(.white)
                        .shadow(color: .white.opacity(0.8), radius: 4)

                    // Daily Motivational Quote
                    Text(dailyQuote)
                        .font(.subheadline)
                        .foregroundColor(accentCyan)

                    // Habits Finished Today
                    HStack {
                        Text("Habits Finished Today: \(habitsFinishedToday)")
                            .foregroundColor(.white)
                    }
                    .padding(.vertical, 10)

                    // Habit List
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(viewModel.habits.indices, id: \.self) { index in
                                let habit = viewModel.habits[index]
                                // We’ll fetch local streak from viewModel.localStreaks
                                let localStreak = viewModel.localStreaks[habit.id ?? ""] ?? habit.currentStreak

                                NavigationLink(
                                    destination: HabitDetailView(habit: $viewModel.habits[index])
                                ) {
                                    // Pass the local streak
                                    HabitRow(
                                        habit: habit,
                                        currentStreak: localStreak,
                                        accentCyan: accentCyan,
                                        onDelete: { deletedHabit in
                                            deleteHabit(deletedHabit)
                                        },
                                        onToggleCompletion: {
                                            toggleHabitCompletion(habit)
                                        }
                                    )
                                }
                            }
                        }
                        .padding(.top, 10)
                    }

                    Spacer()
                }
                .padding()
                .onAppear {
                    guard let userId = session.current_user?.uid else {
                        print("No authenticated user found; cannot fetch habits.")
                        return
                    }
                    // 1) Fetch existing habits
                    viewModel.fetchHabits(for: userId)
                    // 2) Setup default habits if needed
                    viewModel.setupDefaultHabitsIfNeeded(for: userId)

                    // Then do daily reset
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        viewModel.dailyResetIfNeeded()
                    }

                    // Update habitsFinishedToday
                    updateHabitsFinishedToday()

                    // Observe changes in habits
                    viewModel.$habits
                        .sink { _ in
                            updateHabitsFinishedToday()
                        }
                        .store(in: &cancellables)
                }

                // Floating + button for adding new habits
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button {
                            showingAddHabit = true
                        } label: {
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
            .sheet(isPresented: $showingAddHabit) {
                AddHabitView(viewModel: viewModel)
                    .environmentObject(session)
                    .environmentObject(viewModel)
            }
            .navigationBarHidden(true)
        }
    }

    // MARK: - Greeting
    private var greetingMessage: String {
        let userName = session.current_user?.email ?? "User"
        return "Welcome back, let’s get started!"
    }

    // MARK: - Update Habits Finished Today
    private func updateHabitsFinishedToday() {
        habitsFinishedToday = viewModel.habits.filter { $0.isCompletedToday }.count
    }

    // MARK: - Toggle Completion
    private func toggleHabitCompletion(_ habit: Habit) {
        viewModel.toggleHabitCompletion(habit, userId: habit.ownerId)
    }

    // MARK: - Delete Habit
    private func deleteHabit(_ habit: Habit) {
        viewModel.deleteHabit(habit)
    }
}

// MARK: - HabitRow
struct HabitRow: View {
    let habit: Habit
    let currentStreak: Int   // This is from localStreaks or habit.currentStreak
    let accentCyan: Color
    let onDelete: (Habit) -> Void
    let onToggleCompletion: () -> Void

    var body: some View {
        HStack {
            // Left side
            VStack(alignment: .leading, spacing: 4) {
                // Title
                Text(habit.title)
                    .font(.headline)
                    .foregroundColor(.white)

                // Description
                Text(habit.description)
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.7))

                // Streak Info
                HStack(spacing: 8) {
                    // The local streak immediately changes, so the UI feels instant
                    Text("Current Streak: \(max(currentStreak, habit.currentStreak))")
                        .font(.caption)
                        .foregroundColor( (currentStreak > 0) ? .green : .white)

                    // Longest Streak
                    Text("Longest Streak: \(habit.longestStreak)")
                        .font(.caption)
                        .foregroundColor(habit.longestStreak > 0 ? .green : .white)

                    // Possibly show badges
                    if habit.weeklyStreakBadge {
                        StreakBadge(text: "7-Day", color: .green)
                    }
                    if habit.monthlyStreakBadge {
                        StreakBadge(text: "30-Day", color: .yellow)
                    }
                    if habit.yearlyStreakBadge {
                        StreakBadge(text: "365-Day", color: .purple)
                    }
                }
            }
            Spacer()

            // Toggle Completion
            Button(action: onToggleCompletion) {
                if habit.isCompletedToday {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.headline)
                        .foregroundColor(.green)
                        .frame(width: 30, height: 30)
                        .background(Color.green.opacity(0.2))
                        .clipShape(Circle())
                } else {
                    Image(systemName: "circle")
                        .font(.headline)
                        .foregroundColor(accentCyan)
                        .frame(width: 30, height: 30)
                        .background(accentCyan.opacity(0.2))
                        .clipShape(Circle())
                }
            }
            .buttonStyle(PlainButtonStyle())

            // Delete Button
            Button {
                onDelete(habit)
            } label: {
                Image(systemName: "trash")
                    .foregroundColor(.red)
            }
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


// MARK: - StreakBadge
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


// MARK: - Preview
struct HabitTrackerView_Previews: PreviewProvider {
    static var previews: some View {
        // Mock dependencies
        let session = SessionStore()
        let mockViewModel = HabitViewModel()

        // Create sample habits
        let sampleHabit1 = Habit(
            id: "1",
            title: "Daily Coding",
            description: "Review Swift concepts",
            startDate: Date(),
            ownerId: "testOwner",
            isCompletedToday: true,
            lastReset: nil,
            points: 100,
            currentStreak: 5,
            longestStreak: 10,
            weeklyStreakBadge: false,
            monthlyStreakBadge: false,
            yearlyStreakBadge: false
        )
        let sampleHabit2 = Habit(
            id: "2",
            title: "Meditation",
            description: "Morning meditation for clarity",
            startDate: Date(),
            ownerId: "testOwner",
            isCompletedToday: false,
            lastReset: nil,
            points: 200,
            currentStreak: 30,
            longestStreak: 30,
            weeklyStreakBadge: true,
            monthlyStreakBadge: true,
            yearlyStreakBadge: false
        )

        mockViewModel.habits = [sampleHabit1, sampleHabit2]

        return NavigationView {
            HabitTrackerView()
                .environmentObject(session)
                .environmentObject(mockViewModel)
        }
        .preferredColorScheme(.dark)
    }
}
