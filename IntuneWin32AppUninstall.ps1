<#PSScriptInfo

.VERSION 1.0.1

.GUID 328ab807-c501-40bc-94ba-7540a9029885

.AUTHOR Mert Ozsoy

.COMPANYNAME Mert Ozsoy

.COPYRIGHT (c) Mert Ozsoy

.TAGS Intune Uninstall Remediation

.LICENSEURI https://opensource.org/licenses/MIT

.PROJECTURI https://www.mertozsoy.com

.RELEASENOTES
Initial release.

#>

<#
.SYNOPSIS
Creates Intune detection and remediation scripts for application uninstallation.

.DESCRIPTION
Creates Intune detection and remediation scripts for application uninstallation.
#>

#requires -version 5.1

<#
.SCRIPT INFO
    Author   : Mert Ozsoy
    Website  : https://www.mertozsoy.com
    LinkedIn : https://www.linkedin.com/in/mertozsoy365/
#>


Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase, System.Xaml
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

#region İş Mantığı (değişmedi)

function Convert-ToSafeName {
    param([string]$Name)

    $Name = $Name -replace '\+\+', 'PlusPlus'
    $Name = $Name -replace '7-Zip', 'SevenZip'
    $Name = $Name -replace '[^a-zA-Z0-9]', ''

    if ([string]::IsNullOrWhiteSpace($Name)) {
        $Name = 'Application'
    }

    return $Name
}

function Get-Applications {
    $apps = [System.Collections.Generic.List[PSObject]]::new()

    $registryPaths = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKCU:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
    )

    foreach ($path in $registryPaths) {
        Get-ItemProperty -Path $path -ErrorAction SilentlyContinue | ForEach-Object {
            if ([string]::IsNullOrWhiteSpace($_.DisplayName)) { return }
            if ([string]::IsNullOrWhiteSpace($_.UninstallString)) { return }
            if ($_.UninstallString -match '\{[A-Fa-f0-9\-]{36}\}') {
                $apps.Add([PSCustomObject]@{
                    ApplicationName = $_.DisplayName
                    ProductCode     = $Matches[0]
                    UninstallString = $_.UninstallString
                })
            }
        }
    }

    return $apps | Sort-Object ApplicationName
}

function Select-Folder {
    $browser = New-Object System.Windows.Forms.FolderBrowserDialog
    $browser.Description = "Select Output Folder"
    if ($browser.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        return $browser.SelectedPath
    }
    return $null
}

function New-DetectContent {
    param($App)

    return @"
<#
.SCRIPT INFO
    Author   : Mert Ozsoy
    Website  : www.mertozsoy.com
    LinkedIn : https://www.linkedin.com/in/mertozsoy365/
#>

`$AppGUID = "$($App.ProductCode)"

`$Found = Get-ChildItem ``
"HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall",
"HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall" -ErrorAction SilentlyContinue |
Where-Object { `$_.PSChildName -eq `$AppGUID }

if (`$Found) {
    Write-Output "$($App.ApplicationName) bulundu."
    exit 1
}
else {
    Write-Output "$($App.ApplicationName) bulunamadi."
    exit 0
}
"@
}

function New-RemediateContent {
    param($App)

    $logName = $App.ApplicationName -replace '\s', '_'

    return @"
<#
.SCRIPT INFO
    Author   : Mert Ozsoy
    Website  : www.mertozsoy.com
    LinkedIn : https://www.linkedin.com/in/mertozsoy365/
#>

`$LogFolder = "C:\Temp"
`$LogFile = "`$LogFolder\$logName`_Removal.log"
`$AppGUID = "$($App.ProductCode)"

if (!(Test-Path `$LogFolder)) {
    New-Item -Path `$LogFolder -ItemType Directory -Force | Out-Null
}

`$TimeStamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

Add-Content -Path `$LogFile -Value "[`$TimeStamp] Remediation basladi."

`$Found = Get-ChildItem ``
"HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall",
"HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall" -ErrorAction SilentlyContinue |
Where-Object { `$_.PSChildName -eq `$AppGUID }

if (`$Found) {

    Add-Content -Path `$LogFile -Value "[`$TimeStamp] $($App.ApplicationName) bulundu. Kaldirma baslatiliyor."

    `$Process = Start-Process msiexec.exe ``
        -ArgumentList "/X `$AppGUID /quiet /norestart" ``
        -Wait ``
        -PassThru

    `$TimeStamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

    Add-Content -Path `$LogFile -Value "[`$TimeStamp] Msiexec ExitCode: `$(`$Process.ExitCode)"

    Start-Sleep -Seconds 10

    `$StillExists = Get-ChildItem ``
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall",
    "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall" -ErrorAction SilentlyContinue |
    Where-Object { `$_.PSChildName -eq `$AppGUID }

    if (`$StillExists) {
        Add-Content -Path `$LogFile -Value "[`$TimeStamp] Kaldirma basarisiz."
    }
    else {
        Add-Content -Path `$LogFile -Value "[`$TimeStamp] Kaldirma basarili."
    }
}
else {
    Add-Content -Path `$LogFile -Value "[`$TimeStamp] Uygulama zaten kurulu degil."
}
"@
}

