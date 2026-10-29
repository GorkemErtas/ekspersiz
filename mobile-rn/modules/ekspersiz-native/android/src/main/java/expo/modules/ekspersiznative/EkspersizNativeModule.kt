package expo.modules.ekspersiznative

import android.app.Activity
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Matrix
import android.net.Uri
import android.provider.Settings
import android.util.AtomicFile
import androidx.exifinterface.media.ExifInterface
import com.google.android.play.core.integrity.IntegrityManagerFactory
import com.google.android.play.core.integrity.StandardIntegrityManager
import com.google.android.play.core.appupdate.AppUpdateManagerFactory
import com.google.android.play.core.appupdate.AppUpdateOptions
import com.google.android.play.core.install.model.AppUpdateType
import com.google.android.play.core.install.model.UpdateAvailability
import expo.modules.kotlin.Promise
import expo.modules.kotlin.modules.Module
import expo.modules.kotlin.modules.ModuleDefinition
import java.io.DataInputStream
import java.io.File
import java.util.UUID
import kotlin.math.max
import kotlin.math.min
import kotlin.math.roundToInt

class EkspersizNativeModule : Module() {
  private fun context() = appContext.reactContext ?: throw IllegalStateException("Uygulama hazır değil.")
  private fun marker() = AtomicFile(File(context().noBackupFilesDir, "installation/onboarding_completed"))
  override fun definition() = ModuleDefinition {
    Name("EkspersizNative")
    AsyncFunction("installationCompleted") { try { marker().readFully().toString(Charsets.UTF_8) == "completed" } catch (_: Exception) { false } }
    AsyncFunction("completeInstallation") { val marker=marker(); marker.baseFile.parentFile?.mkdirs(); val stream=marker.startWrite(); try { stream.write("completed".toByteArray()); marker.finishWrite(stream) } catch(error:Exception) { marker.failWrite(stream); throw error } }
    AsyncFunction("deviceId") { Settings.Secure.getString(context().contentResolver, Settings.Secure.ANDROID_ID) ?: throw IllegalStateException("Cihaz kimliği alınamadı.") }
    AsyncFunction("integrityToken") { project:String, hash:String, promise:Promise ->
      val manager=IntegrityManagerFactory.createStandard(context())
      manager.prepareIntegrityToken(StandardIntegrityManager.PrepareIntegrityTokenRequest.builder().setCloudProjectNumber(project.toLong()).build())
        .addOnSuccessListener { provider -> provider.request(StandardIntegrityManager.StandardIntegrityTokenRequest.builder().setRequestHash(hash).build()).addOnSuccessListener { promise.resolve(it.token()) }.addOnFailureListener { promise.reject("INTEGRITY_FAILED", "Cihaz doğrulanamadı.",it) } }
        .addOnFailureListener { promise.reject("INTEGRITY_UNAVAILABLE", "Cihaz doğrulaması kullanılamıyor.",it) }
    }
    AsyncFunction("playUpdateInfo") { promise:Promise ->
      AppUpdateManagerFactory.create(context()).appUpdateInfo.addOnSuccessListener { info -> promise.resolve(mapOf("available" to (info.updateAvailability()==UpdateAvailability.UPDATE_AVAILABLE),"immediateAllowed" to info.isUpdateTypeAllowed(AppUpdateType.IMMEDIATE),"inProgress" to (info.updateAvailability()==UpdateAvailability.DEVELOPER_TRIGGERED_UPDATE_IN_PROGRESS))) }.addOnFailureListener { promise.reject("UPDATE_UNAVAILABLE","Mağaza güncellemesi kontrol edilemedi.",it) }
    }
    AsyncFunction("immediateUpdate") { promise:Promise ->
      val manager=AppUpdateManagerFactory.create(context()); val activity=appContext.currentActivity
      if(activity==null) promise.reject("NO_ACTIVITY","Uygulama ön planda olmalı.",null)
      else manager.appUpdateInfo.addOnSuccessListener { info ->
        manager.startUpdateFlow(info,activity,AppUpdateOptions.newBuilder(AppUpdateType.IMMEDIATE).build()).addOnSuccessListener { promise.resolve(it==Activity.RESULT_OK) }.addOnFailureListener { promise.reject("UPDATE_FAILED","Güncelleme tamamlanamadı.",it) }
      }.addOnFailureListener { promise.reject("UPDATE_UNAVAILABLE","Güncelleme kontrol edilemedi.",it) }
    }
    AsyncFunction("prepareImage") { uri:String -> prepareImage(uri) }
  }
  private fun prepareImage(uri:String):Map<String,Any> {
    val cache=File(context().cacheDir,"ekspersiz-images").apply { mkdirs() }
    val input=File(cache,"source-${UUID.randomUUID()}")
    var decoded:Bitmap?=null; var oriented:Bitmap?=null; var output:Bitmap?=null
    try {
      context().contentResolver.openInputStream(Uri.parse(uri)).use { stream ->
        requireNotNull(stream) { "Fotoğraf okunamadı." }; input.outputStream().use { dest ->
          val buffer=ByteArray(32768); var total=0L
          while(true) { val n=stream.read(buffer); if(n<0)break; total+=n; require(total<=40L*1024*1024) { "Fotoğraf 40 MB sınırını aşıyor." }; dest.write(buffer,0,n) }
        }
      }
      validateContainer(input)
      val bounds=BitmapFactory.Options().apply { inJustDecodeBounds=true }; BitmapFactory.decodeFile(input.path,bounds)
      val w=bounds.outWidth; val h=bounds.outHeight
      require(w>0 && h>0 && w.toLong()*h<=64_000_000 && min(w,h)>=256) { "Fotoğraf çözünürlüğü geçersiz (en az 256 piksel, en çok 64 MP)." }
      var sample=1; while(max(w,h)/sample>2048)sample*=2
      decoded=BitmapFactory.decodeFile(input.path,BitmapFactory.Options().apply { inSampleSize=sample;inPreferredConfig=Bitmap.Config.ARGB_8888 }) ?: error("Fotoğraf okunamadı.")
      val exif=ExifInterface(input).getAttributeInt(ExifInterface.TAG_ORIENTATION,ExifInterface.ORIENTATION_NORMAL)
      val matrix=Matrix().apply {
        when(exif) {
          ExifInterface.ORIENTATION_FLIP_HORIZONTAL -> setScale(-1f,1f)
          ExifInterface.ORIENTATION_ROTATE_180 -> setRotate(180f)
          ExifInterface.ORIENTATION_FLIP_VERTICAL -> setScale(1f,-1f)
          ExifInterface.ORIENTATION_TRANSPOSE -> {setRotate(90f);postScale(-1f,1f)}
          ExifInterface.ORIENTATION_ROTATE_90 -> setRotate(90f)
          ExifInterface.ORIENTATION_TRANSVERSE -> {setRotate(-90f);postScale(-1f,1f)}
          ExifInterface.ORIENTATION_ROTATE_270 -> setRotate(-90f)
        }
      }
      oriented=Bitmap.createBitmap(decoded,0,0,decoded.width,decoded.height,matrix,true)
      val scale=min(1.0,2048.0/max(oriented.width,oriented.height));val tw=(oriented.width*scale).roundToInt();val th=(oriented.height*scale).roundToInt()
      require(min(tw,th)>=256) { "Çok geniş panorama yerine araç bölgesini gösteren fotoğraf seçin." }
      output=Bitmap.createBitmap(tw,th,Bitmap.Config.ARGB_8888)
      Canvas(output).apply { drawColor(Color.WHITE); drawBitmap(oriented,null,android.graphics.Rect(0,0,tw,th),android.graphics.Paint(android.graphics.Paint.FILTER_BITMAP_FLAG)) }
      val file=File(cache,"prepared-${UUID.randomUUID()}.jpg")
      try { file.outputStream().use { require(output.compress(Bitmap.CompressFormat.JPEG,90,it)) { "Fotoğraf dönüştürülemedi." } };require(file.length() in 1..10L*1024*1024) { "Fotoğraf yükleme sınırını aşıyor." };val digest=java.security.MessageDigest.getInstance("SHA-256");file.inputStream().use { source->val buffer=ByteArray(8192);while(true){val count=source.read(buffer);if(count<0)break;digest.update(buffer,0,count)} };val hash=digest.digest().joinToString(""){"%02x".format(it)};return mapOf("uri" to Uri.fromFile(file).toString(),"width" to tw,"height" to th,"size" to file.length(),"hash" to hash) } catch(error:Exception){file.delete();throw error}
    } finally {input.delete(); if(output!==oriented&&output!==decoded)output?.recycle();if(oriented!==decoded)oriented?.recycle();decoded?.recycle()}
  }
  private fun validateContainer(file:File) {
    DataInputStream(file.inputStream().buffered()).use { stream ->
      val header=ByteArray(12);stream.readFully(header)
      val jpeg=(header[0].toInt()and 255)==255&&(header[1].toInt()and 255)==216&&(header[2].toInt()and 255)==255
      val png=header.take(8).toByteArray().contentEquals(byteArrayOf(-119,80,78,71,13,10,26,10))
      val webp=String(header,0,4)=="RIFF"&&String(header,8,4)=="WEBP"
      require(jpeg||png||webp) { "Geçerli bir JPG, PNG veya WEBP fotoğraf seçin." }
      if(jpeg)return
    }
    DataInputStream(file.inputStream().buffered()).use { stream ->
      val sig=ByteArray(12);stream.readFully(sig)
      val png=(sig[0].toInt()and 255)==137
      if(png){stream.close();DataInputStream(file.inputStream().buffered()).use { input->input.skipBytes(8);while(input.available()>0){val len=input.readInt();require(len>=0&&len<=file.length());val type=ByteArray(4);input.readFully(type);require(String(type)!="acTL") { "Hareketli görsel yerine tek fotoğraf seçin." };var remaining=len.toLong()+4;while(remaining>0){val n=input.skip(remaining);require(n>0);remaining-=n};if(String(type)=="IEND")break} }}
      else while(stream.available()>0) { val type=ByteArray(4);stream.readFully(type);val len=Integer.reverseBytes(stream.readInt());require(len>=0&&len<=file.length());require(String(type)!="ANIM"&&String(type)!="ANMF") { "Hareketli görsel yerine tek fotoğraf seçin." };var remaining=len.toLong()+(len and 1);while(remaining>0){val n=stream.skip(remaining);require(n>0);remaining-=n} }
    }
  }
}
