param(
	[string]$ApkPath = "export/android/finetune-collector.apk",
	[string]$OutputPath = "",
	[string]$AndroidSdkPath = "",
	[string]$KeystorePath = "$env:USERPROFILE\.android\debug.keystore",
	[string]$KeyAlias = "androiddebugkey",
	[string]$StorePass = "android",
	[string]$KeyPass = "android",
	[switch]$ForceResign
)

$ErrorActionPreference = "Stop"

function Resolve-ApkSignerPath {
	param(
		[string]$SdkPath
	)

	$candidateSdkPaths = @()

	if ($SdkPath -ne "") {
		$candidateSdkPaths += $SdkPath
	}

	if ($env:ANDROID_SDK_ROOT) {
		$candidateSdkPaths += $env:ANDROID_SDK_ROOT
	}

	if ($env:ANDROID_HOME) {
		$candidateSdkPaths += $env:ANDROID_HOME
	}

	$localAndroidSdk = Join-Path $env:LOCALAPPDATA "Android\Sdk"
	if (Test-Path $localAndroidSdk) {
		$candidateSdkPaths += $localAndroidSdk
	}

	$candidateSdkPaths = $candidateSdkPaths | Select-Object -Unique

	foreach ($path in $candidateSdkPaths) {
		$buildToolsPath = Join-Path $path "build-tools"
		if (-not (Test-Path $buildToolsPath)) {
			continue
		}

		$apksigner = Get-ChildItem -Path $buildToolsPath -Directory |
			Sort-Object Name -Descending |
			ForEach-Object { Join-Path $_.FullName "apksigner.bat" } |
			Where-Object { Test-Path $_ } |
			Select-Object -First 1

		if ($apksigner) {
			return $apksigner
		}
	}

	throw "Kein apksigner gefunden. Setze -AndroidSdkPath oder ANDROID_SDK_ROOT korrekt."
}

function Ensure-DebugKeystore {
	param(
		[string]$Keystore,
		[string]$Alias,
		[string]$StorePassword,
		[string]$KeyPassword
	)

	if (Test-Path $Keystore) {
		return
	}

	$keytool = Get-Command keytool -ErrorAction SilentlyContinue
	if (-not $keytool) {
		throw "keytool nicht gefunden. Bitte Java JDK installieren oder Keystore manuell bereitstellen."
	}

	$keystoreDir = Split-Path $Keystore -Parent
	if ($keystoreDir -and -not (Test-Path $keystoreDir)) {
		New-Item -ItemType Directory -Path $keystoreDir -Force | Out-Null
	}

	& $keytool.Source `
		-genkeypair `
		-v `
		-keystore $Keystore `
		-storepass $StorePassword `
		-alias $Alias `
		-keypass $KeyPassword `
		-keyalg RSA `
		-keysize 2048 `
		-validity 10000 `
		-dname "CN=Godot, OU=Godot Engine, O=Stichting Godot, C=NL"

	if ($LASTEXITCODE -ne 0) {
		throw "Debug-Keystore konnte nicht erstellt werden."
	}
}

function Test-ApkSignature {
	param(
		[string]$ApkSignerPath,
		[string]$Apk
	)

	& $ApkSignerPath verify --verbose $Apk *> $null
	return $LASTEXITCODE -eq 0
}

$resolvedApkPath = (Resolve-Path $ApkPath).Path
$apksignerPath = Resolve-ApkSignerPath -SdkPath $AndroidSdkPath

$workApkPath = $resolvedApkPath
if ($OutputPath -ne "") {
	$outputDirectory = Split-Path $OutputPath -Parent
	if ($outputDirectory -and -not (Test-Path $outputDirectory)) {
		New-Item -ItemType Directory -Path $outputDirectory -Force | Out-Null
	}
	Copy-Item $resolvedApkPath $OutputPath -Force
	$workApkPath = (Resolve-Path $OutputPath).Path
}

$alreadySigned = Test-ApkSignature -ApkSignerPath $apksignerPath -Apk $workApkPath

if ($alreadySigned -and -not $ForceResign) {
	Write-Output "APK ist bereits signiert: $workApkPath"
	& $apksignerPath verify --verbose --print-certs $workApkPath
	exit $LASTEXITCODE
}

Ensure-DebugKeystore `
	-Keystore $KeystorePath `
	-Alias $KeyAlias `
	-StorePassword $StorePass `
	-KeyPassword $KeyPass

& $apksignerPath sign `
	--ks $KeystorePath `
	--ks-key-alias $KeyAlias `
	--ks-pass "pass:$StorePass" `
	--key-pass "pass:$KeyPass" `
	$workApkPath

if ($LASTEXITCODE -ne 0) {
	throw "APK konnte nicht signiert werden: $workApkPath"
}

& $apksignerPath verify --verbose --print-certs $workApkPath
if ($LASTEXITCODE -ne 0) {
	throw "APK-Signaturpruefung fehlgeschlagen: $workApkPath"
}

Write-Output "APK erfolgreich signiert: $workApkPath"
