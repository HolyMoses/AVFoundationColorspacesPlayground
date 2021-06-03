//
//  SceneDelegate.swift
//  AVFoundationColorspacesApp
//
//  Created by Ayal Moses on 03/06/2021.
//

import AVFoundation
import UIKit
import SwiftUI
import RxSwift

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

  var window: UIWindow?

  let sdURL = Bundle.main.url(forResource: "QuickTime_Test_Pattern_SD", withExtension: "mov")!
  let hdURL = Bundle.main.url(forResource: "QuickTime_Test_Pattern_HD", withExtension: "mov")!
  let claraURL = Bundle.main.url(forResource: "Clara_Amnon_Avital", withExtension: "mov")!

  // clara recoded with 709 color properties.
  // TODO: command
  let claraRecodedURL = Bundle.main.url(forResource: "clara_1080p_with_sound_1_sec_recoded", withExtension: "mov")!

  func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
    let contentView = makeImageGeneratorContentView()

    // Use a UIHostingController as window root view controller.
    if let windowScene = scene as? UIWindowScene {
        let window = UIWindow(windowScene: windowScene)
        window.rootViewController = UIHostingController(rootView: contentView)
        self.window = window
        window.makeKeyAndVisible()
    }
  }

  func makeImageGeneratorContentView() -> ImageGeneratorContentView {
    let asset = AVAsset(url: claraRecodedURL)

    let imageGenerator = AVAssetImageGenerator(asset: asset)

    //    let videoComposition = AVMutableVideoComposition(propertiesOf: imageGenerator.asset)
    //    videoComposition.colorPrimaries = AVVideoColorPrimaries_ITU_R_709_2
    //    videoComposition.colorTransferFunction = AVVideoTransferFunction_ITU_R_709_2
    //    videoComposition.colorYCbCrMatrix = AVVideoYCbCrMatrix_ITU_R_709_2
    //    imageGenerator.videoComposition = videoComposition

    let defaultImage = try! imageGenerator.copyCGImage(at: .zero, actualTime: nil)
    let defaultImageColorspaceName = (defaultImage.colorSpace?.name ?? "none") as NSString as String
    print(defaultImage.colorSpace as Any)

    let deviceRGBImage = defaultImage.copy(colorSpace: CGColorSpaceCreateDeviceRGB())!
    let sRGBImage = defaultImage.copy(colorSpace: .init(name: CGColorSpace.sRGB)!)!

    let contentView = ImageGeneratorContentView(
      defaultImageColorspaceName: defaultImageColorspaceName,
      defaultImage: UIImage(cgImage: defaultImage),
      deviceRGBImage: UIImage(cgImage: deviceRGBImage),
      sRGBImage: UIImage(cgImage: sRGBImage)
    )
    return contentView
  }
}

// TODO: take clara, add profile, see if it fixes VVV Yes
// take HD/sd, remove profile, see if it breaks
// TODO - reader A/A 13/14,
// reader -> writer -> reader
// ftv export?

// exported assets are tagged
// preprocessed assets are not tagged


//asset.tracks(withMediaType: .video).forEach { assetTracks in
//
//    let formatDescriptions =
//        assetTracks.formatDescriptions as! [CMFormatDescription]
//    for (_, formatDesc) in formatDescriptions.enumerated() {
//
//        guard let colorPrimaries =
//            CMFormatDescriptionGetExtension(formatDesc, extensionKey: kCMFormatDescriptionExtension_ColorPrimaries) else {
//                return
//        }
//
//        if CFGetTypeID(colorPrimaries) == CFStringGetTypeID() {
//
//            let result =
//                CFStringCompareWithOptions((colorPrimaries as! CFString),
//                    kCMFormatDescriptionColorPrimaries_ITU_R_709_2,
//                    CFRangeMake(0, CFStringGetLength((colorPrimaries as! CFString))),
//                    CFStringCompareFlags.compareCaseInsensitive)
//            // Is the color primary Rec. 709?
//            if result == CFComparisonResult.compareEqualTo {
//                // Your code here to process Rec. 709.
//            }
//        }
//    }
//}
//
