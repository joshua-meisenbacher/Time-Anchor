import AppKit
import AVFoundation
import CoreImage

let outputURL = URL(fileURLWithPath: "/Users/joshuameisenbacher/UX Portfoilio /ND Planner App/TimeAnchor_Mentor_Demo.mp4")
let width = 1280
let height = 720
let fps: Int32 = 30

struct Scene {
    let duration: Double
    let draw: (_ t: Double, _ ctx: CGContext) -> Void
}

let workspace = "/Users/joshuameisenbacher/UX Portfoilio /ND Planner App"

func loadImage(_ relativePath: String) -> NSImage? {
    NSImage(contentsOfFile: "\(workspace)/\(relativePath)")
}

let heroImage = loadImage("Neurodivergent planner app.png")
let fiveDayImage = loadImage("Personal Events Page/Five Day View.png")
let alexImage = loadImage("Alex Rivera.png")
let jordanImage = loadImage("Jordan Carter.png")
let saraImage = loadImage("Sara Anderson.png")

func color(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1.0) -> NSColor {
    NSColor(calibratedRed: r / 255, green: g / 255, blue: b / 255, alpha: a)
}

let bg = color(239, 244, 240)
let card = NSColor.white
let primary = color(46, 115, 100)
let primaryMuted = color(214, 230, 223)
let text = color(24, 31, 30)
let secondary = color(82, 98, 94)

func drawBackground(in ctx: CGContext) {
    ctx.setFillColor(bg.cgColor)
    ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))

    ctx.saveGState()
    ctx.setFillColor(primaryMuted.withAlphaComponent(0.9).cgColor)
    ctx.fillEllipse(in: CGRect(x: -140, y: 500, width: 420, height: 260))
    ctx.fillEllipse(in: CGRect(x: 940, y: -80, width: 360, height: 260))
    ctx.restoreGState()
}

func paragraphStyle(lineHeight: CGFloat = 1.15) -> NSMutableParagraphStyle {
    let style = NSMutableParagraphStyle()
    style.lineBreakMode = .byWordWrapping
    style.lineHeightMultiple = lineHeight
    return style
}

func drawText(_ textValue: String, rect: CGRect, font: NSFont, color: NSColor, alignment: NSTextAlignment = .left) {
    let style = paragraphStyle()
    style.alignment = alignment
    let attributes: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: color,
        .paragraphStyle: style
    ]
    NSString(string: textValue).draw(with: rect, options: [.usesLineFragmentOrigin, .usesFontLeading], attributes: attributes)
}

func drawCapsuleLabel(_ value: String, x: CGFloat, y: CGFloat) {
    let rect = CGRect(x: x, y: y, width: 150, height: 34)
    let path = NSBezierPath(roundedRect: rect, xRadius: 17, yRadius: 17)
    primary.setFill()
    path.fill()
    drawText(value.uppercased(), rect: rect.insetBy(dx: 10, dy: 7), font: NSFont(name: "AvenirNext-DemiBold", size: 12) ?? .boldSystemFont(ofSize: 12), color: .white, alignment: .center)
}

func drawCard(_ rect: CGRect) {
    let shadow = NSShadow()
    shadow.shadowOffset = NSSize(width: 0, height: -6)
    shadow.shadowBlurRadius = 18
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.08)
    NSGraphicsContext.current?.saveGraphicsState()
    shadow.set()
    let path = NSBezierPath(roundedRect: rect, xRadius: 28, yRadius: 28)
    card.setFill()
    path.fill()
    NSGraphicsContext.current?.restoreGraphicsState()
}

func drawImage(_ image: NSImage?, in rect: CGRect, alpha: CGFloat = 1.0, cornerRadius: CGFloat = 24) {
    guard let image else { return }
    NSGraphicsContext.current?.saveGraphicsState()
    let path = NSBezierPath(roundedRect: rect, xRadius: cornerRadius, yRadius: cornerRadius)
    path.addClip()
    image.draw(in: rect, from: .zero, operation: .sourceOver, fraction: alpha)
    NSGraphicsContext.current?.restoreGraphicsState()
}

func drawWrappedBullets(_ bullets: [String], origin: CGPoint, width: CGFloat) {
    var y = origin.y
    for bullet in bullets {
        drawText("•", rect: CGRect(x: origin.x, y: y, width: 18, height: 30), font: NSFont(name: "AvenirNext-DemiBold", size: 20) ?? .boldSystemFont(ofSize: 20), color: primary)
        drawText(bullet, rect: CGRect(x: origin.x + 22, y: y, width: width - 22, height: 80), font: NSFont(name: "AvenirNext-Regular", size: 21) ?? .systemFont(ofSize: 21), color: secondary)
        y -= 72
    }
}

