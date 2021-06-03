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
import CoreGraphics

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

  var window: UIWindow?

  let sdURL = Bundle.main.url(forResource: "External Resources/QuickTime_Test_Pattern_SD", withExtension: "mov")!
  let hdURL = Bundle.main.url(forResource: "External Resources/QuickTime_Test_Pattern_HD", withExtension: "mov")!
  let claraURL = Bundle.main.url(forResource: "External Resources/Clara_Amnon_Avital", withExtension: "mov")!
  // clara recoded with 709 color properties.
  // Recode command: ffmpeg -i in.mov -color_primaries bt709 -color_trc bt709 -colorspace bt709 out.mov
  let claraRecodedURL = Bundle.main.url(forResource: "External Resources/clara_1080p_with_sound_1_sec_recoded", withExtension: "mov")!

  func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
    //    let contentView = makeImageGeneratorContentView()
    let contentView = makeReaderContentView()


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

  func generateCGImage(_ asset: AVAsset) -> CGImage {
    let imageGenerator = AVAssetImageGenerator(asset: asset)
    let image = try! imageGenerator.copyCGImage(at: .zero, actualTime: nil)
      .copy(colorSpace: .init(name: CGColorSpace.sRGB)!)!
    return image
  }

//  func makeReaderContentView2() -> ReaderContentView {
//    let asset = AVAsset(url: claraURL)
//    let assetReader = try! AVAssetReader(asset: asset)
//    let track = asset.tracks(withMediaType: .video).first!
//    let videoColorProperties = [AVVideoColorPrimariesKey: AVVideoColorPrimaries_ITU_R_709_2,
//                                AVVideoTransferFunctionKey: AVVideoTransferFunction_ITU_R_709_2,
//                                AVVideoYCbCrMatrixKey: AVVideoYCbCrMatrix_ITU_R_709_2
//                                //                                    AVVideoYCbCrMatrixKey: AVVideoYCbCrMatrix_ITU_R_601_4
//    ]
//    let outputSettings: [String: Any] = [
//      kCVPixelBufferPixelFormatTypeKey as String:
//        [
//          kCVPixelFormatType_32BGRA as NSValue,
//          //              kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange as NSValue,
//          //              kCVPixelFormatType_420YpCbCr8BiPlanarFullRange as NSValue
//        ],
//      kCVPixelBufferIOSurfacePropertiesKey as String: [:],
//      AVVideoColorPropertiesKey: videoColorProperties
//    ]
//    let trackOutput = AVAssetReaderTrackOutput(track: track, outputSettings: outputSettings)
//    assetReader.add(trackOutput)
//    assetReader.timeRange = .init(start: .zero, duration: asset.duration)
//    assetReader.startReading()
//
//    let sampleBuffer = trackOutput.copyNextSampleBuffer()!
//    let presentationTime = CMSampleBufferGetOutputPresentationTimeStamp(sampleBuffer)
//    let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)!
//
//    //CVImageBuffer
//
//  }

  func makeReaderContentView() -> ReaderContentView {
    let asset = AVAsset(url: claraURL)

    let assetReader = AssetFramesReader(asset: asset, selectTracks: { tracks in
      return (tracks, tracks.first!.timeRange)
    })
    let pixelBuffer = assetReader.readNextFrames()!.first!.value.buffer
    //    let lock = NSLock()
    //    var pixelBuffer1: CVPixelBuffer?
    //    DispatchQueue.main.async {
    //      lock.lock()
    //      pixelBuffer1 = assetReader.readNextFrames()!.first!.value.buffer
    //      lock.unlock()
    //    }
    //    lock.lock()
    //    while !assetReader.readingFinished {
    //      lock.unlock()
    //      Thread.sleep(forTimeInterval: 1)
    //      print("waiting")
    //    }
    //    lock.unlock()


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
//    let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(
//      pixelFormat: texturePixelFormat.format,
//      width: textureWidth, height: textureHeight, mipmapped: false
//    )
//    textureDescriptor.usage = .shaderRead
//
//    let device = MTLCreateSystemDefaultDevice()!
////    let commandQueue = device.makeCommandQueue()
//    let mtlTexture = device.makeTexture(descriptor: textureDescriptor)!
//
//    let ciImage = CIImage(mtlTexture: mtlTexture, options: nil)!
//    let correctedCIImage = ciImage.transformed(by: ciImage.orientationTransform(for: .downMirrored), highQualityDownsample: true)
//    let cgImage = CIContext(mtlDevice: device, options: [CIContextOption.outputColorSpace : CGColorSpace(name: CGColorSpace.sRGB)!])
//      .createCGImage(correctedCIImage, from: correctedCIImage.extent)!
//    let readerImage = UIImage(cgImage: cgImage)
//    print(mtlTexture)
//    print("\n", ciImage)
//    print("\n", readerImage)
    //    let readerImageColorspaceName = (mtlTexture. ?? "none") as NSString as String


    // 2
    let imageBuffer = pixelBuffer
    CVPixelBufferLockBaseAddress(imageBuffer, CVPixelBufferLockFlags.init(rawValue: 0))

    let baseAddress = CVPixelBufferGetBaseAddress(imageBuffer) // (uint8_t *)
    let bytesPerRow = CVPixelBufferGetBytesPerRow(imageBuffer)
    let width = CVPixelBufferGetWidth(imageBuffer)
    let height = CVPixelBufferGetHeight(imageBuffer)
//    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
    let newContext = CGContext(data: baseAddress, width: width, height: height, bitsPerComponent: 8,
                               bytesPerRow: bytesPerRow, space: colorSpace,
                               bitmapInfo: CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.premultipliedFirst.rawValue)!
    let newImage = newContext.makeImage()!
    let readerImage = UIImage(cgImage: newImage)

    CVPixelBufferUnlockBaseAddress(imageBuffer, CVPixelBufferLockFlags(rawValue: 0))

    let contentView = ReaderContentView(readerImageColorspaceName: "aa",
                                        readerImage: readerImage,
                                        generatedAssetImage: UIImage(cgImage: generateCGImage(asset)))
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

// https://developer.apple.com/documentation/avfoundation/media_assets_and_metadata/sample-level_reading_and_writing/tagging_media_with_video_color_information?language=objc
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
