# SimplePASS - Main GUI Application
[CmdletBinding()]
param()

Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase
Add-Type -AssemblyName System.Windows.Forms

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
if (-not $scriptDir) { $scriptDir = Get-Location }

Import-Module (Join-Path $scriptDir "CryptoModule.psm1") -DisableNameChecking -Force
Import-Module (Join-Path $scriptDir "VaultModule.psm1") -DisableNameChecking -Force
Import-Module (Join-Path $scriptDir "UtilsModule.psm1") -DisableNameChecking -Force
Import-Module (Join-Path $scriptDir "LoggerModule.psm1") -DisableNameChecking -Force

# --- App-wide Exception & Log Management ---
[System.AppDomain]::CurrentDomain.add_UnhandledException([System.UnhandledExceptionEventHandler]{
    param($sender, $e)
    if ($e.ExceptionObject -is [System.Exception]) {
        Write-AppLog -Level FATAL -Message "Unhandled AppDomain Exception" -Exception $e.ExceptionObject
    }
})

Write-AppLog -Level INFO -Message "SimplePASS Application Started."

# --- XAML UI Definition ---
[xml]$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="SimplePASS - Password Manager" Height="560" Width="860"
        WindowStartupLocation="CenterScreen" Background="#F4F5F7" FontFamily="Segoe UI">
    <Grid>
        <!-- Login Panel -->
        <Border x:Name="LoginPanel" Background="#FFFFFF" Width="420" Height="330"
                CornerRadius="8" VerticalAlignment="Center" HorizontalAlignment="Center">
            <Border.Effect>
                <DropShadowEffect BlurRadius="20" Color="#CCCCCC" ShadowDepth="4" Opacity="0.5"/>
            </Border.Effect>
            <StackPanel Margin="30">
                <TextBlock Text="SimplePASS" FontSize="26" FontWeight="Bold" Foreground="#2C3E50" HorizontalAlignment="Center" Margin="0,0,0,10"/>
                <TextBlock x:Name="TxtLoginSubtitle" Text="Enter your Master Password to unlock" FontSize="13" Foreground="#7F8C8D" HorizontalAlignment="Center" Margin="0,0,0,25"/>

                <TextBlock Text="Master Password:" FontSize="13" FontWeight="SemiBold" Foreground="#34495E" Margin="0,0,0,5"/>
                <PasswordBox x:Name="PbMasterPassword" Height="38" FontSize="16" Padding="5" Margin="0,0,0,20"/>

                <Button x:Name="BtnLogin" Content="Unlock Vault" Height="40" Background="#3498DB" Foreground="White"
                        FontSize="15" FontWeight="Bold" Cursor="Hand" BorderThickness="0">
                    <Button.Resources>
                        <Style TargetType="Border">
                            <Setter Property="CornerRadius" Value="4"/>
                        </Style>
                    </Button.Resources>
                </Button>
                <TextBlock x:Name="TxtLoginError" Foreground="#E74C3C" FontSize="12" Margin="0,10,0,0" TextWrapping="Wrap" HorizontalAlignment="Center"/>
            </StackPanel>
        </Border>

        <!-- Main Dashboard Grid -->
        <Grid x:Name="MainGrid" Visibility="Collapsed" Margin="15">
            <Grid.RowDefinitions>
                <RowDefinition Height="Auto"/>
                <RowDefinition Height="*"/>
                <RowDefinition Height="Auto"/>
            </Grid.RowDefinitions>

            <!-- Search & Actions Bar -->
            <Grid Grid.Row="0" Margin="0,0,0,15">
                <Grid.ColumnDefinitions>
                    <ColumnDefinition Width="*"/>
                    <ColumnDefinition Width="Auto"/>
                    <ColumnDefinition Width="Auto"/>
                </Grid.ColumnDefinitions>
                <TextBox x:Name="TxtSearch" Grid.Column="0" Height="35" FontSize="14" Padding="8,5" VerticalContentAlignment="Center"
                         ToolTip="Search title, URL, username..."/>
                <Button x:Name="BtnAddEntry" Grid.Column="1" Content="+ Add Entry" Height="35" Width="110" Margin="10,0,0,0"
                        Background="#2ECC71" Foreground="White" FontWeight="Bold" Cursor="Hand" BorderThickness="0"/>
                <Button x:Name="BtnLock" Grid.Column="2" Content="Lock Vault" Height="35" Width="90" Margin="10,0,0,0"
                        Background="#E74C3C" Foreground="White" FontWeight="Bold" Cursor="Hand" BorderThickness="0"/>
            </Grid>

            <!-- DataGrid -->
            <DataGrid x:Name="DgEntries" Grid.Row="1" AutoGenerateColumns="False" IsReadOnly="True"
                      CanUserAddRows="False" SelectionMode="Single" Background="White" RowHeaderWidth="0" GridLinesVisibility="Horizontal">
                <DataGrid.Columns>
                    <DataGridTextColumn Header="Title" Binding="{Binding title}" Width="150"/>
                    <DataGridTextColumn Header="Username" Binding="{Binding username}" Width="160"/>
                    <DataGridTextColumn Header="URL" Binding="{Binding url}" Width="180"/>
                    <DataGridTextColumn Header="Note" Binding="{Binding note}" Width="140"/>
                    <DataGridTemplateColumn Header="Actions" Width="*">
                        <DataGridTemplateColumn.CellTemplate>
                            <DataTemplate>
                                <StackPanel Orientation="Horizontal" HorizontalAlignment="Left">
                                    <Button Content="Copy Pass" Tag="{Binding}" x:Name="BtnCopyPass" Margin="2" Padding="6,2" Background="#3498DB" Foreground="White" BorderThickness="0"/>
                                    <Button Content="Copy User" Tag="{Binding}" x:Name="BtnCopyUser" Margin="2" Padding="6,2" Background="#95A5A6" Foreground="White" BorderThickness="0"/>
                                    <Button Content="Edit" Tag="{Binding}" x:Name="BtnEditEntry" Margin="2" Padding="6,2" Background="#F39C12" Foreground="White" BorderThickness="0"/>
                                    <Button Content="Delete" Tag="{Binding}" x:Name="BtnDeleteEntry" Margin="2" Padding="6,2" Background="#E74C3C" Foreground="White" BorderThickness="0"/>
                                </StackPanel>
                            </DataTemplate>
                        </DataGridTemplateColumn.CellTemplate>
                    </DataGridTemplateColumn>
                </DataGrid.Columns>
            </DataGrid>

            <!-- Status Bar -->
            <TextBlock x:Name="TxtStatus" Grid.Row="2" Text="Ready" Foreground="#7F8C8D" Margin="0,10,0,0" FontSize="12"/>
        </Grid>

        <!-- Entry Modal Window -->
        <Border x:Name="EntryModal" Background="#80000000" Visibility="Collapsed">
            <Border Background="White" Width="450" VerticalAlignment="Center" HorizontalAlignment="Center" CornerRadius="8" Padding="25">
                <StackPanel>
                    <TextBlock x:Name="TxtModalTitle" Text="Password Entry" FontSize="18" FontWeight="Bold" Margin="0,0,0,15"/>

                    <TextBlock Text="Title / Service Name:" Margin="0,5,0,2"/>
                    <TextBox x:Name="TxtFormTitle" Height="30" Padding="5"/>

                    <TextBlock Text="URL:" Margin="0,8,0,2"/>
                    <TextBox x:Name="TxtFormUrl" Height="30" Padding="5"/>

                    <TextBlock Text="Username / ID:" Margin="0,8,0,2"/>
                    <TextBox x:Name="TxtFormUsername" Height="30" Padding="5"/>

                    <Grid Margin="0,8,0,2">
                        <Grid.ColumnDefinitions>
                            <ColumnDefinition Width="*"/>
                            <ColumnDefinition Width="Auto"/>
                        </Grid.ColumnDefinitions>
                        <TextBlock Text="Password:" Grid.Column="0"/>
                        <Button x:Name="BtnGeneratePass" Content="Generate" Grid.Column="1" Background="#9B59B6" Foreground="White" Padding="8,2" BorderThickness="0" Cursor="Hand"/>
                    </Grid>
                    <TextBox x:Name="TxtFormPassword" Height="30" Padding="5"/>

                    <TextBlock Text="Note:" Margin="0,8,0,2"/>
                    <TextBox x:Name="TxtFormNote" Height="50" Padding="5" TextWrapping="Wrap" AcceptsReturn="True"/>

                    <StackPanel Orientation="Horizontal" HorizontalAlignment="Right" Margin="0,20,0,0">
                        <Button x:Name="BtnSaveEntry" Content="Save" Width="80" Height="32" Background="#2ECC71" Foreground="White" FontWeight="Bold" Margin="0,0,10,0" BorderThickness="0"/>
                        <Button x:Name="BtnCancelModal" Content="Cancel" Width="80" Height="32" Background="#95A5A6" Foreground="White" BorderThickness="0"/>
                    </StackPanel>
                </StackPanel>
            </Border>
        </Border>
    </Grid>
