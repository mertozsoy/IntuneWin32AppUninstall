# IntuneWin32AppUninstall

**IntuneWin32AppUninstall** is a PowerShell GUI tool that scans the Windows Registry for MSI-installed applications and automatically generates **Microsoft Intune-compatible Detection and Remediation scripts**.

## Features

- Scans both 32-bit and 64-bit Uninstall registry keys (`HKLM` and `HKCU`)
- Filters only MSI-based applications (those with a GUID-style Product Code)
- Displays installed applications in a modern WPF-based data grid with search, filtering, and multi-select
- For each selected application, generates ready-to-deploy scripts:
  - **Detect Script** (`*_Detect.ps1`) — checks if the application registry key exists; exits `0` (compliant) or `1` (non-compliant) for Intune
  - **Remediate Script** (`*_Remediate.ps1`) — silently uninstalls the application via `msiexec /X {GUID} /quiet /norestart` and logs results to `C:\Temp`
  - **README.md** — summary of application name, product code, and uninstall command
  - **AppInfo.json** — metadata about the generated package
- Context menu with quick actions: copy GUID, copy uninstall command, generate scripts or full package
- Export application list to CSV
- Generate individual scripts or full remediation packages into a folder of your choice
- Batch generation: select multiple apps and generate packages for all at once
- **Refresh** button (v1 only) to reload the application list without restarting

## How It Works

1. **Registry Scan** — The tool queries `HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall`, `HKLM\SOFTWARE\WOW6432Node\...`, and their `HKCU` equivalents. It collects `DisplayName`, `UninstallString`, and `ProductCode`.
2. **User Selection** — A WPF window presents the list. Select one or more apps, optionally search/filter.
3. **Script Generation** — When you click "Generate Remediation Package" (or use the context menu), the tool creates a folder per app containing:
   - `{SafeName}_Detect.ps1` — Intune detection script
   - `{SafeName}_Remediate.ps1` — Intune remediation script (silent uninstall)
   - `README.md` — human-readable summary
   - `AppInfo.json` — machine-readable metadata
4. **Intune Deployment** — Upload the Detect and Remediate scripts into Microsoft Intune as a **Detection and Remediation** policy under Endpoint Security.

## Generated Script Details

### Detect Script
- Searches for the product GUID under the Uninstall registry paths
- Exits with code `1` if the app exists (needs remediation)
- Exits with code `0` if not found (compliant)

### Remediate Script
- Runs `msiexec /X {GUID} /quiet /norestart`
- Waits for the process to finish
- Verifies whether the uninstall succeeded by checking the registry again
- Logs all steps to `C:\Temp\{AppName}_Removal.log`

## Requirements

- Windows (PowerShell 5.1+ required)
- .NET Framework 4.x (for WPF UI loading)
- Script execution policy that allows running PowerShell scripts

## Usage

```powershell
.\IntuneWin32AppUninstall.ps1
```

## Documentation

For detailed documentation and a web-based interface, visit: [https://mertozsoy.com/IntuneWin32AppUninstall/](https://mertozsoy.com/IntuneWin32AppUninstall/)

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Contributing

Contributions are welcome! Please see [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

## Code of Conduct

Please note that this project is released with a [Contributor Code of Conduct](CODE_OF_CONDUCT.md). By participating in this project you agree to abide by its terms.

## Author

**Mert Ozsoy**

- Website: [mertozsoy.com](https://www.mertozsoy.com)
- LinkedIn: [linkedin.com/in/mertozsoy365](https://www.linkedin.com/in/mertozsoy365/)
