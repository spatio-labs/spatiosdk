//
//  SpatioApp.swift
//  SpatioApp
//
//  Created by Matthew Park on 4/6/25.
//

import SwiftUI

/// The core protocol defining a Spatio application, usable by both embedded and external plugins.
public protocol SpatioApp: AnyObject, Identifiable { // Add Identifiable
    /// Default initializer required for dynamic instantiation of external plugins.
    /// Embedded apps might use a different, potentially parameterized, initializer.
    init()

    /// A unique identifier string for the app (e.g., "chat", "com.mycompany.myplugin").
    /// This **must** be unique across all built-in and external apps.
    /// Conforms to Identifiable.
    var id: String { get }

    /// The user-visible name of the app.
    var name: String { get }

    /// The name of the SF Symbol or asset to use for the app's icon.
    var iconName: String { get }

    /// Creates the main SwiftUI view for the app.
    /// This replaces the need for a separate `viewType` enum for routing external apps.
    /// - Returns: An AnyView containing the app's UI.
    func makeView() -> AnyView

    // --- Optional but recommended for consistency ---
    // var version: String { get } // Good practice for plugins
    // var author: String { get } // Good practice for plugins
}
