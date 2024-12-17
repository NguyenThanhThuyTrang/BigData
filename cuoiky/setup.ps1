# Chọn subscription
Write-Host "Setting subscription to '$subscriptionName'..."
$selectedSub = Get-AzSubscription | Where-Object { $_.Id -eq $subscriptionId }

if ($null -eq $selectedSub) {
    Write-Error "Subscription '$subscriptionName' with ID '$subscriptionId' not found. Please verify the details."
    exit
}

Select-AzSubscription -SubscriptionId $subscriptionId
az account set --subscription $subscriptionId

Write-Host "Subscription '$subscriptionName' (ID: $subscriptionId) has been set."

# Tạo Synapse Workspace
Write-Host "Creating Synapse Workspace: $synapseWorkspace in region: $region"
$workspaceExists = Get-AzSynapseWorkspace -Name $synapseWorkspace -ErrorAction SilentlyContinue

if ($null -eq $workspaceExists) {
    New-AzSynapseWorkspace `
        -ResourceGroupName "DefaultResourceGroup" `
        -Name $synapseWorkspace `
        -Location $region `
        -DefaultDataLakeStorageAccountName $dataLakeAccountName `
        -DefaultDataLakeStorageFilesystem "filesystem" `
        -SqlAdministratorLogin $sqlUser `
        -SqlAdministratorLoginPassword (ConvertTo-SecureString $sqlPassword -AsPlainText -Force)

    Write-Host "Synapse Workspace '$synapseWorkspace' created successfully in region '$region'."
}
else {
    Write-Host "Synapse Workspace '$synapseWorkspace' already exists."
}

# Thông tin cấu hình cuối cùng
Write-Host "--------------------------------------------"
Write-Host "Subscription: $subscriptionName (ID: $subscriptionId)"
Write-Host "Region: $region"
Write-Host "Workspace: $synapseWorkspace"
Write-Host "Data Lake: $dataLakeAccountName"
Write-Host "Spark Pool: $sparkPool"
Write-Host "SQL Database: $sqlDatabaseName"
Write-Host "SQL User: $sqlUser"
Write-Host "--------------------------------------------"

# Create database
write-host "Creating the $sqlDatabaseName database..."
sqlcmd -S "$synapseWorkspace.sql.azuresynapse.net" -U $sqlUser -P $sqlPassword -d $sqlDatabaseName -I -i setup.sql

# Load data
write-host "Loading data..."
Get-ChildItem "./data/*.txt" -File | Foreach-Object {
    write-host ""
    $file = $_.FullName
    Write-Host "$file"
    $table = $_.Name.Replace(".txt","")
    bcp dbo.$table in $file -S "$synapseWorkspace.sql.azuresynapse.net" -U $sqlUser -P $sqlPassword -d $sqlDatabaseName -f $file.Replace("txt", "fmt") -q -k -E -b 5000
}

# Pause SQL Pool
write-host "Pausing the $sqlDatabaseName SQL Pool..."
Suspend-AzSynapseSqlPool -WorkspaceName $synapseWorkspace -Name $sqlDatabaseName -AsJob

# Upload files
write-host "Loading data..."
$storageAccount = Get-AzStorageAccount -ResourceGroupName $resourceGroupName -Name $dataLakeAccountName
$storageContext = $storageAccount.Context
Get-ChildItem "./files/*.csv" -File | Foreach-Object {
    write-host ""
    $file = $_.Name
    Write-Host $file
    $blobPath = "sales_data/$file"
    Set-AzStorageBlobContent -File $_.FullName -Container "files" -Blob $blobPath -Context $storageContext
}

# Create KQL script
# Removing until fix for Bad Request error is resolved
# New-AzSynapseKqlScript -WorkspaceName $synapseWorkspace -DefinitionFile "./files/ingest-data.kql"

write-host "Script completed at $(Get-Date)"