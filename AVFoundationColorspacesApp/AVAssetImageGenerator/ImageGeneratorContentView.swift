//
//  ContentView.swift
//  AVFoundationColorspacesApp
//
//  Created by Ayal Moses on 03/06/2021.
//

import SwiftUI

struct ImageGeneratorContentView: View {
  @State var title1: String
  @State var image1: UIImage
  @State var title2: String
  @State var image2: UIImage
  @State var title3: String
  @State var image3: UIImage

  var body: some View {
    HStack {
      VStack{
        Text(title1)
        Image(uiImage: image1).resizable().scaledToFit()
      }

      VStack{
        Text(title2)
        Image(uiImage: image2).resizable().scaledToFit()
      }

      VStack{
        Text(title3)
        Image(uiImage: image3).resizable().scaledToFit()
      }
    }
  }
}
