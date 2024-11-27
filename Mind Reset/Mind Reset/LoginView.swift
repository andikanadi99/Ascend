//
//  LoginView.swift
//  This View handles the Login UI component of Mind Reset
//  Objectives: View that allow user to:
//      1.Enter their email and password.
//      2.Handle input validation.
//      3.Authenticate using the SessionStore class.
//      4.Display error messages when login fails.
//      5.Navigate to the SignUpView if the user doesn't have an account.
//
//  Created by Andika Yudhatrisna on 11/21/24.
//

import SwiftUI

struct LoginView: View {
    //Access the shared instance of SessionStore
    @EnvironmentObject var session: SessionStore
    //Declaring email and password variables
    @State private var email = ""
    @State private var password = ""
    @State private var showPassword = false
    //Body of Login View
    var body: some View {
            //Main Stack lineup
            VStack(spacing:20){
                //Welcome message
                Text("Welcome Back")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                //Email Field
                TextField("Enter Your Email",text:$email)
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
                    .padding()
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(8)
                    .padding(.horizontal)
                    .onChange(of: email, initial: false) { oldValue, newValue in
                        session.auth_error = nil
                    }
                // Password Field
                ZStack(alignment: .trailing){
                    if showPassword {
                        TextField("Enter Your Password", text: $password)
                            .padding()
                            .background(Color(UIColor.secondarySystemBackground))
                            .cornerRadius(8)
                            .padding(.horizontal)
                            .onChange(of: password, initial: false) { oldValue, newValue in
                                session.auth_error = nil
                            }
                    }
                    else {
                        SecureField("Enter Your Password", text: $password)
                            .padding()
                            .background(Color(UIColor.secondarySystemBackground))
                            .cornerRadius(8)
                            .padding(.horizontal)
                            .onChange(of: password, initial: false) { oldValue, newValue in
                                session.auth_error = nil
                            }
                    }
                    // Button to toggle password visibility
                    Button(action: {
                        showPassword.toggle()
                    }){
                        Image(systemName: self.showPassword ? "eye.slash.fill" : "eye.fill")
                            .foregroundColor(.gray)
                            .padding(.trailing, 35)
                    }
                }
                //Error message conditional pop-up
                if let error_message = session.auth_error{
                    Text(error_message)
                        .foregroundColor(.red)
                        .padding(.horizontal)
                }
                
                //Login Button
                Button(action: {
                    login()
                }){
                    Text("Login")
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(8)
                }
                .padding(.horizontal)
                
                //Re-direction to create an account
                NavigationLink("Don't have an account? Please sign up",destination: SignUpView())
                    .padding()
            }
            .padding()
            .background(Color(UIColor.systemBackground))
            .onTapGesture{
                hideLoginKeyboard()
            }
            .navigationBarHidden(true)
    }
    
    /*
        Purpose: Takes an email and checks if its valoid to register
    */
    func isEmailValid(_email: String) -> Bool{
        let emailRegEx = "(?:[A-Z0-9a-z._%+-]+)@(?:[A-Za-z0-9-]+\\.)+[A-Za-z]{2,64}"
        let emailPred = NSPredicate(format:"SELF MATCHES %@", emailRegEx)
        return emailPred.evaluate(with: email)
    }
    
    /*
        Purpose: Check if credentials inputed by user is valid and sign users in using the SessionStore class
    */
    func login(){
        //Check if email or password field is empty
        guard !email.isEmpty, !password.isEmpty else {
            session.auth_error = "Please enter both email and password."
            return
        }
        guard isEmailValid(_email: email) else{
            session.auth_error = "Please enter a valid email address."
            return
        }
        
        //Call the sign-in method from SessionStore class
        session.signIn(email:email,password:password)
    }
    
    
}

/*
    If Conditional to hide the keyboard if UIKit is present
*/
#if canImport(UIKit)
extension View {
    func hideLoginKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}
#endif

struct LoginView_Previews: PreviewProvider {
    static var previews: some View {
        LoginView()
            .environmentObject(SessionStore())
    }
}