function New-README {
    param($App)

    $safeName = Convert-ToSafeName $App.ApplicationName
    $policyName = "Remove_$safeName"

    return @"
Application Name : $($App.ApplicationName)
Product Code    : $($App.ProductCode)
Policy Name     : $policyName

Uninstall Command:
MsiExec.exe /X$($App.ProductCode) /quiet /norestart

---
Script Info
Author   : Mert Ozsoy
Website  : www.mertozsoy.com
LinkedIn : https://www.linkedin.com/in/mertozsoy365/
"@
}

function New-AppInfoJson {
    param($App)

    $safeName = Convert-ToSafeName $App.ApplicationName
    $policyName = "Remove_$safeName"

    return [PSCustomObject]@{
        ApplicationName = $App.ApplicationName
        ProductCode     = $App.ProductCode
        PolicyName      = $policyName
        UninstallString = $App.UninstallString
        GeneratedOn     = [DateTime]::Now.ToString("yyyy-MM-dd HH:mm:ss")
    } | ConvertTo-Json
}

function New-Package {
    param($Apps, $ParentFolder)

    $createdFolders = [System.Collections.Generic.List[string]]::new()

    foreach ($app in $Apps) {
        try {
            $safeName = Convert-ToSafeName $app.ApplicationName
            $targetFolder = Join-Path -Path $ParentFolder -ChildPath "Remove_$safeName"

            New-Item -ItemType Directory -Path $targetFolder -Force | Out-Null

            Set-Content -Path (Join-Path $targetFolder "$safeName`_Detect.ps1") -Value (New-DetectContent $app) -Encoding UTF8
            Set-Content -Path (Join-Path $targetFolder "$safeName`_Remediate.ps1") -Value (New-RemediateContent $app) -Encoding UTF8
            Set-Content -Path (Join-Path $targetFolder "README.md") -Value (New-README $app) -Encoding UTF8
            Set-Content -Path (Join-Path $targetFolder "AppInfo.json") -Value (New-AppInfoJson $app) -Encoding UTF8

            $createdFolders.Add($targetFolder)
        } catch {
            [System.Windows.Forms.MessageBox]::Show(
                "Failed to generate package for: $($app.ApplicationName)`n`n$_",
                "Error",
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Error
            )
        }
    }

    return $createdFolders
}

#endregion İş Mantığı

#region Veri Yükleme

$script:allApps = Get-Applications

if ($script:allApps.Count -eq 0) {
    [System.Windows.Forms.MessageBox]::Show(
        "No MSI applications found in registry.",
        "No Applications",
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Information
    )
    return
}

#endregion Veri Yükleme

#region XAML Tanımı

