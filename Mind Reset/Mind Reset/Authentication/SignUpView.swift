//
//  SignUpView.swift
//  Mind Reset
//  This View handles the Login UI component of Mind Reset
//  Objectives:
//      1.User Registration: Allow users to create a new account using their email and password.
//      2.Handle input validation.
//      3.Error Handling: Display meaningful error messages when registration fails.
//      4.Navigation: Provide a way for users to navigate to the LoginView if they already have an account.
//  Created by Andika Yudhatrisna on 11/22/24.
//

import SwiftUI

struct SignUpView: View {
    //Access the shared instance of SessionStore
    @EnvironmentObject var session: SessionStore
    //Variables for the file
    @State private var email = ""
    @State private var password = ""
    @State private var confirm_password = ""
    @State private var show_password = false
    @State private var show_confirm_password = false
    @State private var isShowingAlert = false
    
    var body: some View {
            ScrollView{
                
                //Main Stack lineup
                VStack(spacing:20){
                    //Title section
                    Text("Create Account")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .padding(.top, 40)
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
                    //Zstack for password field.
                    ZStack(alignment: .trailing){
                        //If-Else, depending on if user wants password to be shown or not
                        if show_password{
                            TextField("Enter Your Password",text:$password)
                                .padding()
                                .background(Color(UIColor.secondarySystemBackground))
                                .cornerRadius(8)
                                .padding(.horizontal)
                                .onChange(of: password, initial: false) { oldValue, newValue in
                                    session.auth_error = nil
                                }
                        }
                        else{
                            SecureField("Enter Your Password",text:$password)
                                .padding()
                                .background(Color(UIColor.secondarySystemBackground))
                                .cornerRadius(8)
                                .padding(.horizontal)
                                .onChange(of: password, initial: false) { oldValue, newValue in
                                    session.auth_error = nil
                                }
                        }
                        //Button to toggle between show and not show
                        Button(action: {
                            show_password.toggle()
                        }){
                            Image(systemName: self.show_password ? "eye.slash.fill" : "eye.fill")
                                .foregroundColor(.gray)
                                .padding(.trailing, 35)
                        }
                    }
                    //Zstack for confirm password field.
                    ZStack(alignment: .trailing){
                        //If-Else, depending on if user wants password to be shown or not
                        if show_confirm_password{
                            TextField("Confirm Your Password",text:$confirm_password)
                                .padding()
                                .background(Color(UIColor.secondarySystemBackground))
                                .cornerRadius(8)
                                .padding(.horizontal)
                                .onChange(of: confirm_password, initial: false) { oldValue, newValue in
                                    session.auth_error = nil
                                }
                        }
                        else{
                            SecureField("Confirm Your Password",text:$confirm_password)
                                .padding()
                                .background(Color(UIColor.secondarySystemBackground))
                                .cornerRadius(8)
                                .padding(.horizontal)
                                .onChange(of: confirm_password, initial: false) { oldValue, newValue in
                                    session.auth_error = nil
                                }
                        }
                        //Button to toggle between show and not show
                        Button(action: {
                            show_confirm_password.toggle()
                        }){
                            Image(systemName: self.show_confirm_password ? "eye.slash.fill" : "eye.fill")
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
                    //Sign Up Button
                    Button(action:{
                        signUp()
                    }){
                        Text("Sign Up")
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.green)
                            .cornerRadius(8)
                    }
                    .padding(.horizontal)
                    
                    //Navigation to LoginView if account already exist
                    NavigationLink("Already have an account? Log In", destination: LoginView())
                        .padding()
                }
                .padding()
                .background(Color(UIColor.systemBackground))
                .onTapGesture {
                    hideSignUpKeyboard()
                }
            }
            .navigationBarHidden(true)
    }
    
    //Functions associated with page
    
    /*
        Purpose: Takes an email and checks if its valoid to register
    */
    func isEmailValid(_email: String) -> Bool{
        let emailRegEx = "(?:[A-Z0-9a-z._%+-]+)@(?:[A-Za-z0-9-]+\\.)+(?:com|org|net|edu|gov|mil|int)"
        let emailPred = NSPredicate(format: "SELF MATCHES %@", emailRegEx)
        return emailPred.evaluate(with: email)
    }
    /*
        Purpose: Takes an email and checks if its valoid to register
    */
    func isPasswordValid(_password: String) -> Bool{
        return password.count >= 6
    }
    /*
        Purpose: Handles user sign up.
    */
    func signUp(){
        //Check if any field is empty
        guard !email.isEmpty, !password.isEmpty , !confirm_password.isEmpty else{
            session.auth_error = "Please fill in all fields."
            return
        }
        //Check if confirm password does not match password
        guard password == confirm_password else{
            session.auth_error = "Passwords do not match."
            return
        }
        //Check if email is valid
        guard isEmailValid(_email:email) else{
            session.auth_error = "Please enter a valid email address."
            return
        }
        //Check if password is valid is valid
        guard isPasswordValid(_password:password) else{
            session.auth_error = "Passwords must be at least 6 characters."
            return
        }
        
        // Call the signUp method from SessionStore
        session.createAccount(email: email, password: password) { success in
            if success {
                isShowingAlert = true
            } else {
                // Handle error (auth_error is already updated in SessionStore)
            }
        }
    }
}


#if canImport(UIKit)
extension View {
    func hideSignUpKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder),
                                        to: nil, from: nil, for: nil)
    }
}
#endif


struct SignUpView_Previews: PreviewProvider {
    static var previews: some View {
        SignUpView()
            .environmentObject(SessionStore())
    }
}
