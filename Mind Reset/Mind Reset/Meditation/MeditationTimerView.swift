//
//  MeditationTimerView.swift
//  Mind Reset
//  Objective: Serves as the main user interface for the meditation timer feature of the app.
//  Created by Andika Yudhatrisna on 12/24/24.
//

import SwiftUI
import FirebaseAuth

struct MeditationTimerView: View {
    //Session Store instance
    @EnvironmentObject var session: SessionStore
    
    //Meditation Variables
    @State private var elapsedSeconds: Int = 0
    @State private var timer: Timer?
    @State private var isRunning: Bool = false
    
    var body : some View {
        VStack(spacing: 20) {
            Text(formattedTime(elapsedSeconds))
                    .font(.system(size: 64))
                    .padding()

                HStack {
                    Button(action: startTimer) {
                        Text("Start")
                            .foregroundColor(.white)
                            .padding()
                            .background(isRunning ? Color.gray : Color.green)
                            .cornerRadius(8)
                    }
                    .disabled(isRunning)

                    Button(action: pauseTimer) {
                        Text("Pause")
                            .foregroundColor(.white)
                            .padding()
                            .background(isRunning ? Color.orange : Color.gray)
                            .cornerRadius(8)
                    }
                    .disabled(!isRunning)

                    Button(action: finishSession) {
                        Text("Finish")
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.red)
                            .cornerRadius(8)
                    }
                }
            }
            .padding()
            .navigationTitle("Meditation Timer")
        }
    //Functions
    /*
        Purpose: Starts the timer, sets it to increment by 1 second
    */
    private func startTimer() {
            isRunning = true
            timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
                self.elapsedSeconds += 1
            }
        }
    /*
        Purpose: Pauses timer, does not reset time
    */
    private func pauseTimer() {
        isRunning = false
        timer?.invalidate()
        timer = nil
    }
    /*
        Purpose: Finishes Meditation time
    */
    private func finishSession() {
            // If the user never started, there's nothing to record
            guard elapsedSeconds > 0 else {
                resetTimer()
                return
            }

            pauseTimer()
            
            // Convert total session from seconds -> minutes
            let sessionMinutes = elapsedSeconds / 60
            // If we want more granular data, use seconds or partial minutes

            // Award these minutes in Firestore
            if let userId = session.current_user?.uid {
                session.awardMeditationTime(userId: userId, additionalMinutes: sessionMinutes)
            } else {
                print("No authenticated user, cannot save meditation data.")
            }

            // Reset for next session
            resetTimer()
        }
    /*
        Purpose: Resets timer
    */
    private func resetTimer() {
            pauseTimer()
            elapsedSeconds = 0
        }
    // Helper to format seconds as MM:SS
        private func formattedTime(_ seconds: Int) -> String {
            let mins = seconds / 60
            let secs = seconds % 60
            return String(format: "%02d:%02d", mins, secs)
        }
    }



//Preview
struct MeditationTimerView_Previews: PreviewProvider {
    static var previews: some View {
        MeditationTimerView()
            .environmentObject(SessionStore())
    }
}


