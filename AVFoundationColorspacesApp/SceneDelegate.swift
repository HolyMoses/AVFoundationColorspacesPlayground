//
//  SceneDelegate.swift
//  AVFoundationColorspacesApp
//
//  Created by Ayal Moses on 03/06/2021.
//

import UIKit
import SwiftUI

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

  var window: UIWindow?


  func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {



    let uiImage = UIImage(named: "asaph_netai.jpg")!

    let contentView = ContentView(
      defaultImage: uiImage,
      deviceRGBImage: uiImage,
      sRGBImage: uiImage
    )

    // Use a UIHostingController as window root view controller.
    if let windowScene = scene as? UIWindowScene {
        let window = UIWindow(windowScene: windowScene)
        window.rootViewController = UIHostingController(rootView: contentView)
        self.window = window
        window.makeKeyAndVisible()
    }
  }
}

