//
//  HabitTrackerView.swift
//  Mind Reset
//  Objective: Serves as the main user interface for the habit-tracking feature of the app. It displays a list of habits, allows users to add new habits, mark habits as completed, and delete habits.
//  Created by Andika Yudhatrisna on 12/1/24.
//

import SwiftUI
import FirebaseAuth

@available(iOS 16.0, *)
struct HabitTrackerView: View {
    // MARK: - State & Environment
    @StateObject private var viewModel = HabitViewModel()
    @EnvironmentObject var session: SessionStore
    
    @State private var showingAddHabit = false
    
    // Dark theme & accent
    let backgroundBlack = Color.black
    let accentCyan      = Color(red: 0, green: 1, blue: 1) // #00FFFF

    // Placeholder daily quote
    let dailyQuote = "Focus on what matters today."
    
    // Example placeholders for intensity & total sessions
    @State private var intensityScore: Int = 0
    @State private var totalSessions: Int = 0

    var body: some View {
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

                // Single line for intensity & total sessions (above the list)
                HStack {
                    Text("Intensity Score: \(intensityScore)")
                        .foregroundColor(.white)
                    Spacer()
                    Text("Total Sessions: \(totalSessions)")
                        .foregroundColor(.white)
                }
                .padding(.vertical, 10)
                
                // Habit List
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(viewModel.habits) { habit in
                            HabitRow(
                                habit: habit,
                                accentCyan: accentCyan,
                                onTap: { tappedHabit in
                                    navigateToHabit(tappedHabit)
                                },
                                onToggle: { toggledHabit in
                                    toggleHabitCompletion(toggledHabit)
                                },
                                onDelete: { deletedHabit in
                                    deleteHabit(deletedHabit)
                                }
                            )
                        }
                    }
                    .padding(.top, 10)
                }
                
                Spacer()
            }
            .padding()
            // **Important**: Check user doc for defaultHabitsCreated & fetch existing
            .onAppear {
                guard let userId = session.current_user?.uid else {
                    print("No authenticated user found.")
                    return
                }
                // 1) Fetch existing habits
                viewModel.fetchHabits(for: userId)
                // 2) Setup default habits if needed (only once)
                viewModel.setupDefaultHabitsIfNeeded(for: userId)
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
                            .frame(width: 50, height: 50)
                            .foregroundColor(.black)
                            .background(accentCyan)
                            .clipShape(Circle())
                    }
                    .padding()
                }
            }
        }
        .sheet(isPresented: $showingAddHabit) {
            AddHabitView(viewModel: viewModel)
                .environmentObject(session)
        }
        .navigationBarHidden(true)
    }

    // MARK: - Greeting
    private var greetingMessage: String {
        let userName = session.current_user?.email ?? "User"
        return "Welcome back, let’s get started!"
    }
    
    // MARK: - Toggle Completion
    private func toggleHabitCompletion(_ habit: Habit) {
        guard let userId = session.current_user?.uid else { return }
        
        var updatedHabit = habit
        if updatedHabit.isCompletedToday {
            updatedHabit.isCompletedToday = false
        } else {
            updatedHabit.isCompletedToday = true
            updatedHabit.streak += 1
            // Optionally award points
            viewModel.awardPointsToUser(userId: userId, points: 10)
        }
        viewModel.updateHabit(updatedHabit)
    }
    
    // MARK: - Delete Habit
    private func deleteHabit(_ habit: Habit) {
        viewModel.deleteHabit(habit)
    }
    
    // MARK: - Navigate to Habit Page
    private func navigateToHabit(_ habit: Habit) {
        // Placeholder logic for a dedicated habit detail page
        print("Navigating to detail for habit:", habit.title)
    }
}

// MARK: - HabitRow
struct HabitRow: View {
    let habit: Habit
    let accentCyan: Color
    let onTap: (Habit) -> Void
    let onToggle: (Habit) -> Void
    let onDelete: (Habit) -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(habit.title)
                    .font(.headline)
                    .foregroundColor(.white)
                Text(habit.description)
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.7))
            }
            Spacer()
            
            // Toggling a habit => arrow or checkmark, both in accentCyan
            Button {
                onToggle(habit)
            } label: {
                if habit.isCompletedToday {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(accentCyan)
                } else {
                    Image(systemName: "chevron.right")
                        .foregroundColor(accentCyan)
                }
            }
            
            // Trash icon to delete
            Button {
                onDelete(habit)
            } label: {
                Image(systemName: "trash")
                    .foregroundColor(.red)
            }
            .padding(.leading, 8)
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
        .onTapGesture {
            onTap(habit)
        }
    }
}


// MARK: - Preview
struct HabitTrackerView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            HabitTrackerView()
                .environmentObject(SessionStore())
        }
    }
}
