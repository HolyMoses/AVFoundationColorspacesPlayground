//
//  SceneDelegate.swift
//  AVFoundationColorspacesApp
//
//  Created by Ayal Moses on 03/06/2021.
//

import AVFoundation
import UIKit
import SwiftUI

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

  var window: UIWindow?

  let sdURL = Bundle.main.url(forResource: "QuickTime_Test_Pattern_SD", withExtension: "mov")!
  let hdURL = Bundle.main.url(forResource: "QuickTime_Test_Pattern_HD", withExtension: "mov")!
  let claraURL = Bundle.main.url(forResource: "Clara_Amnon_Avital.mov", withExtension: "mov")!

  func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {

    let asset = AVAsset(url: sdURL)
    let imageGenerator = AVAssetImageGenerator(asset: asset)

    let defaultImage = try! imageGenerator.copyCGImage(at: .zero, actualTime: nil)
    let defaultImageColorspaceName = (defaultImage.colorSpace?.name ?? "none") as NSString as String
    print(defaultImage.colorSpace as Any)

    let deviceRGBImage = defaultImage.copy(colorSpace: CGColorSpaceCreateDeviceRGB())!
    let sRGBImage = defaultImage.copy(colorSpace: .init(name: CGColorSpace.sRGB)!)!

    let contentView = ContentView(
      defaultImageColorspaceName: defaultImageColorspaceName,
      defaultImage: UIImage(cgImage: defaultImage),
      deviceRGBImage: UIImage(cgImage: deviceRGBImage),
      sRGBImage: UIImage(cgImage: sRGBImage)
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

