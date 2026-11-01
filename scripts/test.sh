#!/bin/bash
# Tests unitaires de la logique pure (sans UI) : compile le module avec les tests puis les exécute.
# Une erreur de compilation arrête tout : le binaire de tests n'est remplacé qu'après une compilation réussie,
# on n'exécute donc jamais un ancien binaire.
set -euo pipefail
cd "$(dirname "$0")/.."

SDK_ROOT=/Library/Developer/CommandLineTools/SDKs
SDK="${CUB_SDK:-$SDK_ROOT/MacOSX26.5.sdk}"
[ -d "$SDK" ] || SDK="$SDK_ROOT/MacOSX26.sdk"
[ -d "$SDK" ] || { echo "SDK introuvable : $SDK (variable CUB_SDK)" >&2; exit 1; }

mkdir -p build
swiftc -sdk "$SDK" -o build/tests.new \
    app/StatuslineUsage.swift app/KeychainStore.swift app/SecretStore.swift app/BundledSecretStore.swift app/AppSecrets.swift app/UsageForecast.swift \
    app/MenuBarDisplay.swift app/ApiCredits.swift app/ConsoleBalance.swift app/SyncHelpers.swift app/RefreshPolicy.swift \
    app/DesignModels.swift app/PaceText.swift app/UsageAnalytics.swift app/AlertRules.swift app/WeekPlan.swift \
    app/ForecastExport.swift app/SystemSettings.swift app/UsageHistory.swift app/DailyHistory.swift app/CreditsSummary.swift \
    app/AppClock.swift app/UpdateChecker.swift app/Brand.swift app/MobileSyncPolicy.swift app/AppSupport.swift app/FirstRun.swift app/UpdateInstaller.swift app/DayBudget.swift app/MobileCrypto.swift app/MobileSnapshot.swift app/MobileUploader.swift app/DailyInsights.swift app/Organizations.swift app/FirefoxCookies.swift \
    app/LoanModels.swift app/LoanAttribution.swift app/LoanRules.swift app/ClaudeTranscripts.swift app/LoanPublishing.swift tests/loan_tests.swift tests/main.swift
mv build/tests.new build/tests
build/tests