func drawProgress(_ index: Int, total: Int) {
    let barWidth: CGFloat = 240
    let startX = CGFloat(width) - barWidth - 60
    let y = CGFloat(48)
    for i in 0..<total {
        let w = (barWidth - CGFloat((total - 1) * 8)) / CGFloat(total)
        let x = startX + CGFloat(i) * (w + 8)
        let rect = CGRect(x: x, y: y, width: w, height: 8)
        let path = NSBezierPath(roundedRect: rect, xRadius: 4, yRadius: 4)
        (i <= index ? primary : primaryMuted).setFill()
        path.fill()
    }
}

func makePersonaScene(label: String, title: String, subtitle: String, body: String, bullets: [String], portrait: NSImage?, preview: NSImage?, index: Int) -> Scene {
    Scene(duration: 8.0) { t, ctx in
        drawBackground(in: ctx)
        drawProgress(index, total: 5)
        drawCapsuleLabel(label, x: 60, y: 632)
        drawText(title, rect: CGRect(x: 60, y: 550, width: 620, height: 84), font: NSFont(name: "AvenirNext-Bold", size: 42) ?? .boldSystemFont(ofSize: 42), color: text)
        drawText(subtitle, rect: CGRect(x: 60, y: 498, width: 640, height: 48), font: NSFont(name: "AvenirNext-DemiBold", size: 22) ?? .boldSystemFont(ofSize: 22), color: primary)
        drawText(body, rect: CGRect(x: 60, y: 390, width: 620, height: 96), font: NSFont(name: "AvenirNext-Regular", size: 22) ?? .systemFont(ofSize: 22), color: secondary)
        drawWrappedBullets(bullets, origin: CGPoint(x: 60, y: 305), width: 610)

        let portraitRect = CGRect(x: 790, y: 330, width: 360, height: 310)
        let previewRect = CGRect(x: 720, y: 70, width: 500, height: 230)
        drawCard(CGRect(x: 772, y: 312, width: 396, height: 346))
        drawImage(portrait, in: portraitRect, alpha: 1.0 - CGFloat(max(0, 0.15 - t * 0.03)), cornerRadius: 26)
        drawCard(CGRect(x: 700, y: 50, width: 540, height: 270))
        drawImage(preview, in: previewRect, alpha: 1.0, cornerRadius: 22)
    }
}

let scenes: [Scene] = [
    Scene(duration: 5.0) { _, ctx in
        drawBackground(in: ctx)
        drawCard(CGRect(x: 58, y: 82, width: 1164, height: 556))
        drawImage(heroImage, in: CGRect(x: 650, y: 120, width: 520, height: 480), alpha: 0.92, cornerRadius: 30)
        drawCapsuleLabel("Mentor Demo", x: 90, y: 560)
        drawText("Time Anchor", rect: CGRect(x: 90, y: 460, width: 500, height: 80), font: NSFont(name: "AvenirNext-Bold", size: 54) ?? .boldSystemFont(ofSize: 54), color: text)
        drawText("An adaptive planner for focus, transitions, overload, and recovery.", rect: CGRect(x: 90, y: 380, width: 500, height: 90), font: NSFont(name: "AvenirNext-Regular", size: 28) ?? .systemFont(ofSize: 28), color: secondary)
        drawText("This demo shows the product through three users rather than a feature tour.", rect: CGRect(x: 90, y: 290, width: 500, height: 90), font: NSFont(name: "AvenirNext-DemiBold", size: 22) ?? .boldSystemFont(ofSize: 22), color: primary)
        drawProgress(0, total: 5)
    },
    makePersonaScene(
        label: "Story 1",
        title: "Jordan: School and Work",
        subtitle: "A student trying to protect the best study window before an afternoon shift.",
        body: "The problem is not just a full schedule. It is losing the morning to anxiety, switching costs, and a blurry transition into work.",
        bullets: [
            "Protects the morning study block",
            "Makes the work transition explicit",
            "Reduces context switching before the shift"
        ],
        portrait: jordanImage,
        preview: fiveDayImage,
        index: 1
    ),
    makePersonaScene(
        label: "Story 2",
        title: "Sara: Overloaded Coordination Day",
        subtitle: "A family coordinator holding too many demands at once.",
        body: "Here the app has to do more than list tasks. It needs to make the day readable, show the heaviest commitment first, and keep recovery visible before burnout takes over.",
        bullets: [
            "Turns overload into clearer anchors",
            "Surfaces the highest-weight commitment first",
            "Keeps shutdown and recovery in view"
        ],
        portrait: saraImage,
        preview: heroImage,
        index: 2
    ),
    makePersonaScene(
        label: "Story 3",
        title: "Alex: Recovery Without Losing the Thread",
        subtitle: "A day where success means less pressure, not more output.",
        body: "Time Anchor can also support regulation. The goal here is to protect restorative time while keeping one practical task visible so the day still feels held together.",
        bullets: [
            "Lowers pressure instead of increasing it",
            "Protects recovery time as real structure",
            "Keeps just enough visible to stay grounded"
        ],
        portrait: alexImage,
        preview: heroImage,
        index: 3
    ),
    Scene(duration: 6.0) { _, ctx in
        drawBackground(in: ctx)
        drawProgress(4, total: 5)
        drawCard(CGRect(x: 90, y: 120, width: 1100, height: 480))
        drawCapsuleLabel("Takeaway", x: 120, y: 530)
        drawText("What makes Time Anchor different", rect: CGRect(x: 120, y: 448, width: 760, height: 70), font: NSFont(name: "AvenirNext-Bold", size: 44) ?? .boldSystemFont(ofSize: 44), color: text)
        drawWrappedBullets([
            "It adapts support to the user, not just the task list.",
            "It treats overload, transitions, and recovery as design problems.",
            "It frames planning as making the day more workable, not just more efficient."
        ], origin: CGPoint(x: 120, y: 360), width: 760)
        drawImage(heroImage, in: CGRect(x: 860, y: 170, width: 280, height: 380), alpha: 0.95, cornerRadius: 30)
    }
]

