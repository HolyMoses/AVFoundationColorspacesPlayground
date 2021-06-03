//
//  ContentView.swift
//  AVFoundationColorspacesApp
//
//  Created by Ayal Moses on 03/06/2021.
//

import SwiftUI

struct ContentView: View {
  @State var defaultImage: UIImage
  @State var deviceRGBImage: UIImage
  @State var sRGBImage: UIImage
  
  var body: some View {
    Text("Default")
    Image(uiImage: defaultImage)
      .resizable()
      .scaledToFit()
    Spacer()
    
    Text("DeviceRGB")
    Image(uiImage: deviceRGBImage)
      .resizable()
      .scaledToFit()
    Spacer()
    
    Text("sRGB")
    Image(uiImage: sRGBImage)
      .resizable()
      .scaledToFit()
  }
}

//struct ContentView_Previews: PreviewProvider {
//  static var previews: some View {
//    ContentView()
//  }
//}
