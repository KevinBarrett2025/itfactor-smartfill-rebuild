//
//  STSWatchApp.swift
//  STSWatch Watch App
//
//  Created by Kevin Barrett on 11/22/25.
//

import SwiftUI

@main
struct STSWatchApp: App {
    var body: some Scene {
        WindowGroup {
            if #available(watchOS 10.0, *) {
                RemoteView()
            } else {
                ContentView()
            }
        }
    }
}
