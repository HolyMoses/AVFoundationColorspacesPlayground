//
//  ContentView.swift
//  AVFoundationColorspacesApp
//
//  Created by Ayal Moses on 03/06/2021.
//

import SwiftUI

struct ContentView: View {
  @State var defaultImageColorspaceName: String
  @State var defaultImage: UIImage
  @State var deviceRGBImage: UIImage
  @State var sRGBImage: UIImage

  var body: some View {
    HStack {
      VStack{
        Text("Default. Colorspace: " + defaultImageColorspaceName)
        Image(uiImage: defaultImage).resizable().scaledToFit()
      }

      VStack{
        Text("DeviceRGB")
        Image(uiImage: deviceRGBImage).resizable().scaledToFit()
      }

      VStack{
        Text("sRGB")
        Image(uiImage: sRGBImage).resizable().scaledToFit()
      }
    }
  }
}

//struct ContentView_Previews: PreviewProvider {
//  static var previews: some View {
//    ContentView()
//  }
//}