</Window>
"@

$reader = (New-Object System.Xml.XmlNodeReader $xaml)
$window = [Windows.Markup.XamlReader]::Load($reader)

# Controls
$loginPanel = $window.FindName("LoginPanel")
$pbMasterPassword = $window.FindName("PbMasterPassword")
$btnLogin = $window.FindName("BtnLogin")
$txtLoginError = $window.FindName("TxtLoginError")
$txtLoginSubtitle = $window.FindName("TxtLoginSubtitle")

$mainGrid = $window.FindName("MainGrid")
$txtSearch = $window.FindName("TxtSearch")
$btnAddEntry = $window.FindName("BtnAddEntry")
$btnLock = $window.FindName("BtnLock")
$dgEntries = $window.FindName("DgEntries")
$txtStatus = $window.FindName("TxtStatus")

$entryModal = $window.FindName("EntryModal")
$txtModalTitle = $window.FindName("TxtModalTitle")
$txtFormTitle = $window.FindName("TxtFormTitle")
$txtFormUrl = $window.FindName("TxtFormUrl")
$txtFormUsername = $window.FindName("TxtFormUsername")
$txtFormPassword = $window.FindName("TxtFormPassword")
$txtFormNote = $window.FindName("TxtFormNote")
$btnGeneratePass = $window.FindName("BtnGeneratePass")
$btnSaveEntry = $window.FindName("BtnSaveEntry")
$btnCancelModal = $window.FindName("BtnCancelModal")