[xml]$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="AtaUninstallPack"
        Width="1200" Height="920" MinWidth="960" MinHeight="600"
        Background="#F9F9F9"
        FontFamily="Segoe UI"
        WindowStartupLocation="CenterScreen"
        TextElement.Foreground="#1A1C1C"
        SnapsToDevicePixels="True"
        UseLayoutRounding="True">
    <Window.Resources>
        <Style x:Key="IconButton" TargetType="Button">
            <Setter Property="Background" Value="Transparent"/>
            <Setter Property="BorderThickness" Value="0"/>
            <Setter Property="Padding" Value="8,4"/>
            <Setter Property="FontSize" Value="18"/>
            <Setter Property="Foreground" Value="#404752"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border Background="{TemplateBinding Background}" CornerRadius="8" Padding="{TemplateBinding Padding}">
                            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter Property="Background" Value="#E8E8E8"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>
        <Style x:Key="SecondaryButton" TargetType="Button">
            <Setter Property="Background" Value="White"/>
            <Setter Property="Foreground" Value="#1A1C1C"/>
            <Setter Property="BorderBrush" Value="#C0C7D4"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="Padding" Value="12,6"/>
            <Setter Property="FontSize" Value="14"/>
            <Setter Property="FontWeight" Value="500"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}" BorderThickness="{TemplateBinding BorderThickness}" CornerRadius="8" Padding="{TemplateBinding Padding}">
                            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter Property="Background" Value="#F3F3F3"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>
        <Style TargetType="DataGridRow">
            <Setter Property="Background" Value="Transparent"/>
            <Setter Property="BorderBrush" Value="#E0E0E0"/>
            <Setter Property="BorderThickness" Value="0,0,0,1"/>
            <Setter Property="VerticalAlignment" Value="Center"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="MinHeight" Value="44"/>
            <Style.Triggers>
                <Trigger Property="IsMouseOver" Value="True">
                    <Setter Property="Background" Value="#F0F4F8"/>
                </Trigger>
                <Trigger Property="IsSelected" Value="True">
                    <Setter Property="Background" Value="#E8F0FE"/>
                </Trigger>
            </Style.Triggers>
        </Style>
        <Style TargetType="DataGridCell">
            <Setter Property="BorderThickness" Value="0"/>
            <Setter Property="Padding" Value="16,8"/>
            <Setter Property="VerticalAlignment" Value="Center"/>
            <Setter Property="FontSize" Value="14"/>
            <Style.Triggers>
                <Trigger Property="IsSelected" Value="True">
                    <Setter Property="Background" Value="Transparent"/>
                    <Setter Property="BorderBrush" Value="Transparent"/>
                </Trigger>
            </Style.Triggers>
        </Style>
        <Style TargetType="DataGridColumnHeader">
            <Setter Property="Background" Value="White"/>
            <Setter Property="BorderBrush" Value="#E0E0E0"/>
            <Setter Property="BorderThickness" Value="0,0,0,1"/>
            <Setter Property="Padding" Value="16,14"/>
            <Setter Property="HorizontalContentAlignment" Value="Left"/>
            <Setter Property="FontSize" Value="12"/>
            <Setter Property="FontWeight" Value="600"/>
            <Setter Property="Foreground" Value="#404752"/>
            <Setter Property="Height" Value="48"/>
        </Style>
    </Window.Resources>
    <Grid>
        <Grid.RowDefinitions>
            <RowDefinition Height="64"/>
            <RowDefinition Height="*"/>
            <RowDefinition Height="32"/>
        </Grid.RowDefinitions>
        <!-- ===== BAŞLIK ===== -->
        <Border Grid.Row="0" Background="#F9F9F9" BorderBrush="#C0C7D4" BorderThickness="0,0,0,1">
            <Grid Margin="32,0">
                <Grid.ColumnDefinitions>
                    <ColumnDefinition Width="Auto"/>
                    <ColumnDefinition Width="*"/>
                    <ColumnDefinition Width="Auto"/>
                </Grid.ColumnDefinitions>
                <StackPanel Grid.Column="0" Orientation="Horizontal" VerticalAlignment="Center">
                    <TextBlock Margin="0,0,0,0" Text="AtaUninstallPack" FontSize="20" FontWeight="600" VerticalAlignment="Center" Foreground="#1A1C1C"/>
                </StackPanel>
                <Border Grid.Column="1" Height="36" CornerRadius="6" Background="#EEEEEE" Margin="48,0,48,0">
                    <Grid>
                        <TextBlock Text="🔍" Margin="10,0,0,0" VerticalAlignment="Center" FontSize="14"/>
                        <TextBox x:Name="SearchBox" Margin="34,0,0,0" Background="Transparent" BorderThickness="0" VerticalAlignment="Center" FontSize="14" Foreground="#1A1C1C" Padding="0"/>
                    </Grid>
                </Border>
                <StackPanel Grid.Column="2" Orientation="Horizontal" VerticalAlignment="Center">
                    <Border CornerRadius="14" Background="#D3E3FF" Padding="14,4" Height="28" VerticalAlignment="Center">
                        <StackPanel Orientation="Horizontal" VerticalAlignment="Center">
                            <TextBlock Text="📦" FontSize="13" VerticalAlignment="Center"/>
                            <TextBlock x:Name="HeaderAppCount" Margin="6,0,0,0" FontSize="12" FontWeight="500" Foreground="#001C39" VerticalAlignment="Center"/>
                        </StackPanel>
                    </Border>

                </StackPanel>
            </Grid>
        </Border>
        <!-- ===== ANA İÇERİK ===== -->
        <Grid Grid.Row="1" Margin="32,16,32,16">
            <Grid.ColumnDefinitions>
                <ColumnDefinition Width="70*"/>
                <ColumnDefinition Width="30*"/>
            </Grid.ColumnDefinitions>
            <!-- Left: Application Grid -->
            <Border x:Name="LeftCardBorder" Grid.Column="0" CornerRadius="12" Background="White" BorderBrush="#D0D0D0" BorderThickness="1">
                <Grid>
                    <Grid.RowDefinitions>
                        <RowDefinition Height="Auto"/>
                        <RowDefinition Height="*"/>
                    </Grid.RowDefinitions>
                    <Border Grid.Row="0" BorderBrush="#E0E0E0" BorderThickness="0,0,0,1" Background="#F5F5F5" Padding="24,16">
                        <Grid>
                            <Grid.ColumnDefinitions>
                                <ColumnDefinition Width="*"/>
                                <ColumnDefinition Width="Auto"/>
                            </Grid.ColumnDefinitions>
                            <TextBlock Grid.Column="0" Text="Installed Applications" FontSize="20" FontWeight="600" Foreground="#1A1C1C" VerticalAlignment="Center"/>
                            <StackPanel Grid.Column="1" Orientation="Horizontal">
                                <Button x:Name="RefreshButton" Content="↻ Refresh" Style="{StaticResource SecondaryButton}"/>
                                <Button x:Name="ExportButton" Content="↓ Export" Style="{StaticResource SecondaryButton}"/>
                            </StackPanel>
                        </Grid>
                    </Border>
                    <DataGrid x:Name="AppDataGrid" Grid.Row="1"
                              AutoGenerateColumns="False"
                              SelectionMode="Extended"
                              SelectionUnit="FullRow"
                              IsReadOnly="False"
                              HeadersVisibility="Column"
                              GridLinesVisibility="None"
                              Background="White"
                              BorderThickness="0"
                              VirtualizingStackPanel.IsVirtualizing="True"
                              VirtualizingStackPanel.VirtualizationMode="Recycling"
                              RowHeaderWidth="0"
                              FontFamily="Segoe UI"
                              Foreground="#1A1C1C">
                        <DataGrid.Resources>
                            <Style TargetType="DataGridRow" BasedOn="{StaticResource {x:Type DataGridRow}}"/>
                            <Style TargetType="DataGridCell" BasedOn="{StaticResource {x:Type DataGridCell}}">
                                <Setter Property="Foreground" Value="#1A1C1C"/>
                                <Style.Triggers>
                                    <Trigger Property="IsSelected" Value="True">
                                        <Setter Property="Background" Value="#D3E3FF"/>
                                        <Setter Property="Foreground" Value="#1A1C1C"/>
                                    </Trigger>
                                </Style.Triggers>
                            </Style>
                            <Style TargetType="DataGridColumnHeader" BasedOn="{StaticResource {x:Type DataGridColumnHeader}}"/>
                        </DataGrid.Resources>
                        <DataGrid.Columns>
                            <DataGridTemplateColumn Header=" " Width="56">
                                <DataGridTemplateColumn.CellTemplate>
                                    <DataTemplate>
                                        <CheckBox IsChecked="{Binding RelativeSource={RelativeSource AncestorType=DataGridRow}, Path=IsSelected}"
                                                  HorizontalAlignment="Center"
                                                  VerticalAlignment="Center"/>
                                    </DataTemplate>
                                </DataGridTemplateColumn.CellTemplate>
                            </DataGridTemplateColumn>
                            <DataGridTextColumn Header="Application Name" Binding="{Binding ApplicationName}" Width="3*" IsReadOnly="True">
                                <DataGridTextColumn.ElementStyle>
                                    <Style>
                                        <Setter Property="TextBlock.FontWeight" Value="500"/>
                                        <Setter Property="TextBlock.VerticalAlignment" Value="Center"/>
                                        <Setter Property="TextBlock.Margin" Value="0,0,0,0"/>
                                    </Style>
                                </DataGridTextColumn.ElementStyle>
                            </DataGridTextColumn>
                            <DataGridTextColumn Header="Product Code" Binding="{Binding ProductCode}" Width="2*" IsReadOnly="True">
                                <DataGridTextColumn.ElementStyle>
                                    <Style>
                                        <Setter Property="TextBlock.FontFamily" Value="Consolas"/>
                                        <Setter Property="TextBlock.FontSize" Value="12"/>
                                        <Setter Property="TextBlock.Foreground" Value="#717783"/>
                                        <Setter Property="TextBlock.VerticalAlignment" Value="Center"/>
                                    </Style>
                                </DataGridTextColumn.ElementStyle>
                            </DataGridTextColumn>
                            <DataGridTextColumn Header="Uninstall Command" Binding="{Binding UninstallString}" Width="3*" IsReadOnly="True">
                                <DataGridTextColumn.ElementStyle>
                                    <Style>
                                        <Setter Property="TextBlock.Foreground" Value="#404752"/>
                                        <Setter Property="TextBlock.VerticalAlignment" Value="Center"/>
                                    </Style>
                                </DataGridTextColumn.ElementStyle>
                            </DataGridTextColumn>
                        </DataGrid.Columns>
                    </DataGrid>
                </Grid>
            </Border>
            <!-- Sağ: Detay Paneli -->
            <StackPanel Grid.Column="1" Margin="16,0,0,0">
                <Border x:Name="RightCardBorder" CornerRadius="12" Background="White" BorderBrush="#D0D0D0" BorderThickness="1">
                    <StackPanel>
                        <Border BorderBrush="#E0E0E0" BorderThickness="0,0,0,1" Padding="24,20" Background="#F0F6FF">
                            <StackPanel>
                                <StackPanel Orientation="Horizontal">
                                    <TextBlock Text="&#x2139;" FontSize="20" Foreground="#005FAA" VerticalAlignment="Center"/>
                                    <TextBlock Margin="12,0,0,0" Text="Application Details" FontSize="20" FontWeight="600" Foreground="#1A1C1C" VerticalAlignment="Center"/>
                                </StackPanel>
                                <TextBlock Margin="32,8,0,0" Text="Review the selected application data before generating the remediation package." FontSize="14" Foreground="#404752" TextWrapping="Wrap"/>
                            </StackPanel>
                        </Border>
                        <StackPanel Margin="24,24,24,0">
                            <StackPanel>
                                <TextBlock Text="Application Name" FontSize="12" FontWeight="500" Foreground="#717783" Margin="0,0,0,4"/>
                                <TextBlock x:Name="DetailAppName" Text="-" FontSize="16" FontWeight="600" Foreground="#1A1C1C"/>
                            </StackPanel>
                            <StackPanel Margin="0,20,0,0">
                                <TextBlock Text="Product Code" FontSize="12" FontWeight="500" Foreground="#717783" Margin="0,0,0,4"/>
                                <Border Padding="10" Background="#F3F3F3" CornerRadius="8" BorderBrush="#C0C7D4" BorderThickness="1">
                                    <TextBlock x:Name="DetailProductCode" Text="-" FontFamily="Consolas" FontSize="12" Foreground="#1A1C1C" TextWrapping="Wrap"/>
                                </Border>
                            </StackPanel>
                            <StackPanel Margin="0,20,0,0">
                                <TextBlock Text="Uninstall Command" FontSize="12" FontWeight="500" Foreground="#717783" Margin="0,0,0,4"/>
                                <Border Padding="10" Background="#F3F3F3" CornerRadius="8" BorderBrush="#C0C7D4" BorderThickness="1">
                                    <TextBlock x:Name="DetailUninstallCmd" Text="-" FontFamily="Consolas" FontSize="12" Foreground="#1A1C1C" TextWrapping="Wrap"/>
                                </Border>
                            </StackPanel>
                            <StackPanel Margin="0,20,0,0">
                                <Border BorderBrush="#E0E0E0" BorderThickness="0,1,0,0" Padding="0,16,0,0">
                                    <StackPanel>
                                        <TextBlock Text="Generated Policy Name" FontSize="12" FontWeight="700" Foreground="#005FAA" Margin="0,0,0,8"/>
                                        <Border CornerRadius="8" BorderBrush="#C0C7D4" BorderThickness="1" Background="#EEEEEE">
                                            <TextBox x:Name="DetailPolicyName" Text="-" Padding="12,8" FontSize="14" Foreground="#1A1C1C" Background="Transparent" BorderThickness="0"/>
                                        </Border>
                                        <TextBlock Margin="0,4,0,0" Text="This name will be used in Intune for the script configuration." FontSize="11" Foreground="#717783" TextWrapping="Wrap"/>
                                    </StackPanel>
                                </Border>
                            </StackPanel>
                        </StackPanel>
                        <Border BorderBrush="#E0E0E0" BorderThickness="0,1,0,0" Margin="0,24,0,0" Background="#F5F5F5" Padding="24,16">
                            <StackPanel>
                                <Button x:Name="GeneratePackageButton" Content="Generate Remediation Package" Height="44" Margin="0,0,0,0"
                                        Background="#005FAA" Foreground="White" FontSize="16" FontWeight="600" Cursor="Hand"
                                        BorderThickness="0">
                                    <Button.Style>
                                        <Style TargetType="Button">
                                            <Setter Property="Template">
                                                <Setter.Value>
                                                    <ControlTemplate TargetType="Button">
                                                        <Border x:Name="border" Background="{TemplateBinding Background}" CornerRadius="8" Padding="{TemplateBinding Padding}">
                                                            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                                                        </Border>
                                                        <ControlTemplate.Triggers>
                                                            <Trigger Property="IsMouseOver" Value="True">
                                                                <Setter TargetName="border" Property="Background" Value="#0078D4"/>
                                                            </Trigger>
                                                        </ControlTemplate.Triggers>
                                                    </ControlTemplate>
                                                </Setter.Value>
                                            </Setter>
                                        </Style>
                                    </Button.Style>
                                </Button>
                                <Grid Margin="0,12,0,0">
                                    <Grid.ColumnDefinitions>
                                        <ColumnDefinition Width="*"/>
                                        <ColumnDefinition Width="*"/>
                                    </Grid.ColumnDefinitions>
                                    <Grid.RowDefinitions>
                                        <RowDefinition Height="Auto"/>
                                        <RowDefinition Height="Auto"/>
                                    </Grid.RowDefinitions>
                                    <Button x:Name="CopyGuidButton" Grid.Column="0" Grid.Row="0" Content="Copy GUID" Height="36" Margin="0,0,4,8" Style="{StaticResource SecondaryButton}" FontSize="12"/>
                                    <Button x:Name="CopyCommandButton" Grid.Column="1" Grid.Row="0" Content="Copy Command" Height="36" Margin="4,0,0,8" Style="{StaticResource SecondaryButton}" FontSize="12"/>
                                    <Button x:Name="OpenOutputFolderButton" Grid.Column="0" Grid.Row="1" Grid.ColumnSpan="2" Content="Open Output Folder" Height="36" Style="{StaticResource SecondaryButton}" FontSize="12"/>
                                </Grid>
                            </StackPanel>
                        </Border>
                    </StackPanel>
                </Border>
                <Border Margin="0,16,0,0" Padding="16" CornerRadius="12" Background="#F0EEFF" BorderBrush="#B9C3FF" BorderThickness="1">
                    <StackPanel Orientation="Horizontal">
                        <TextBlock Text="&#x1F4A1;" FontSize="20" Foreground="#304ED0" VerticalAlignment="Top"/>
                        <StackPanel Margin="12,0,0,0">
                            <TextBlock Text="Expert Tip" FontSize="12" FontWeight="500" Foreground="#0D35BB" Margin="0,0,0,4"/>
                            <TextBlock Text="You can select multiple applications to batch generate remediation scripts into a single directory." FontSize="11" Foreground="#404752" TextWrapping="Wrap"/>
                        </StackPanel>
                    </StackPanel>
                </Border>
            </StackPanel>
        </Grid>
        <!-- ===== ALT BİLGİ ===== -->
        <Border Grid.Row="2" Background="#EEEEEE" BorderBrush="#C0C7D4" BorderThickness="0,1,0,0" Padding="32,0">
            <TextBlock HorizontalAlignment="Center" VerticalAlignment="Center" FontSize="12" Foreground="#404752">
                Made with <Run Text="❤️" FontSize="14"/> by <Hyperlink x:Name="FooterLink" NavigateUri="https://mertozsoy.com" Foreground="#005FAA" FontWeight="700" TextDecorations="None">Mert Ozsoy</Hyperlink>
            </TextBlock>
        </Border>
    </Grid>
