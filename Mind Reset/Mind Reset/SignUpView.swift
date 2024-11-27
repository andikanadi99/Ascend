//
//  SignUpView.swift
//  Mind Reset
//
//  Created by Andika Yudhatrisna on 11/22/24.
//

import SwiftUI

struct SignUpView: View {
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
                Text("Sign Up Interface")
                
            }
        }
    }
}
    


struct SignUpView_Previews: PreviewProvider {
    static var previews: some View {
        SignUpView()
            .environmentObject(SessionStore())
    }
}
