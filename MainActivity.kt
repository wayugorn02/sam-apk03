package com.sam.drivehub

import android.Manifest
import android.annotation.SuppressLint
import android.app.Activity
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Bundle
import android.webkit.JavascriptInterface
import android.webkit.PermissionRequest
import android.webkit.ValueCallback
import android.webkit.WebChromeClient
import android.webkit.WebResourceRequest
import android.webkit.WebSettings
import android.webkit.WebView
import android.webkit.WebViewClient
import android.widget.Toast
import androidx.activity.OnBackPressedCallback
import androidx.activity.result.contract.ActivityResultContracts
import androidx.appcompat.app.AppCompatActivity
import androidx.biometric.BiometricManager
import androidx.biometric.BiometricPrompt
import androidx.core.content.ContextCompat

/**
 * MainActivity สำหรับแอป "แซม" (SAM Drive Hub)
 * รองรับ:
 * 1. ระบบล็อกแอปด้วยสแกนลายนิ้วมือและสแกนใบหน้าของ Android จริง (BiometricPrompt API)
 * 2. ระบบเลือกไฟล์จากเครื่อง Android เพื่ออัปโหลดเข้า Google Drive, เปลี่ยนไอคอนแอป และเปลี่ยนรูปพื้นหลัง
 * 3. ระบบเชื่อมต่อ Google Drive REST API v3 และตู้เซฟไฟล์ส่วนตัว
 */
class MainActivity : AppCompatActivity() {

    private lateinit var webView: WebView
    private var filePathCallback: ValueCallback<Array<Uri>>? = null

    // ตัวรับผลลัพธ์การเลือกไฟล์จากเครื่อง (รูปภาพ, วิดีโอ, เอกสาร, ไฟล์ ZIP, ไอคอนแอป, พื้นหลัง)
    private val fileChooserLauncher = registerForActivityResult(
        ActivityResultContracts.StartActivityForResult()
    ) { result ->
        if (result.resultCode == Activity.RESULT_OK) {
            val data = result.data
            val results: Array<Uri>? = when {
                data?.clipData != null -> {
                    val count = data.clipData!!.itemCount
                    Array(count) { i -> data.clipData!!.getItemAt(i).uri }
                }
                data?.data != null -> arrayOf(data.data!!)
                else -> null
            }
            filePathCallback?.onReceiveValue(results)
        } else {
            filePathCallback?.onReceiveValue(null)
        }
        filePathCallback = null
    }

    // ขออนุญาตใช้กล้องสำหรับฟีเจอร์สแกนใบหน้า (Face Scan)
    private val cameraPermissionLauncher = registerForActivityResult(
        ActivityResultContracts.RequestPermission()
    ) { isGranted ->
        if (!isGranted) {
            Toast.makeText(this, "สามารถใช้ระบบสแกนใบหน้าผ่าน Biometric ของเครื่องได้ทันที", Toast.LENGTH_SHORT).show()
        }
    }

    @SuppressLint("SetJavaScriptEnabled")
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        webView = WebView(this)
        setContentView(webView)

        setupWebView()
        setupBackNavigation()

