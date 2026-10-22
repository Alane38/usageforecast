package com.alane.usageforecast

import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageInstaller
import android.os.Build
import java.io.File

/** Dernier état de l'installation, lu par l'écran de mise à jour. */
object InstallStatus {
    @Volatile var listener: ((String) -> Unit)? = null
    fun post(message: String) { listener?.invoke(message) }
}

/** Installe un APK déjà vérifié avec PackageInstaller. Android contrôle lui-même que la signature est celle de l'app installée. */
object UpdateInstaller {
    /** Vérifie que l'archive est bien cette application, en version plus récente, avant de la proposer au système. */
    fun check(context: Context, apk: File): String? {
        val info = context.packageManager.getPackageArchiveInfo(apk.path, 0) ?: return "Archive illisible."
        if (info.packageName != context.packageName) return "Cette archive n'est pas UsageForecast."
        return null
    }

    fun install(context: Context, apk: File) {
        val installer = context.packageManager.packageInstaller
        val params = PackageInstaller.SessionParams(PackageInstaller.SessionParams.MODE_FULL_INSTALL).apply {
            setAppPackageName(context.packageName)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) setRequireUserAction(PackageInstaller.SessionParams.USER_ACTION_NOT_REQUIRED)
        }
        val sessionId = installer.createSession(params)
        installer.openSession(sessionId).use { session ->
            apk.inputStream().use { input ->
                session.openWrite("apk", 0, apk.length()).use { output ->
                    input.copyTo(output)
                    session.fsync(output)
                }
            }
            val callback = Intent(context, InstallResultReceiver::class.java)
            // Mutable : le système y ajoute le statut et l'intent de confirmation.
            val pending = PendingIntent.getBroadcast(context, sessionId, callback, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE)
            session.commit(pending.intentSender)
        }
    }
}

/** Reçoit le résultat : ouvre la confirmation d'Android si elle est demandée, sinon rend compte. */
class InstallResultReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        when (intent.getIntExtra(PackageInstaller.EXTRA_STATUS, PackageInstaller.STATUS_FAILURE)) {
            PackageInstaller.STATUS_PENDING_USER_ACTION -> {
                @Suppress("DEPRECATION")
                val confirm = intent.getParcelableExtra<Intent>(Intent.EXTRA_INTENT)
                confirm?.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)?.let(context::startActivity)
                InstallStatus.post("Confirme l'installation dans la fenêtre d'Android.")
            }
            PackageInstaller.STATUS_SUCCESS -> InstallStatus.post("Mise à jour installée.")
            PackageInstaller.STATUS_FAILURE_INCOMPATIBLE ->
                InstallStatus.post("Android refuse cette version : la signature diffère de l'application installée. Désinstalle puis réinstalle l'APK.")
            else -> InstallStatus.post("Installation impossible (${intent.getStringExtra(PackageInstaller.EXTRA_STATUS_MESSAGE) ?: "erreur inconnue"}).")
        }
    }
}
