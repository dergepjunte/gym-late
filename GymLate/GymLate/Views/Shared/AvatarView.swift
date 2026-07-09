import SwiftUI
import UIKit

/// Member avatar: uploaded photo when `avatarImg` (data URL) is set,
/// otherwise emoji on the member color — same fallback order as the website.
struct AvatarView: View {
    let emoji: String
    let color: String
    let img: String?
    var size: CGFloat = 48

    private static let cache = NSCache<NSString, UIImage>()

    var body: some View {
        if let img, let ui = Self.decode(img) {
            Image(uiImage: ui)
                .resizable()
                .scaledToFill()
                .frame(width: size, height: size)
                .clipShape(Circle())
        } else {
            ZStack {
                Circle()
                    .fill(Color(hex: color).opacity(0.22))
                    .frame(width: size, height: size)
                Text(emoji)
                    .font(.system(size: size * 0.54))
            }
        }
    }

    static func decode(_ dataURL: String) -> UIImage? {
        guard dataURL.hasPrefix("data:image/") else { return nil }
        let key = NSString(string: String(dataURL.suffix(64)) + "\(dataURL.count)")
        if let cached = cache.object(forKey: key) { return cached }
        guard let comma = dataURL.firstIndex(of: ","),
              let data = Data(base64Encoded: String(dataURL[dataURL.index(after: comma)...])),
              let ui = UIImage(data: data) else { return nil }
        cache.setObject(ui, forKey: key)
        return ui
    }
}