        // โหลดตัวแอป "แซม" จากโฟลเดอร์ assets/www/index.html
        webView.loadUrl("file:///android_asset/www/index.html")
    }

    @SuppressLint("SetJavaScriptEnabled")
    private fun setupWebView() {
        val settings: WebSettings = webView.settings
        settings.javaScriptEnabled = true
        settings.domStorageEnabled = true
        settings.databaseEnabled = true
        settings.allowFileAccess = true
        settings.allowContentAccess = true
        settings.mediaPlaybackRequiresUserGesture = false
        settings.mixedContentMode = WebSettings.MIXED_CONTENT_ALWAYS_ALLOW
        settings.userAgentString = settings.userAgentString + " SamDriveAndroidApp/1.0"

        // เชื่อมต่อ JavaScript Bridge สำหรับเรียกใช้ระบบสแกนลายนิ้วมือและสแกนใบหน้าของ Android
        webView.addJavascriptInterface(AndroidBiometricBridge(), "AndroidNative")

        webView.webViewClient = object : WebViewClient() {
            override fun shouldOverrideUrlLoading(view: WebView?, request: WebResourceRequest?): Boolean {
                val url = request?.url?.toString() ?: return false
                // หากเป็นลิงก์เปิดไฟล์ในแอป Google Drive ภายนอก ให้เปิดด้วย Intent
                if (url.startsWith("https://drive.google.com/file/")) {
                    val intent = Intent(Intent.ACTION_VIEW, Uri.parse(url))
                    startActivity(intent)
                    return true
                }
                return false
            }
        }

        webView.webChromeClient = object : WebChromeClient() {
            // รองรับ <input type="file"> สำหรับอัปโหลดไฟล์เข้า Drive, เปลี่ยนรูปพื้นหลัง และเปลี่ยนไอคอนแอป
            override fun onShowFileChooser(
                webView: WebView?,
                filePathCallback: ValueCallback<Array<Uri>>?,
                fileChooserParams: FileChooserParams?
            ): Boolean {
                this@MainActivity.filePathCallback?.onReceiveValue(null)
                this@MainActivity.filePathCallback = filePathCallback

                val intent = Intent(Intent.ACTION_GET_CONTENT).apply {
                    addCategory(Intent.CATEGORY_OPENABLE)
                    type = "*/*"
                    putExtra(Intent.EXTRA_ALLOW_MULTIPLE, true)
                }
                fileChooserLauncher.launch(Intent.createChooser(intent, "เลือกไฟล์สำหรับแอปแซม"))
                return true
            }

            // รองรับการขอสิทธิ์กล้องจาก WebRTC สำหรับสแกนใบหน้า
            override fun onPermissionRequest(request: PermissionRequest?) {
                request?.let {
                    if (ContextCompat.checkSelfPermission(this@MainActivity, Manifest.permission.CAMERA)
                        != PackageManager.PERMISSION_GRANTED
                    ) {
                        cameraPermissionLauncher.launch(Manifest.permission.CAMERA)
                    }
                    it.grant(it.resources)
                }
            }
        }
    }

    /**
     * ฟังก์ชันเรียกใช้งาน Android Hardware BiometricPrompt (สแกนนิ้วมือ / สแกนใบหน้าระดับฮาร์ดแวร์)
     */
    fun authenticateWithHardwareBiometric(title: String, subtitle: String) {
        val executor = ContextCompat.getMainExecutor(this)
        val biometricPrompt = BiometricPrompt(this, executor,
            object : BiometricPrompt.AuthenticationCallback() {
                override fun onAuthenticationSucceeded(result: BiometricPrompt.AuthenticationResult) {
                    super.onAuthenticationSucceeded(result)
                    // ปลดล็อกหน้าจอแอป "แซม" อัตโนมัติเมื่อสแกนผ่าน
                    webView.evaluateJavascript(
                        "document.getElementById('appLockOverlay').classList.add('hidden');",
                        null
                    )
                    Toast.makeText(this@MainActivity, "ปลดล็อกแอปแซมสำเร็จ", Toast.LENGTH_SHORT).show()
                }

                override fun onAuthenticationError(errorCode: Int, errString: CharSequence) {
                    super.onAuthenticationError(errorCode, errString)
                    Toast.makeText(this@MainActivity, "ยกเลิกการสแกน: $errString", Toast.LENGTH_SHORT).show()
                }
            })

        val promptInfo = BiometricPrompt.PromptInfo.Builder()
            .setTitle(title)
            .setSubtitle(subtitle)
            .setAllowedAuthenticators(
                BiometricManager.Authenticators.BIOMETRIC_STRONG or
                BiometricManager.Authenticators.BIOMETRIC_WEAK or
                BiometricManager.Authenticators.DEVICE_CREDENTIAL
            )
            .build()

        biometricPrompt.authenticate(promptInfo)
    }

    inner class AndroidBiometricBridge {
        @JavascriptInterface
        fun triggerFingerprintUnlock() {
            runOnUiThread {
                authenticateWithHardwareBiometric(
                    "ปลดล็อกแอปแซม (SAM)",
                    "แตะเซ็นเซอร์ลายนิ้วมือเพื่อเข้าใช้งาน"
                )
            }
        }

        @JavascriptInterface
        fun triggerFaceUnlock() {
            runOnUiThread {
                authenticateWithHardwareBiometric(
                    "สแกนใบหน้าเข้าแอปแซม (SAM)",
                    "มองที่กล้องหน้าเพื่อยืนยันตัวตน"
                )
            }
        }
    }

    private fun setupBackNavigation() {
        onBackPressedDispatcher.addCallback(this, object : OnBackPressedCallback(true) {
            override fun handleOnBackPressed() {
                if (webView.canGoBack()) {
                    webView.goBack()
                } else {
                    finish()
                }
            }
        })
    }
}