func pixelBufferPool(writerInput: AVAssetWriterInput, adaptor: AVAssetWriterInputPixelBufferAdaptor) -> CVPixelBufferPool? {
    while adaptor.pixelBufferPool == nil {
        usleep(1000)
    }
    return adaptor.pixelBufferPool
}

func makePixelBuffer(from image: CGImage, pool: CVPixelBufferPool) -> CVPixelBuffer? {
    var maybeBuffer: CVPixelBuffer?
    let status = CVPixelBufferPoolCreatePixelBuffer(nil, pool, &maybeBuffer)
    guard status == kCVReturnSuccess, let buffer = maybeBuffer else { return nil }

    CVPixelBufferLockBaseAddress(buffer, [])
    defer { CVPixelBufferUnlockBaseAddress(buffer, []) }

    guard let context = CGContext(
        data: CVPixelBufferGetBaseAddress(buffer),
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue
    ) else { return nil }

    context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
    return buffer
}

func renderFrame(scene: Scene, time: Double) -> CGImage? {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: width,
        pixelsHigh: height,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: width * 4,
        bitsPerPixel: 32
    )

    guard let bitmap = rep else { return nil }
    let image = NSImage(size: NSSize(width: width, height: height))
    image.addRepresentation(bitmap)

    NSGraphicsContext.saveGraphicsState()
    guard let graphicsContext = NSGraphicsContext(bitmapImageRep: bitmap) else { return nil }
    NSGraphicsContext.current = graphicsContext
    scene.draw(time, graphicsContext.cgContext)
    NSGraphicsContext.restoreGraphicsState()

    return bitmap.cgImage
}

try? FileManager.default.removeItem(at: outputURL)

let writer = try AVAssetWriter(outputURL: outputURL, fileType: .mp4)
let settings: [String: Any] = [
    AVVideoCodecKey: AVVideoCodecType.h264,
    AVVideoWidthKey: width,
    AVVideoHeightKey: height
]
let input = AVAssetWriterInput(mediaType: .video, outputSettings: settings)
input.expectsMediaDataInRealTime = false

let sourceAttributes: [String: Any] = [
    kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32ARGB),
    kCVPixelBufferWidthKey as String: width,
    kCVPixelBufferHeightKey as String: height
]

let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: sourceAttributes)
guard writer.canAdd(input) else {
    fatalError("Cannot add input")
}
writer.add(input)

guard writer.startWriting() else {
    fatalError("Could not start writing")
}
writer.startSession(atSourceTime: .zero)

guard let pool = pixelBufferPool(writerInput: input, adaptor: adaptor) else {
    fatalError("No pixel buffer pool")
}

var frameCount: Int64 = 0
for scene in scenes {
    let sceneFrames = Int(scene.duration * Double(fps))
    for i in 0..<sceneFrames {
        while !input.isReadyForMoreMediaData {
            usleep(1000)
        }

        let t = Double(i) / Double(sceneFrames)
        guard let cgImage = renderFrame(scene: scene, time: t),
              let buffer = makePixelBuffer(from: cgImage, pool: pool) else {
            continue
        }

        let presentation = CMTime(value: frameCount, timescale: fps)
        adaptor.append(buffer, withPresentationTime: presentation)
        frameCount += 1
    }
}

input.markAsFinished()
writer.finishWriting {
    print("Wrote video to \(outputURL.path)")
}

while writer.status == .writing {
    RunLoop.current.run(until: Date().addingTimeInterval(0.1))
}

if writer.status != .completed {
    fputs("Video generation failed: \(writer.error?.localizedDescription ?? "unknown error")\n", stderr)
    exit(1)
}

print("Done")
