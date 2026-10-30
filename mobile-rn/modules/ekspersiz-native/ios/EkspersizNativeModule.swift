import ExpoModulesCore
import CryptoKit
import UIKit
import ImageIO
import UniformTypeIdentifiers

public class EkspersizNativeModule: Module {
  private func failure(_ message:String) -> NSError { NSError(domain:"EkspersizNative",code:1,userInfo:[NSLocalizedDescriptionKey:message]) }
  private func installationDirectory() throws -> URL {
    var directory=try FileManager.default.url(for:.applicationSupportDirectory,in:.userDomainMask,appropriateFor:nil,create:true).appendingPathComponent("installation",isDirectory:true)
    try FileManager.default.createDirectory(at:directory,withIntermediateDirectories:true)
    var values=URLResourceValues();values.isExcludedFromBackup=true;try directory.setResourceValues(values)
    return directory
  }
  public func definition() -> ModuleDefinition {
    Name("EkspersizNative")
    AsyncFunction("installationCompleted") { () -> Bool in
      guard let url=try? self.installationDirectory().appendingPathComponent("onboarding_completed"),let data=try? Data(contentsOf:url) else {return false}
      return String(data:data,encoding:.utf8)=="completed"
    }
    AsyncFunction("completeInstallation") { try Data("completed".utf8).write(to:self.installationDirectory().appendingPathComponent("onboarding_completed"),options:.atomic) }
    AsyncFunction("deviceId") { () -> String in throw self.failure("Bu cihazda başlangıç kredisi doğrulaması kullanılamıyor.") }
    AsyncFunction("integrityToken") { (_:String,_:String) -> String in throw self.failure("Play Integrity yalnızca Android'de kullanılabilir.") }
    AsyncFunction("prepareImage") { (uri:String) -> [String:Any] in
      guard let url=URL(string:uri),url.isFileURL else {throw self.failure("Fotoğraf okunamadı.")}
      let attributes=try FileManager.default.attributesOfItem(atPath:url.path)
      guard let size=attributes[.size] as? NSNumber,size.int64Value>0,size.int64Value<=40*1024*1024,
        let source=CGImageSourceCreateWithURL(url as CFURL,nil),let type=CGImageSourceGetType(source) as String?,
        [UTType.jpeg.identifier,UTType.png.identifier,UTType.webP.identifier].contains(type),CGImageSourceGetCount(source)==1,
        let properties=CGImageSourceCopyPropertiesAtIndex(source,0,nil) as? [CFString:Any],
        let width=properties[kCGImagePropertyPixelWidth] as? Int,let height=properties[kCGImagePropertyPixelHeight] as? Int,
        width>0,height>0,width*height<=64_000_000,min(width,height)>=256 else {throw self.failure("Geçerli, hareketsiz JPG, PNG veya WEBP seçin (256 piksel–64 MP).")}
      let options:[CFString:Any]=[kCGImageSourceCreateThumbnailFromImageAlways:true,kCGImageSourceCreateThumbnailWithTransform:true,kCGImageSourceThumbnailMaxPixelSize:2048,kCGImageSourceShouldCacheImmediately:true]
      guard let image=CGImageSourceCreateThumbnailAtIndex(source,0,options as CFDictionary),min(image.width,image.height)>=256 else {throw self.failure("Fotoğraf işlenemedi veya çok geniş panorama seçildi.")}
      let format=UIGraphicsImageRendererFormat();format.scale=1;format.opaque=true
      let renderer=UIGraphicsImageRenderer(size:CGSize(width:image.width,height:image.height),format:format)
      let data=renderer.jpegData(withCompressionQuality:0.9) { context in
        UIColor.white.setFill();context.fill(CGRect(x:0,y:0,width:image.width,height:image.height))
        UIImage(cgImage:image).draw(in:CGRect(x:0,y:0,width:image.width,height:image.height))
      }
      guard data.count<=10*1024*1024 else {throw self.failure("Fotoğraf yükleme sınırını aşıyor.")}
      let directory=FileManager.default.urls(for:.cachesDirectory,in:.userDomainMask)[0].appendingPathComponent("ekspersiz-images",isDirectory:true)
      try FileManager.default.createDirectory(at:directory,withIntermediateDirectories:true)
      let output=directory.appendingPathComponent("prepared-\(UUID().uuidString).jpg");try data.write(to:output,options:.atomic)
      return ["uri":output.absoluteString,"width":image.width,"height":image.height,"size":data.count,"hash":SHA256.hash(data:data).map { String(format:"%02x",$0) }.joined()]
    }
  }
}
