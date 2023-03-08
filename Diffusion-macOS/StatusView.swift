//
//  StatusView.swift
//  Diffusion-macOS
//
//  Created by Cyril Zakka on 1/12/23.
//  See LICENSE at https://github.com/huggingface/swift-coreml-diffusers/LICENSE
//

import SwiftUI

struct StatusView: View {
    @EnvironmentObject var generation: GenerationContext
    var pipelineState: Binding<PipelineState>
    
    @State private var showErrorPopover = false
    var isInLoop=false
    func submit() {
        if case .running = generation.state { return }
        if generation.isSubmtBTNBusy {return}
        generation.isSubmtBTNBusy=true
        Task {
            generation.state = .running(nil)
           for _ in 1...generation.ImageCount{
               for promptText in generation.positivePrompts{
                    do {
                        generation.positivePrompt=promptText
                        let result = try await generation.generate()
                        if result.userCanceled {
                            generation.state = .userCanceled
                        } else {
                            generation.state = .complete(generation.positivePrompt, result.image, result.lastSeed, result.interval)
                            if let theImage = result.image {
                                generation.generatedImages.insert(theImage, at: 0)
                                generation.generatedImagesInfo.insert(promptText, at: 0)
                            }
                        }
                    } catch {
                        generation.state = .failed(error)
                    }
                    if case .userCanceled = generation.state  {
                        generation.isSubmtBTNBusy=false
                        return
                        
                    }
                    try await Task.sleep(nanoseconds: 1_000_000_000) // 程式暫停 1 秒
                }
            }
        }
        generation.isSubmtBTNBusy=false
    }

    func errorWithDetails(_ message: String, error: Error) -> any View {
        HStack {
            Text(message)
            Spacer()
            Button {
                showErrorPopover.toggle()
            } label: {
                Image(systemName: "info.circle")
            }.buttonStyle(.plain)
            .popover(isPresented: $showErrorPopover) {
                VStack {
                    Text(verbatim: "\(error)")
                    .lineLimit(nil)
                    .padding(.all, 5)
                    Button {
                        showErrorPopover.toggle()
                    } label: {
                        Text("Dismiss").frame(maxWidth: 200)
                    }
                    .padding(.bottom)
                }
                .frame(minWidth: 400, idealWidth: 400, maxWidth: 400)
                .fixedSize()
            }
        }
    }

    func generationStatusView() -> any View {
        switch generation.state {
        case .startup: return EmptyView()
        case .running(let progress):
            guard let progress = progress, progress.stepCount > 0 else {
                // The first time it takes a little bit before generation starts
                return HStack {
                    Text("Preparing model…")
                    Spacer()
                }
            }
            let step = Int(progress.step) + 1
            let fraction = Double(step) / Double(progress.stepCount)
            return HStack {
                Text("Generating \(Int(round(100*fraction)))%")
                Spacer()
            }
        case .complete(_, let image, let lastSeed, let interval):
            guard let _ = image else {
                return HStack {
                    Text("Safety checker triggered, please try a different prompt or seed.")
                    Spacer()
                }
            }
                              
            return HStack {
                let intervalString = String(format: "Time: %.1fs", interval ?? 0)
                Text(intervalString)
                Spacer()
                if generation.seed != Double(lastSeed) {
                    Text("Seed: \(lastSeed)")
                    Button("Set") {
                        generation.seed = Double(lastSeed)
                    }
                }
            }.frame(maxHeight: 25)
        case .failed(let error):
            return errorWithDetails("Generation error", error: error)
        case .userCanceled:
            return HStack {
                Text("Generation canceled.")
                Spacer()
            }
        }
    }
    
    var body: some View {
        switch pipelineState.wrappedValue {
        case .downloading(let progress):
            ProgressView("Downloading…", value: progress*100, total: 110).padding()
        case .uncompressing:
            ProgressView("Uncompressing…", value: 100, total: 110).padding()
        case .loading:
            ProgressView("Loading…", value: 105, total: 110).padding()
        case .ready:
            VStack {
                Button {
                    submit()
                } label: {
                    Text("Generate")
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                }
                .buttonStyle(.borderedProminent)
                
                AnyView(generationStatusView())
            }
        case .failed(let error):
            AnyView(errorWithDetails("Pipeline loading error", error: error))
        }
    }
}

struct StatusView_Previews: PreviewProvider {
    static var previews: some View {
        StatusView(pipelineState: .constant(.downloading(0.2)))
    }
}
