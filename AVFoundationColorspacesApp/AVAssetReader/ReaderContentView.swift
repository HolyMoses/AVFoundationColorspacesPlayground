//  ReaderContentView.swift
//  AVFoundationColorspacesApp
//
//  Created by Ayal Moses on 03/06/2021.
//

import MetalKit
import SwiftUI

struct ReaderContentView: View {
  @State var readerImageColorspaceName: String
  @State var readerImage: UIImage

  var body: some View {
    HStack {
      VStack {
        Text("Default. Colorspace: " + readerImageColorspaceName)
//        MTKView(frame: .zero, device: MTLCreateSystemDefaultDevice()!)
        Image(uiImage: readerImage).resizable().scaledToFit()
      }
    }
  }
}

//struct ReaderContentView_Previews: PreviewProvider {
//  static var previews: some View {
//    ReaderContentView()
//  }
//}
