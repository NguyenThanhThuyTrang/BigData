# Định nghĩa các biến mặc định
$synapseWorkspace = "cuoiky-workspace"         # Tên Synapse workspace
$dataLakeAccountName = "tranghuyen"            # Tên Azure Data Lake Storage Account
$sparkPool = "sparkpool"                      # Tên Spark pool
$sqlDatabaseName = "sqlpool"                  # Tên SQL pool
$subscriptionName = "Azure subscription 1"    # Tên Subscription
$subscriptionID = "063ab6f7-120f-4b12-8d36-8ea6f30a4b25" # Subscription ID
$region = "Southeast Asia"                    # Khu vực hoạt động

# Đăng nhập Azure và chọn Subscription
Write-Output "Đăng nhập vào Azure..."
Connect-AzAccount

Write-Output "Chọn Subscription mặc định..."
Select-AzSubscription -SubscriptionId $subscriptionID

# Tạo Azure Synapse Workspace
Write-Output "Tạo Synapse Workspace '$synapseWorkspace'..."
New-AzSynapseWorkspace -Name $synapseWorkspace `
                       -ResourceGroupName "DefaultResourceGroup" `
                       -Location $region `
                       -DefaultDataLakeStorageAccountName $dataLakeAccountName `
                       -DefaultDataLakeStorageFilesystem "synapse"

# Tạo Spark Pool
Write-Output "Tạo Spark Pool '$sparkPool'..."
New-AzSynapseSparkPool -WorkspaceName $synapseWorkspace `
                       -Name $sparkPool `
                       -NodeCount 3 `
                       -NodeSize Small

# Tạo SQL Database
Write-Output "Tạo SQL Pool '$sqlDatabaseName'..."
New-AzSynapseSqlPool -WorkspaceName $synapseWorkspace `
                     -Name $sqlDatabaseName `
                     -PerformanceLevel "DW100c"

Write-Output "Cấu hình hoàn tất. Các tài nguyên sau đã được tạo:"
Write-Output "Workspace: $synapseWorkspace"
Write-Output "Data Lake Account: $dataLakeAccountName"
Write-Output "Spark Pool: $sparkPool"
Write-Output "SQL Database: $sqlDatabaseName"
Write-Output "Subscription: $subscriptionName"
Write-Output "Region: $region"

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