import AppKit

/// Compare deux PNG pixel par pixel : `visual-diff ref.png actual.png diff.png [seuil %]`.
/// Un pixel compte comme différent si un canal s'écarte de plus de 24/255 (anti-crénelage toléré).
/// Code de sortie : 0 conforme, 1 différent, 2 images de tailles différentes ou illisibles.
/// L'image `diff.png` montre l'actuel estompé avec les pixels différents en rouge.

struct Pixels {
    let width: Int
    let height: Int
    var bytes: [UInt8]   // RGBA, 8 bits, sRGB, ligne par ligne

    init?(path: String) {
        guard let data = FileManager.default.contents(atPath: path), let image = NSBitmapImageRep(data: data)?.cgImage,
              let space = CGColorSpace(name: CGColorSpace.sRGB) else { return nil }
        width = image.width
        height = image.height
        bytes = [UInt8](repeating: 0, count: width * height * 4)
        let drawn = bytes.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8,
                                          bytesPerRow: width * 4, space: space,
                                          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return false }
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        guard drawn else { return nil }
    }
}

let args = CommandLine.arguments
guard args.count >= 4, let reference = Pixels(path: args[1]), let actual = Pixels(path: args[2]) else {
    print("illisible")
    exit(2)
}
let threshold = args.count > 4 ? (Double(args[4]) ?? 0.1) : 0.1
guard reference.width == actual.width, reference.height == actual.height else {
    print("tailles différentes : \(reference.width)x\(reference.height) contre \(actual.width)x\(actual.height)")
    exit(2)
}

var different = 0
var diff = actual.bytes
for pixel in 0..<(actual.width * actual.height) {
    let offset = pixel * 4
    var delta = 0
    for channel in 0..<3 { delta = max(delta, abs(Int(reference.bytes[offset + channel]) - Int(actual.bytes[offset + channel]))) }
    if delta > 24 {
        different += 1
        diff[offset] = 255; diff[offset + 1] = 25; diff[offset + 2] = 25
    } else {
        for channel in 0..<3 { diff[offset + channel] = UInt8(Double(actual.bytes[offset + channel]) * 0.4) }
    }
    diff[offset + 3] = 255
}

let percent = Double(different) * 100 / Double(actual.width * actual.height)
let written = diff.withUnsafeMutableBytes { buffer -> Bool in
    guard let space = CGColorSpace(name: CGColorSpace.sRGB),
          let context = CGContext(data: buffer.baseAddress, width: actual.width, height: actual.height, bitsPerComponent: 8,
                                  bytesPerRow: actual.width * 4, space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue),
          let image = context.makeImage(),
          let png = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]) else { return false }
    return (try? png.write(to: URL(fileURLWithPath: args[3]))) != nil
}
if !written { print("image de différences non écrite") }
print(String(format: "%.3f %% de pixels différents (seuil %.2f %%)", percent, threshold))
exit(percent <= threshold ? 0 : 1)
