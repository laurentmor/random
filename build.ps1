# ───────────── Préparation du log ─────────────
$logDir = "E:\maven\logs"

if (-not (Test-Path $logDir)) {
    New-Item -ItemType Directory -Path $logDir | Out-Null
}
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$OUT = Join-Path $logDir "build_$timestamp.log"

# ───────────── Constantes de chemin ─────────────
$gitRepoPath   = "E:\maven\src\maven"
$buildPath     = "E:\maven\build"
$tempBuildPath = "E:\maven\_build"
$rootPath      = "E:\maven"

# ───────────── Fonctions utilitaires ─────────────
function Log($message) {
    $time = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$time - $message" | Out-File -Append $OUT
}

function Check-CommandAvailability {
    param([string[]]$commands)
    foreach ($cmd in $commands) {
        $exists = Get-Command $cmd -ErrorAction SilentlyContinue
        if (-not $exists) {
            $msg = "⛔ La commande '$cmd' est introuvable dans le PATH. Script interrompu."
            Log $msg
            Write-Host $msg -ForegroundColor Red
            Play-ErrorSound
            exit 1
        } else {
            Log "✅ Commande '$cmd' trouvée dans le PATH."
        }
    }
}

function Log-MavenVersion {
    Log "Vérification de la version de Maven..."
    try {
        $output = & mvn -v 2>&1
        $output | ForEach-Object { Log "Maven > $_" }
        Log "Code de retour : $LASTEXITCODE"
    } catch {
        Log "Erreur lors de la récupération de la version Maven : $_"
    }
}


function Play-SuccessSound {
    [System.Media.SystemSounds]::Asterisk.Play()
}

function Play-ErrorSound {
    [System.Media.SystemSounds]::Hand.Play()
}

# ───────────── Étapes principales ─────────────

function Pull-GitChanges {
    Log "Accès au dépôt Git local dans $gitRepoPath"
    Set-Location $gitRepoPath

    Log "Exécution de git pull origin master..."
    & git pull origin master *>> $OUT
    $exitCode = $LASTEXITCODE

    if ($exitCode -ne 0) {
        Log "❌ Échec de git pull (ExitCode: $exitCode)"
        return $false
    }
    $logContent = Get-Content $OUT -Tail 20
    if ($logContent -match "Already up to date" -or $logContent -match "À jour") {
        Log "Aucun changement détecté via git."
        return $false
    } else {
        Log "Changements détectés par git pull."
        return $true
    }
}

function Run-MavenBuild {
    Log "Démarrage du build Maven dans $gitRepoPath"
    Set-Location $gitRepoPath

    $args = "-DdistributionTargetDir=`"$tempBuildPath`" clean package"
    Log "Commande exécutée : mvn $args"

    & mvn $args *>> $OUT
    $exitCode = $LASTEXITCODE

    if ($exitCode -eq 0) {
        Log "✅ Build Maven terminé avec succès."
        return $true
    } else {
        Log "❌ Échec du build Maven (ExitCode: $exitCode)."
        return $false
    }
}

function Remove-OldBuild {
    Log "Suppression de l'ancien build ($buildPath)..."
    try {
        Remove-Item $buildPath -Recurse -Force -ErrorAction Stop
        Log "Dossier supprimé avec succès."
        return $true
    } catch {
        Log "Erreur lors de la suppression : $_"
        return $false
    }
}

function Promote-NewBuild {
    if (Test-Path $tempBuildPath) {
        try {
            Rename-Item -Path $tempBuildPath -NewName "build" -Force
            Log "Renommage réussi : _build → build"
        } catch {
            Log "Erreur lors du renommage : $_"
        }
    } else {
        Log "Le dossier temporaire '$tempBuildPath' est introuvable. Renommage annulé."
    }
}

# ───────────── Lancement du process ─────────────

Check-CommandAvailability -commands @("git", "mvn")
Log-MavenVersion

if (Pull-GitChanges) {
    if (Run-MavenBuild) {
        if (Remove-OldBuild) {
            Promote-NewBuild
            Play-SuccessSound
        } else {
            Log "Renommage annulé car la suppression du dossier existant a échoué."
            Play-ErrorSound
        }
    } else {
        Play-ErrorSound
    }
} else {
    Log "Aucune action requise (pas de changements Git)."
    Play-SuccessSound
}

Log-MavenVersion

# ───────────── Retour au répertoire racine ─────────────
Set-Location $rootPath
Log "Retour dans le répertoire racine $rootPath"
pause