</Window>
"@

#endregion XAML Tanımı

#region XAML Yükle

$reader = [System.Xml.XmlNodeReader]::new($xaml)
try {
    $window = [Windows.Markup.XamlReader]::Load($reader)
} catch {
    Write-Host "XAML Load Error: $_" -ForegroundColor Red
    [System.Windows.Forms.MessageBox]::Show("Failed to load UI. Error: $_", "XAML Error")
    return
}

#endregion XAML Yükle

#region Kontrol Referansları

$searchBox = $window.FindName("SearchBox")
$AppDataGrid = $window.FindName("AppDataGrid")
$headerAppCount = $window.FindName("HeaderAppCount")
$detailAppName = $window.FindName("DetailAppName")
$detailProductCode = $window.FindName("DetailProductCode")
$detailUninstallCmd = $window.FindName("DetailUninstallCmd")
$detailPolicyName = $window.FindName("DetailPolicyName")
$generatePackageButton = $window.FindName("GeneratePackageButton")
$copyGuidButton = $window.FindName("CopyGuidButton")
$copyCommandButton = $window.FindName("CopyCommandButton")
$openOutputFolderButton = $window.FindName("OpenOutputFolderButton")
$exportButton = $window.FindName("ExportButton")
$refreshButton = $window.FindName("RefreshButton")