# App State
$script:MasterPassword = ""
$script:VaultEntries = @()
$script:EditingEntryId = $null

# First-time setup check function
function Update-LoginUIState {
    if (-not (Test-VaultExists)) {
        $txtLoginSubtitle.Text = "First run detected. Create your Master Password."
        $btnLogin.Content = "Create Vault"
    } else {
        $txtLoginSubtitle.Text = "Enter your Master Password to unlock"
        $btnLogin.Content = "Unlock Vault"
    }
}

Update-LoginUIState

# --- Event Handlers ---

# PasswordBox Enter key login
$pbMasterPassword.Add_KeyDown({
    param($sender, $e)
    if ($e.Key -eq [System.Windows.Input.Key]::Enter) {
        $btnLogin.RaiseEvent((New-Object System.Windows.RoutedEventArgs([System.Windows.Controls.Primitives.ButtonBase]::ClickEvent)))
    }
})

# Login / Create Vault Button
$btnLogin.Add_Click({
    $inputPass = $pbMasterPassword.Password
    if ([string]::IsNullOrWhiteSpace($inputPass)) {
        $txtLoginError.Text = "Please enter a Master Password."
        return
    }

    try {
        $isFirstRun = -not (Test-VaultExists)
        if ($isFirstRun) {
            $script:VaultEntries = @()
            Save-Vault -Entries $script:VaultEntries -MasterPassword $inputPass
        } else {
            $script:VaultEntries = Load-Vault -MasterPassword $inputPass
        }
        $script:MasterPassword = $inputPass
        $pbMasterPassword.Password = ""
        $txtLoginError.Text = ""

        $loginPanel.Visibility = [System.Windows.Visibility]::Collapsed
        $mainGrid.Visibility = [System.Windows.Visibility]::Visible
        
        $dgEntries.ItemsSource = @($script:VaultEntries)
        if ($isFirstRun) {
            $txtStatus.Text = "Master Password created successfully. Vault initialized."
        } else {
            $txtStatus.Text = "Authenticated successfully. Loaded $($script:VaultEntries.Count) entries."
        }
    } catch {
        Write-AppLog -Level ERROR -Message "Login / Vault creation failed" -Exception $_.Exception
        if (Test-VaultExists) {
            $txtLoginError.Text = "Invalid Master Password or Decryption Failed."
        } else {
            $txtLoginError.Text = "Failed to create Vault: $($_.Exception.Message)"
        }
    }
})

