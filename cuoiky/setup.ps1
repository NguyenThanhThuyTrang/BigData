# Clear the console
Clear-Host
Write-Host "Starting script at $(Get-Date)"

# Trust PSGallery for installation
Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
Install-Module -Name Az.Synapse -Force

# Prompt user to select Azure subscription if multiple subscriptions exist
$subscriptions = Get-AzSubscription | Select-Object
if ($subscriptions.Count -gt 1) {
    Write-Host "Multiple Azure subscriptions found. Please select one:"
    for ($i = 0; $i -lt $subscriptions.Count; $i++) {
        Write-Host "[$i]: $($subscriptions[$i].Name) (ID: $($subscriptions[$i].Id))"
    }
    
    $selectedIndex = -1
    while ($selectedIndex -lt 0 -or $selectedIndex -ge $subscriptions.Count) {
        $selectedIndex = Read-Host "Enter the index of your subscription (0 to $($subscriptions.Count - 1))"
        if (-not [int]::TryParse($selectedIndex, [ref]$null)) {
            Write-Host "Invalid input. Please enter a number." -ForegroundColor Red
            $selectedIndex = -1
        }
    }

    $selectedSubscription = $subscriptions[$selectedIndex]
    Select-AzSubscription -SubscriptionId $selectedSubscription.Id
    az account set --subscription $selectedSubscription.Id
    Write-Host "Selected subscription: $($selectedSubscription.Name)"
}

# Resource configuration
$resourceGroupName = "cuoiky"
$region = "Southeast Asia"
$synapseWorkspace = "cuoiky-synapse"
$dataLakeAccountName = "tranghuyen"
$fileSystemName = "data"

# Create or update the resource group
Write-Host "Creating or updating Resource Group: $resourceGroupName in region: $region..."
New-AzResourceGroup -Name $resourceGroupName -Location $region | Out-Null

# Create Synapse workspace
Write-Host "Creating Synapse Analytics Workspace: $synapseWorkspace..."
$adminPassword = Read-Host -Prompt "Enter SQL Admin Password" -AsSecureString

New-AzSynapseWorkspace -ResourceGroupName $resourceGroupName `
    -Name $synapseWorkspace `
    -Location $region `
    -DefaultDataLakeStorageAccountName $dataLakeAccountName `
    -DefaultDataLakeStorageFilesystem $fileSystemName `
    -SqlAdministratorLoginPassword $adminPassword `
    -EnableManagedVirtualNetwork `
    -PublicNetworkAccess Disabled

Write-Host "Synapse Workspace $synapseWorkspace created successfully."

# Upload files to Data Lake Storage
Write-Host "Uploading files to Data Lake Storage..."
$storageAccount = Get-AzStorageAccount -ResourceGroupName $resourceGroupName -Name $dataLakeAccountName
if (-not $storageAccount) {
    Write-Host "Error: Storage account $dataLakeAccountName does not exist in Resource Group $resourceGroupName." -ForegroundColor Red
    exit 1
}

$storageContext = $storageAccount.Context
Get-ChildItem "./files/*.csv" -File | ForEach-Object {
    Write-Host "Uploading file: $($_.Name)"
    Set-AzStorageBlobContent -File $_.FullName -Container $fileSystemName -Blob $_.Name -Context $storageContext
}

Write-Host "Script completed successfully at $(Get-Date)."