# Tümünü Seç onay kutusu (programlı başlık)
$script:updatingSelectAll = $false
$selectAllCheckBox = New-Object System.Windows.Controls.CheckBox
$selectAllCheckBox.HorizontalAlignment = "Center"
$selectAllCheckBox.VerticalAlignment = "Center"
$selectAllCheckBox.IsThreeState = $true
$AppDataGrid.Columns[0].Header = $selectAllCheckBox

$selectAllCheckBox.Add_Checked({
    if (-not $script:updatingSelectAll -and $selectAllCheckBox.IsChecked -eq $true) {
        $AppDataGrid.SelectAll()
    }
})

$selectAllCheckBox.Add_Unchecked({
    if (-not $script:updatingSelectAll) {
        $AppDataGrid.SelectedItems.Clear()
    }
})

# Yuvarlak kartlarda içerik taşmasını önlemek için köşe kırpma uygula
$leftCardBorder = $window.FindName("LeftCardBorder")
$rightCardBorder = $window.FindName("RightCardBorder")

function Set-CardClip {
    param($border)
    if (-not $border) { return }
    $child = $border.Child
    if (-not $child) { return }
    $radius = $border.CornerRadius.TopLeft
    if ($radius -le 0) { return }
    $geometry = New-Object System.Windows.Media.RectangleGeometry
    $geometry.RadiusX = $radius
    $geometry.RadiusY = $radius
    $child.Clip = $geometry
    $child.Add_SizeChanged({
        param($s, $e)
        $a = [System.Windows.Media.VisualTreeHelper]::GetDescendantBounds($s)
        $s.Clip.Rect = $a
    })
}