# Search text changed
$txtSearch.Add_TextChanged({
    if ($script:VaultEntries) {
        $filtered = Search-VaultEntries -Entries $script:VaultEntries -Keyword $txtSearch.Text
        $dgEntries.ItemsSource = @($filtered)
    }
})

# Lock Button
$btnLock.Add_Click({
    $script:MasterPassword = ""
    $script:VaultEntries = @()
    $dgEntries.ItemsSource = $null
    Update-LoginUIState
    $mainGrid.Visibility = [System.Windows.Visibility]::Collapsed
    $loginPanel.Visibility = [System.Windows.Visibility]::Visible
    $txtStatus.Text = "Vault locked."
})

# Add Entry Button
$btnAddEntry.Add_Click({
    $script:EditingEntryId = $null
    $txtModalTitle.Text = "New Password Entry"
    $txtFormTitle.Text = ""
    $txtFormUrl.Text = ""
    $txtFormUsername.Text = ""
    $txtFormPassword.Text = ""
    $txtFormNote.Text = ""
    $entryModal.Visibility = [System.Windows.Visibility]::Visible
})

# Cancel Modal
$btnCancelModal.Add_Click({
    $entryModal.Visibility = [System.Windows.Visibility]::Collapsed
})

# Generate Password Button
$btnGeneratePass.Add_Click({
    $txtFormPassword.Text = New-RandomPassword -Length 16
})

# Save Entry Button
$btnSaveEntry.Add_Click({
    if ([string]::IsNullOrWhiteSpace($txtFormTitle.Text)) {
        [System.Windows.MessageBox]::Show("Please enter a title.", "Validation Error", "OK", "Error") | Out-Null
        return
    }

    if ($script:EditingEntryId) {
        $item = $script:VaultEntries | Where-Object { $_.id -eq $script:EditingEntryId }
        if ($item) {
            $item.title = $txtFormTitle.Text
            $item.url = $txtFormUrl.Text
            $item.username = $txtFormUsername.Text
            $item.password = $txtFormPassword.Text
            $item.note = $txtFormNote.Text
            $item.updatedAt = (Get-Date).ToString("o")
        }
    } else {
        $newEntry = New-VaultEntry -Title $txtFormTitle.Text -Url $txtFormUrl.Text -Username $txtFormUsername.Text -Password $txtFormPassword.Text -Note $txtFormNote.Text
        $script:VaultEntries = @($script:VaultEntries) + $newEntry
    }

    Save-Vault -Entries $script:VaultEntries -MasterPassword $script:MasterPassword
    $dgEntries.ItemsSource = @(Search-VaultEntries -Entries $script:VaultEntries -Keyword $txtSearch.Text)
    $entryModal.Visibility = [System.Windows.Visibility]::Collapsed
    $txtStatus.Text = "Entry saved. (Total: $($script:VaultEntries.Count))"
})

# DataGrid Row Actions
$script:BtnCopyPass_Click = {
    param($sender, $e)
    $entry = $sender.Tag
    if ($entry -and $entry.password) {
        Set-ClipboardWithAutoClear -Text $entry.password -ClearAfterSeconds 30
        $txtStatus.Text = "Password copied to clipboard (Auto-clears in 30s)."
    }
}

$script:BtnCopyUser_Click = {
    param($sender, $e)
    $entry = $sender.Tag
    if ($entry -and $entry.username) {
        Set-ClipboardWithAutoClear -Text $entry.username -ClearAfterSeconds 30
        $txtStatus.Text = "Username copied to clipboard."
    }
}

