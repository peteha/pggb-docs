# 🧰 Telegraf Installation and Configuration Guide (Windows)

This guide provides a step-by-step manual process to install and configure the open-source Telegraf agent on a Windows VM, optimized for integration with VMware Aria Operations.

## Pre-Requisites

### 1. VCF Operations Collection Proxy and Collector Group

Telegraf requires an additional proxy collector which the Telegraf agents connect to.  The following is a screenshot of the proxy used in the example.

![](telegraf-opensource-deployment-windows/CleanShot%202025-05-29%20at%2006.42.42@2x.png)<!-- {"width":755} -->

The proxy is added to a collector group.   In my example I am using a non-HA collector group called ‘pggb’.  The following is the screen shot of my example collector group.
![](telegraf-opensource-deployment-windows/CleanShot%202025-05-29%20at%2006.46.03@2x.png)<!-- {"width":749} -->


### 

---

## 📁 Step 1: Create Required Directories

```powershell
New-Item -ItemType Directory -Force -Path "C:\Deploy\Temp"
New-Item -ItemType Directory -Force -Path "C:\Program Files\InfluxData\telegraf"
New-Item -ItemType Directory -Force -Path "C:\Program Files\InfluxData\telegraf\telegraf.d"
```

---

## 🧾 Step 2: Create the .env File

Create a file named `.env` in `C:\Deploy\Temp` with the following contents. This file contains the credentials and endpoint used to authenticate with VMware Aria Operations.

```env
OPS_HOST=pgops.pggb.net
OPS_USERNAME=admin
OPS_PASSWORD=##$$VMware123
TOKEN_PATH=C:\Deploy\Temp\auth_token.txt
OPS_PROXY=10.205.16.57
COLLECTION_GROUP=pggb
```

*> ⚠️ Keep this file secure, as it contains sensitive credentials.*

---

## 🧬 Step 3: Load Environment Variables

```powershell
$envFile = "C:\Deploy\Temp\.env"
$envVars = Get-Content $envFile -Encoding ASCII | Where-Object { $_ -match "=" } | ConvertFrom-StringData
```

---

## ⬇️ Step 4: Download and Extract Telegraf

```powershell
if (-Not (Test-Path "C:\Deploy\Temp\telegraf.zip")) {
    curl.exe -L -o "C:\Deploy\Temp\telegraf.zip" https://dl.influxdata.com/telegraf/releases/telegraf-1.34.4_windows_amd64.zip
}
Expand-Archive -Path "C:\Deploy\Temp\telegraf.zip" -DestinationPath "C:\Program Files\InfluxData\telegraf"
```

---

## ⚙️ Step 5: Download Telegraf Utility Script

```powershell
curl.exe -k -L -o "C:\Deploy\Temp\telegraf-utils.ps1" https://$($envVars["OPS_PROXY"])/downloads/salt/telegraf-utils.ps1
```

---

## 🔑 Step 6: Acquire Auth Token

This step reads credentials from a `.env` file and uses them to retrieve a token.

```powershell
$Cred = @{
  username = $envVars["OPS_USERNAME"]
  password = $envVars["OPS_PASSWORD"]
}

$TokenResponse = Invoke-RestMethod -Method Post `
  -Uri "https://$($envVars["OPS_HOST"])/suite-api/api/auth/token/acquire?_no_links=true" `
  -Headers @{ "accept" = "application/json"; "Content-Type" = "application/json" } `
  -Body ($Cred | ConvertTo-Json) `
  -SkipCertificateCheck

if (-not $TokenResponse.token) {
    Write-Error "Failed to retrieve auth token. Check credentials or network access."
    exit 1
}

$TokenResponse.token | Out-File -FilePath $envVars["TOKEN_PATH"] -Encoding ascii
```

*> Ensure the* `.env` *file exists before running this step.*

---

## 📝 Step 7: Configure Telegraf with the Token

```powershell
# Read token
$token = Get-Content $envVars["TOKEN_PATH"]

# Run Telegraf configuration script
powershell -ExecutionPolicy Bypass -File "C:\Deploy\Temp\telegraf-utils.ps1" `
  opensource `
  -c $envVars["COLLECTION_GROUP"] `
  -t $token `
  -d "C:\Program Files\InfluxData\telegraf\telegraf.d" `
  -e "C:\Program Files\InfluxData\telegraf\telegraf-1.34.4\telegraf.exe" `
  -v $envVars["OPS_HOST"]
```


---

## ✅ Final Notes

- Run all commands in an elevated PowerShell session.
- Ensure network access to the required VMware Aria Operations API endpoints.
- Monitor logs for success or troubleshooting.