Set-CardClip $leftCardBorder
Set-CardClip $rightCardBorder

#endregion Kontrol Referansları

#region UI Adaptör Fonksiyonları

function Update-Grid {
    param([string]$Filter)

    $view = [System.Windows.Data.CollectionViewSource]::GetDefaultView($AppDataGrid.ItemsSource)
    if ($view -and $view.CanFilter) {
        if ([string]::IsNullOrWhiteSpace($Filter)) {
            $view.Filter = $null
        } else {
            $view.Filter = {
                param($item)
                $item.ApplicationName -like "*$Filter*"
            }
        }
    }

    $script:updatingSelectAll = $true
    $selectAllCheckBox.IsChecked = $false
    $script:updatingSelectAll = $false
}

function Get-SelectedApps {
    return $AppDataGrid.SelectedItems
}

function Update-DetailsPanel {
    $selected = Get-SelectedApps
    $count = if ($selected) { @($selected).Count } else { 0 }
    $app = if ($count -gt 0) { $selected | Select-Object -First 1 } else { $null }

    if ($app) {
        $detailAppName.Text = $app.ApplicationName
        $detailProductCode.Text = $app.ProductCode
        $detailUninstallCmd.Text = $app.UninstallString
        $safeName = Convert-ToSafeName $app.ApplicationName
        $detailPolicyName.Text = "Remove_$safeName"
    } else {
        $detailAppName.Text = "No application selected"
        $detailProductCode.Text = "-"
        $detailUninstallCmd.Text = "-"
        $detailPolicyName.Text = "-"
    }

    $view = [System.Windows.Data.CollectionViewSource]::GetDefaultView($AppDataGrid.ItemsSource)
    $totalCount = if ($view) { @($view).Count } else { 0 }
    $script:updatingSelectAll = $true
    if ($count -eq 0) {
        $selectAllCheckBox.IsChecked = $false
    } elseif ($count -eq $totalCount) {
        $selectAllCheckBox.IsChecked = $true
    } else {
        $selectAllCheckBox.IsChecked = $null
    }
    $script:updatingSelectAll = $false
}

