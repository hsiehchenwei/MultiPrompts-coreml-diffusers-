//
//  GeneratedImageView.swift
//  Diffusion
//
//  Created by Pedro Cuenca on 18/1/23.
//  See LICENSE at https://github.com/huggingface/swift-coreml-diffusers/LICENSE
//

import SwiftUI

import ImageIO

struct GeneratedImageView: View {
    @EnvironmentObject var generation: GenerationContext
    
    
    
    func showSavePanel(defaltName:String) -> URL? {
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.png]
        savePanel.canCreateDirectories = true
        savePanel.isExtensionHidden = false
        savePanel.title = "Save your image"
        savePanel.message = "Choose a folder and a name to store the image."
        savePanel.nameFieldLabel = "File name:"
        savePanel.nameFieldStringValue = defaltName.replacingOccurrences(of: " ", with: "_")

        let response = savePanel.runModal()
        return response == .OK ? savePanel.url : nil
    }

    func savePNG(cgImage: CGImage, path: URL) {
        let image = NSImage(cgImage: cgImage, size: .zero)
        let imageRepresentation = NSBitmapImageRep(data: image.tiffRepresentation!)
        guard let pngData = imageRepresentation?.representation(using: .png, properties: [:]) else {
            print("Error generating PNG data")
            return
        }
        do {
            try pngData.write(to: path)
        } catch {
            print("Error saving: \(error)")
        }
    }
    var body: some View {
        switch generation.state {
        case .startup: return AnyView(Image("placeholder").resizable())
        case .running(let progress):
            guard let progress = progress, progress.stepCount > 0 else {
                // The first time it takes a little bit before generation starts
                return AnyView(ProgressView())
            }
            let step = Int(progress.step) + 1
            let fraction = Double(step) / Double(progress.stepCount)
            let label = "Step \(step) of \(progress.stepCount)"
            return AnyView(HStack {
                ProgressView(label, value: fraction, total: 1).padding()
                Button {
                    generation.cancelGeneration()
                } label: {
                    Image(systemName: "x.circle.fill").foregroundColor(.gray)
                }
                .buttonStyle(.plain)
            })
        case .complete(_, _, _, _):
            
            let columns = [
                GridItem(.adaptive(minimum: 150)),
                GridItem(.adaptive(minimum: 200))
            ]
           
            let images = generation.generatedImages
            let infos = generation.generatedImagesInfo
               return AnyView(
                   ScrollView(.vertical) {
                       LazyVGrid(columns: columns, spacing: 16) {
                           ForEach(images.indices, id: \.self) { index in
                               let image = images[index]
                               VStack {
                                   HStack{
                                       let result = "\(index)\(infos[index])"
                                       Text(result)
                                       Button() {
                                           if let url = showSavePanel(defaltName: result) {
                                               savePNG(cgImage: image, path: url)
                                           }
                                       } label: {
                                           Label("Save…", systemImage: "square.and.arrow.down")
                                       }
                                  
                                   }
                                   Image(image, scale: 1, label: Text("generated"))
                                      .resizable()
                                      .aspectRatio(contentMode: .fit)
                                      .clipShape(RoundedRectangle(cornerRadius: 20))
                                      .padding(.vertical, 8)
                                  
                               }
                           }
                       }
                   }
               )
            /*
            guard let theImage = image else {
                return AnyView(Image(systemName: "exclamationmark.triangle").resizable())
            }
                              
            return AnyView(Image(theImage, scale: 1, label: Text("generated"))
                .resizable()
                .clipShape(RoundedRectangle(cornerRadius: 20))
            )*/
        case .failed(_):
            return AnyView(Image(systemName: "exclamationmark.triangle").resizable())
        case .userCanceled:
            return AnyView(Text("Generation canceled"))
        }
    }
}
