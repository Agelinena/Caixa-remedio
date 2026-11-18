package br.caixaremedios.caixa_remedios

import android.content.Context
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// Canal "caixa/rede": na rede da caixa (sem internet) o Android manda o tráfego
// pelos dados móveis. "usarWifi" prende o app ao Wi-Fi; "liberar" desfaz.
class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "caixa/rede").setMethodCallHandler { call, result ->
            val cm = getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
            when (call.method) {
                "usarWifi" -> {
                    @Suppress("DEPRECATION")
                    val wifi = cm.allNetworks.firstOrNull { n ->
                        cm.getNetworkCapabilities(n)?.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) == true
                    }
                    result.success(wifi != null && cm.bindProcessToNetwork(wifi))
                }
                "liberar" -> {
                    cm.bindProcessToNetwork(null)
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }
}