function Invoke-GenerateDetectScripts {
    $selected = Get-SelectedApps
    if (-not $selected -or @($selected).Count -eq 0) {
        [System.Windows.Forms.MessageBox]::Show("Please select at least one application.", "No Selection", "OK", "Warning")
        return
    }

    $folder = Select-Folder
    if (-not $folder) { return }

    foreach ($app in $selected) {
        try {
            $safeName = Convert-ToSafeName $app.ApplicationName
            $outPath = Join-Path $folder "$safeName`_Detect.ps1"
            Set-Content -Path $outPath -Value (New-DetectContent $app) -Encoding UTF8
        } catch {
            [System.Windows.Forms.MessageBox]::Show(
                "Failed to generate detect script for: $($app.ApplicationName)`n`n$_",
                "Error",
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Error
            )
        }
    }

    [System.Windows.Forms.MessageBox]::Show(
        "Detect scripts generated successfully.",
        "Success",
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Information
    )

    Invoke-Item $folder
}

function Invoke-GenerateRemediateScripts {
    $selected = Get-SelectedApps
    if (-not $selected -or @($selected).Count -eq 0) {
        [System.Windows.Forms.MessageBox]::Show("Please select at least one application.", "No Selection", "OK", "Warning")
        return
    }

    $folder = Select-Folder
    if (-not $folder) { return }

    foreach ($app in $selected) {
        try {
            $safeName = Convert-ToSafeName $app.ApplicationName
            $outPath = Join-Path $folder "$safeName`_Remediate.ps1"
            Set-Content -Path $outPath -Value (New-RemediateContent $app) -Encoding UTF8
        } catch {
            [System.Windows.Forms.MessageBox]::Show(
                "Failed to generate remediation script for: $($app.ApplicationName)`n`n$_",
                "Error",
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Error
            )
        }
    }

    [System.Windows.Forms.MessageBox]::Show(
        "Remediation scripts generated successfully.",
        "Success",
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Information
    )

    Invoke-Item $folder
}

function Invoke-GeneratePackage {
    $selected = Get-SelectedApps
    if (-not $selected -or @($selected).Count -eq 0) {
        [System.Windows.Forms.MessageBox]::Show("Please select at least one application.", "No Selection", "OK", "Warning")
        return
    }

    $folder = Select-Folder
    if (-not $folder) { return }

    $createdFolders = New-Package -Apps $selected -ParentFolder $folder

    if ($createdFolders.Count -gt 0) {
        [System.Windows.Forms.MessageBox]::Show(
            "Package(s) created successfully.`n`n$($createdFolders.Count) package(s) generated.",
            "Success",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Information
        )

        $script:lastOutputFolder = $folder
        Invoke-Item $folder
    }
}

#endregion UI Adaptör Fonksiyonları

#region Bağlam Menüsü (Programlı)

$contextMenu = New-Object System.Windows.Controls.ContextMenu

$copyProductCodeItem = New-Object System.Windows.Controls.MenuItem
$copyProductCodeItem.Header = "Copy Product Code"

$copyUninstallItem = New-Object System.Windows.Controls.MenuItem
$copyUninstallItem.Header = "Copy Uninstall Command"

$sep1 = New-Object System.Windows.Controls.Separator

$generateDetectItem = New-Object System.Windows.Controls.MenuItem
$generateDetectItem.Header = "Generate Detect Script"

$generateRemediateItem = New-Object System.Windows.Controls.MenuItem
$generateRemediateItem.Header = "Generate Remediation Script"

$sep2 = New-Object System.Windows.Controls.Separator

$generatePackageItem = New-Object System.Windows.Controls.MenuItem
$generatePackageItem.Header = "Generate Remediation Package"
$generatePackageItem.FontWeight = "Bold"

