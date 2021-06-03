//
//  SceneDelegate.swift
//  AVFoundationColorspacesApp
//
//  Created by Ayal Moses on 03/06/2021.
//

import Metal
import MetalKit
import AVFoundation
import UIKit
import SwiftUI
import RxSwift

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

  var window: UIWindow?

  let sdURL = Bundle.main.url(forResource: "External Resources/QuickTime_Test_Pattern_SD", withExtension: "mov")!
  let hdURL = Bundle.main.url(forResource: "External Resources/QuickTime_Test_Pattern_HD", withExtension: "mov")!
  let claraURL = Bundle.main.url(forResource: "External Resources/Clara_Amnon_Avital", withExtension: "mov")!
  // clara recoded with 709 color properties.
  // Recode command: ffmpeg -i in.mov -color_primaries bt709 -color_trc bt709 -colorspace bt709 out.mov
  let claraRecodedURL = Bundle.main.url(forResource: "External Resources/clara_1080p_with_sound_1_sec_recoded", withExtension: "mov")!

  func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
    let contentView = makeImageGeneratorContentView()
    //    let contentView = makeReaderContentView()


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

  func makeReaderContentView() -> ReaderContentView {
    let asset = AVAsset(url: sdURL)

    let assetReader = AssetFramesReader(asset: asset, selectTracks: { tracks in
      return (tracks, tracks.first!.timeRange)
    })
    let lock = NSLock()
    var pixelBuffer1: CVPixelBuffer?
    DispatchQueue.main.async {
      lock.lock()
      pixelBuffer1 = assetReader.readNextFrames()!.first!.value.buffer
      lock.unlock()
    }
    lock.lock()
    while !assetReader.readingFinished {
      lock.unlock()
      Thread.sleep(forTimeInterval: 1)
      print("waiting")
    }
    lock.unlock()


    let pixelBuffer = pixelBuffer1!
    let ioSurface = CVPixelBufferGetIOSurface(pixelBuffer)
    let cvPixelFormat = CVPixelBufferGetPixelFormatType(pixelBuffer);
    let kMTBCVPixelFormatToMTLPixelFormatMap = [
      (cvFormat: kCVPixelFormatType_OneComponent8, plane: 0, format: MTLPixelFormat.r8Unorm),
      (cvFormat: kCVPixelFormatType_TwoComponent8, plane: 0, format: MTLPixelFormat.rg8Unorm),
      (cvFormat: kCVPixelFormatType_32BGRA, plane: 0, format: MTLPixelFormat.bgra8Unorm),
      (cvFormat: kCVPixelFormatType_OneComponent16Half, plane: 0, format: MTLPixelFormat.r16Float),
      (cvFormat: kCVPixelFormatType_TwoComponent16Half, plane: 0, format: MTLPixelFormat.rg16Float),
      (cvFormat: kCVPixelFormatType_64RGBAHalf, plane: 0, format: MTLPixelFormat.rgba16Float),
      (cvFormat: kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange, plane: 0, format: MTLPixelFormat.r8Unorm),
      (cvFormat: kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange, plane: 1, format: MTLPixelFormat.rg8Unorm),
      (cvFormat: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange, plane: 0, format: MTLPixelFormat.r8Unorm),
      (cvFormat: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange, plane: 1, format: MTLPixelFormat.rg8Unorm),
      (cvFormat: kCVPixelFormatType_420YpCbCr10BiPlanarVideoRange, plane: 0, format: MTLPixelFormat.r16Unorm),
      (cvFormat: kCVPixelFormatType_420YpCbCr10BiPlanarVideoRange, plane: 1, format: MTLPixelFormat.rg16Unorm),
      (cvFormat: kCVPixelFormatType_420YpCbCr10BiPlanarFullRange, plane: 0, format: MTLPixelFormat.r16Unorm),
      (cvFormat: kCVPixelFormatType_420YpCbCr10BiPlanarFullRange, plane: 1, format: MTLPixelFormat.rg16Unorm)
    ]
    let texturePixelFormat = kMTBCVPixelFormatToMTLPixelFormatMap.first { $0.cvFormat == cvPixelFormat }!
    let textureWidth = CVPixelBufferGetWidthOfPlane(pixelBuffer, texturePixelFormat.plane);
    let textureHeight = CVPixelBufferGetHeightOfPlane(pixelBuffer, texturePixelFormat.plane);
    let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(
      pixelFormat: texturePixelFormat.format,
      width: textureWidth, height: textureHeight, mipmapped: false
    )
    textureDescriptor.usage = .shaderRead

    let device = MTLCreateSystemDefaultDevice()!
//    let commandQueue = device.makeCommandQueue()
    let mtlTexture = device.makeTexture(descriptor: textureDescriptor,
                                        iosurface: ioSurface!.takeRetainedValue(),
                                        plane: texturePixelFormat.plane)!
    let ciImage = CIImage(mtlTexture: mtlTexture, options: nil)!
    let readerImage = UIImage(ciImage: ciImage)
    print(mtlTexture)
    print("\n", ciImage)
    print("\n", readerImage)
    //    let readerImageColorspaceName = (mtlTexture. ?? "none") as NSString as String

    let contentView = ReaderContentView(readerImageColorspaceName: "aa",
                                        readerImage: readerImage)
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

// Recode command: ffmpeg -i in.mov -color_primaries bt709 -color_trc bt709 -colorspace bt709 out.mov
// mediainfo asset.mov

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