$script:BtnEditEntry_Click = {
    param($sender, $e)
    $entry = $sender.Tag
    if ($entry) {
        $script:EditingEntryId = $entry.id
        $txtModalTitle.Text = "Edit Entry"
        $txtFormTitle.Text = $entry.title
        $txtFormUrl.Text = $entry.url
        $txtFormUsername.Text = $entry.username
        $txtFormPassword.Text = $entry.password
        $txtFormNote.Text = $entry.note
        $entryModal.Visibility = [System.Windows.Visibility]::Visible
    }
}

$script:BtnDeleteEntry_Click = {
    param($sender, $e)
    $entry = $sender.Tag
    if ($entry) {
        $res = [System.Windows.MessageBox]::Show("Are you sure you want to delete '$($entry.title)'?", "Confirm Delete", "YesNo", "Question")
        if ($res -eq "Yes") {
            $targetId = $entry.id
            $script:VaultEntries = @($script:VaultEntries | Where-Object { $_.id -ne $targetId })

            Save-Vault -Entries $script:VaultEntries -MasterPassword $script:MasterPassword
            $dgEntries.ItemsSource = @(Search-VaultEntries -Entries $script:VaultEntries -Keyword $txtSearch.Text)
            $txtStatus.Text = "Entry deleted."
        }
    }
}

$window.AddHandler([System.Windows.Controls.Primitives.ButtonBase]::ClickEvent, [System.Windows.RoutedEventHandler]{
    param($sender, $e)
    $source = $e.OriginalSource
    if ($null -eq $source -or $source -isnot [System.Windows.Controls.Button]) { return }

    $entry = $source.DataContext

    if ($source.Name -eq "BtnCopyPass" -or $source.Content -eq "Copy Pass") {
        $passToCopy = if ($entry -and $entry.password) { $entry.password } else { $source.Tag }
        if ($passToCopy) {
            [void](Set-ClipboardWithAutoClear -Text $passToCopy -ClearAfterSeconds 30)
            $txtStatus.Text = "Password copied to clipboard (Auto-clears in 30s)."
            Write-AppLog -Level INFO -Message "Password copied to clipboard."
        }
    }
    elseif ($source.Name -eq "BtnCopyUser" -or $source.Content -eq "Copy User") {
        $userToCopy = if ($entry -and $entry.username) { $entry.username } else { $source.Tag }
        if ($userToCopy) {
            [void](Set-ClipboardWithAutoClear -Text $userToCopy -ClearAfterSeconds 30)
            $txtStatus.Text = "Username copied to clipboard."
            Write-AppLog -Level INFO -Message "Username copied to clipboard."
        }
    }
    elseif ($source.Name -eq "BtnEditEntry" -or $source.Content -eq "Edit") {
        if ($entry) {
            $script:EditingEntryId = $entry.id
            $txtModalTitle.Text = "Edit Entry"
            $txtFormTitle.Text = $entry.title
            $txtFormUrl.Text = $entry.url
            $txtFormUsername.Text = $entry.username
            $txtFormPassword.Text = $entry.password
            $txtFormNote.Text = $entry.note
            $entryModal.Visibility = [System.Windows.Visibility]::Visible
        }
    }
    elseif ($source.Name -eq "BtnDeleteEntry" -or $source.Content -eq "Delete") {
        if ($entry) {
            $res = [System.Windows.MessageBox]::Show("Are you sure you want to delete '$($entry.title)'?", "Confirm Delete", "YesNo", "Question")
            if ($res -eq "Yes") {
                $targetId = $entry.id
                $script:VaultEntries = @($script:VaultEntries | Where-Object { $_.id -ne $targetId })

                Save-Vault -Entries $script:VaultEntries -MasterPassword $script:MasterPassword
                $dgEntries.ItemsSource = @(Search-VaultEntries -Entries $script:VaultEntries -Keyword $txtSearch.Text)
                $txtStatus.Text = "Entry deleted."
            }
        }
    }
})

# Show Dialog
[void]$window.ShowDialog()