$contextMenu.Items.Add($copyProductCodeItem)
$contextMenu.Items.Add($copyUninstallItem)
$contextMenu.Items.Add($sep1)
$contextMenu.Items.Add($generateDetectItem)
$contextMenu.Items.Add($generateRemediateItem)
$contextMenu.Items.Add($sep2)
$contextMenu.Items.Add($generatePackageItem)

$AppDataGrid.ContextMenu = $contextMenu

#endregion Bağlam Menüsü

#region Olay İşleyicileri

$searchBox.Add_TextChanged({
    Update-Grid -Filter $searchBox.Text.Trim()
})

$AppDataGrid.Add_PreviewMouseLeftButtonDown({
    param($sender, $e)
    $dep = $e.OriginalSource -as [System.Windows.DependencyObject]
    if (-not $dep) { return }
    $row = $null
    $current = $dep
    while ($current) {
        $row = $current -as [System.Windows.Controls.DataGridRow]
        if ($row) { break }
        $current = [System.Windows.Media.VisualTreeHelper]::GetParent($current)
    }
    if ($row) {
        $row.IsSelected = -not $row.IsSelected
        $e.Handled = $true
    }
})

$AppDataGrid.Add_SelectionChanged({
    Update-DetailsPanel
})

$AppDataGrid.Add_PreviewMouseRightButtonDown({
    param($sender, $e)
    $source = $e.OriginalSource
    $row = $null
    $current = $source
    while ($current -and -not $row) {
        $row = $current -as [System.Windows.Controls.DataGridRow]
        $current = [System.Windows.Media.VisualTreeHelper]::GetParent($current)
    }
    if ($row) {
        if (-not $row.IsSelected) {
            $AppDataGrid.SelectedItems.Clear()
            $row.IsSelected = $true
        }
        $e.Handled = $true
    }
})

$copyProductCodeItem.Add_Click({
    $selected = Get-SelectedApps
    if (-not $selected -or @($selected).Count -eq 0) { return }
    $text = ($selected | ForEach-Object { $_.ProductCode }) -join "`r`n"
    [System.Windows.Clipboard]::SetText($text)
})

$copyUninstallItem.Add_Click({
    $selected = Get-SelectedApps
    if (-not $selected -or @($selected).Count -eq 0) { return }
    $text = ($selected | ForEach-Object { $_.UninstallString }) -join "`r`n"
    [System.Windows.Clipboard]::SetText($text)
})

$generateDetectItem.Add_Click({ Invoke-GenerateDetectScripts })
$generateRemediateItem.Add_Click({ Invoke-GenerateRemediateScripts })
$generatePackageItem.Add_Click({ Invoke-GeneratePackage })

$generatePackageButton.Add_Click({ Invoke-GeneratePackage })

$copyGuidButton.Add_Click({
    $selected = Get-SelectedApps
    $app = if ($selected) { @($selected)[0] } else { $null }
    if ($app) {
        [System.Windows.Clipboard]::SetText($app.ProductCode)
    }
})

$copyCommandButton.Add_Click({
    $selected = Get-SelectedApps
    $app = if ($selected) { @($selected)[0] } else { $null }
    if ($app) {
        [System.Windows.Clipboard]::SetText($app.UninstallString)
    }
})

$openOutputFolderButton.Add_Click({
    $folder = Select-Folder
    if ($folder) { Invoke-Item $folder }
})

$refreshButton.Add_Click({
    $script:allApps = Get-Applications
    $AppDataGrid.ItemsSource = $script:allApps
    $headerAppCount.Text = "$($script:allApps.Count) Apps"
    Update-DetailsPanel
    Update-Grid
    [System.Windows.Forms.MessageBox]::Show("Application list refreshed successfully.", "Refreshed", "OK", "Information")
})

$exportButton.Add_Click({
    $dlg = New-Object Microsoft.Win32.SaveFileDialog
    $dlg.Filter = "CSV Files (*.csv)|*.csv|All Files (*.*)|*.*"
    $dlg.DefaultExt = ".csv"
    $dlg.FileName = "InstalledApplications_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"
    if ($dlg.ShowDialog($window)) {
        $view = [System.Windows.Data.CollectionViewSource]::GetDefaultView($AppDataGrid.ItemsSource)
        $data = if ($view) { @($view) } else { @() }
        if ($data.Count -eq 0) { return }
        $data | Select-Object ApplicationName, ProductCode, UninstallString | Export-Csv -Path $dlg.FileName -NoTypeInformation -Encoding UTF8
    }
})

# Footer link - tarayıcıda aç
$footerLink = $window.FindName("FooterLink")
$footerLink.Add_RequestNavigate({
    param($sender, $e)
    Start-Process $e.Uri.AbsoluteUri
    $e.Handled = $true
})

#endregion Olay İşleyicileri

#region Başlatma

$AppDataGrid.ItemsSource = $script:allApps
$headerAppCount.Text = "$($script:allApps.Count) Apps"

Update-DetailsPanel
Update-Grid

#endregion Başlatma

#region Pencereyi Göster

$window.ShowDialog() | Out-Null

#endregion Pencereyi Göster
