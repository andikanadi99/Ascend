//
//  LoginView.swift
//  This View handles the Login UI component of Mind Reset
//  Mind Reset
//
//  Created by Andika Yudhatrisna on 11/21/24.
//

import SwiftUI

struct LoginView: View {
    //State variables to store email and password of user
    @State private var email: String = "";
    @State private var password: String = "";
    //Global Variable to access the SessionStore object. Allows this view to interact with authentication metods and observe state changes.
    @EnvironmentObject var session: SessionStore
    
    var body: some View {
        VStack{
            
        }
    }
}
