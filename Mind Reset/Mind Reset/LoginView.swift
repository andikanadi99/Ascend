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
    //Body of Login View
    var body: some View {
        //Navigation View to alternate between login and signup view
        NavigationView {
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
                //Password Field
                SecureField("Enter Your Password",text:$password)
                    .autocapitalization(.none)
                    .padding()
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(8)
                    .padding(.horizontal)
                    .onChange(of: password, initial: false) { oldValue, newValue in
                        session.auth_error = nil
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
                hideKeyboard()
            }
            .navigationBarHidden(true)
        }
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
        
        //Call the sign-in method from SessionStore class
        session.signIn(email:email,password:password)
    }
    
    
}

/*
    If Conditional to hide the keyboard if UIKit is present
*/
#if canImport(UIKit)
extension View {
    func hideKeyboard() {
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
