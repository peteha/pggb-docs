# 🧰 Telegraf Installation and Configuration Guide (Windows)

This guide provides a step-by-step manual process to install and configure the open-source Telegraf agent on a Windows VM, optimized for integration with VMware Aria Operations.

**Disclaimer**
This is a guide only - refer to official documentation befor utilising in your own environment.

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
cd C:\Deploy\Temp
```

Example:
![](telegraf-opensource-deployment-windows/CleanShot%202025-05-29%20at%2008.00.17@2x.png)<!-- {"width":546} -->
---

## 🧾 Step 2: Create the .env File

Create a file named `.env` in `C:\Deploy\Temp` with the following contents. This file contains the credentials and endpoint used to authenticate with VMware Aria Operations.

```env
OPS_HOST=pgops.pggb.net
OPS_USERNAME=admin
OPS_PASSWORD=##$$VMware123
TOKEN_PATH=C:\\Deploy\\Temp\\auth_token.txt
OPS_PROXY=10.205.16.57
COLLECTION_GROUP=pggb
```

*> ⚠️ Keep this file secure, as it contains sensitive credentials.*

---

## 🧬 Step 3: Load Environment Variables

```powershell
$envVars = @{}
foreach ($line in Get-Content "C:\Deploy\Temp\.env" -Encoding ASCII) {
    if ($line -match '^\s*([^#][^=]*)=(.*)$') {
        $key = $matches[1].Trim()
        $val = $matches[2].Trim().Trim('"')
        $envVars[$key] = $val
    }
}
$envVars.GetEnumerator() | ForEach-Object { "$($_.Key) = $($_.Value)" }
```

Example:
![](telegraf-opensource-deployment-windows/CleanShot%202025-05-29%20at%2008.01.37@2x.png)<!-- {"width":546} -->

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

Example:
![](telegraf-opensource-deployment-windows/CleanShot%202025-05-29%20at%2007.59.06@2x.png)<!-- {"width":687} -->

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
  -Body ($Cred | ConvertTo-Json)

if (-not $TokenResponse.token) {
    Write-Error "Failed to retrieve auth token. Check credentials or network access."
    exit 1
}

$TokenResponse.token | Out-File -FilePath $envVars["TOKEN_PATH"] -Encoding ascii
```

Example:
![](telegraf-opensource-deployment-windows/CleanShot%202025-05-29%20at%2007.55.59@2x.png)<!-- {"width":592} -->
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

Example:
![](telegraf-opensource-deployment-windows/CleanShot%202025-05-29%20at%2007.40.57@2x.png)<!-- {"width":554} -->
*Error does not impact deployment - if successful it should say “Telegraf configuration to post metrics to cloud proxy succeeded. Please restart telegraf.”*
## Step 8: Register Telegraf

```powershell
& "C:\Program Files\InfluxData\telegraf\telegraf-1.34.4\telegraf.exe" `
  --config "C:\Program Files\InfluxData\telegraf\telegraf-1.34.4\telegraf.conf" `
  --config-directory "C:\Program Files\InfluxData\telegraf\telegraf.d" `
  service install
```

Example:
![](telegraf-opensource-deployment-windows/CleanShot%202025-05-29%20at%2007.43.06@2x.png)<!-- {"width":554} -->


## Step 9: Start Telegraf

```powershell
net start telegraf
```

Example:
![](telegraf-opensource-deployment-windows/CleanShot%202025-05-29%20at%2007.48.23@2x.png)<!-- {"width":360} -->

## Step 10:

After a couple of collections cycles the agent should show as deployed in the the Ops console under Operations —> Applications —> Manage Telegraf Agents.
![](telegraf-opensource-deployment-windows/CleanShot%202025-05-29%20at%2007.52.39@2x.png)<!-- {"width":938} -->
Green tick in a circle confirms data is being collected.

---

## ✅ Final Notes

- Run all commands in an elevated PowerShell session.
- Ensure network access to the required VMware Aria Operations API endpoints.
- Monitor logs for success or troubleshooting.

- - -
## Resources

### Overview of Telegraf Integration

Comprehensive guide on integrating open-source Telegraf with VMware Aria Operations:
- 📘 [Monitoring Application Services and Operating Systems using Open Source Telegraf](https://techdocs.broadcom.com/us/en/vmware-cis/aria/aria-operations/8-18/vmware-aria-operations-configuration-guide-8-18/connect-to-data-sources/monitoring-applications-and-os-using-open-source-telegraf.html)

### Install and Configure Open Source Telegraf

Step-by-step instructions for setting up Telegraf:
- 🔧 [Install and Configure Open Source Telegraf](https://techdocs.broadcom.com/us/en/vmware-cis/aria/aria-operations/8-18/vmware-aria-operations-configuration-guide-8-18/connect-to-data-sources/monitoring-applications-and-os-using-open-source-telegraf/monitoring-applications-using-open-source-telegraf/install-and-configure-open-source-telegraf.html)

### Windows Platform Guide

Platform-specific instructions for Windows environments:
- 🪟 [Monitoring Applications using Open Source Telegraf on a Windows Platform](https://techdocs.broadcom.com/us/en/vmware-cis/aria/aria-operations/8-18/vmware-aria-operations-configuration-guide-8-18/connect-to-data-sources/monitoring-applications-and-os-using-open-source-telegraf/monitoring-applications-using-open-source-telegraf/monitoring-applications-using-open-source-telegraf-on-a-windows-platform-saas-onprem.html)

### Sample Scripts and Configurations

Example config files and scripts:
- 💾 [Sample Scripts and Configurations](https://techdocs.broadcom.com/us/en/vmware-cis/aria/aria-operations/8-18/vmware-aria-operations-configuration-guide-8-18/connect-to-data-sources/monitoring-applications-and-os-using-open-source-telegraf/monitoring-applications-using-open-source-telegraf/sample-scripts-open-source-telegraf.html)

Common issues and resolutions:
- 🛠️ [Telegraf Troubleshooting](https://techdocs.broadcom.com/us/en/ca-enterprise-software/it-operations-management/vmware-aria-operations-for-applications/saas/telegraf_details.html)

### Broadcom Support Portal

Downloads and documentation:
- 🌐 [Broadcom Support Downloads](https://www.broadcom.com/support/download-search)

