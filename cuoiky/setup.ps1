Clear-Host
write-host "Starting script at $(Get-Date)"
Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
Install-Module -Name Az.Synapse -Force

# Biến mặc định
$synapseWorkspace = "cuoiky-workspace"         # Tên Synapse workspace
$dataLakeAccountName = "tranghuyen"            # Tên Azure Data Lake Storage Account
$sparkPool = "sparkpool"                      # Tên Spark pool
$sqlDatabaseName = "sqlpool"                  # Tên SQL pool
$subscriptionName = "Azure subscription 1"    # Tên Subscription
$subscriptionID = "063ab6f7-120f-4b12-8d36-8ea6f30a4b25" # Subscription ID
$region = "Southeast Asia"                    # Khu vực hoạt động
$sqlUser = "SQLUser"
$sqlPassword = "Chanchan123@"

# Xác nhận subscription
Select-AzSubscription -SubscriptionId $subscriptionID
az account set --subscription $subscriptionID

# Đăng ký resource providers
Write-Host "Registering resource providers...";
$provider_list = "Microsoft.Synapse", "Microsoft.Sql", "Microsoft.Storage", "Microsoft.Compute"
foreach ($provider in $provider_list) {
    Register-AzResourceProvider -ProviderNamespace $provider | Out-Null
    Write-Host "$provider is successfully registered."
}

# Tạo resource group
Write-Host "Creating $resourceGroupName resource group in $region ..."
$resourceGroupName = "cuoiky"
New-AzResourceGroup -Name $resourceGroupName -Location $region | Out-Null

# Tạo Synapse workspace
write-host "Creating $synapseWorkspace Synapse Analytics workspace in $resourceGroupName resource group..."
write-host "(This may take some time!)"
New-AzResourceGroupDeployment -ResourceGroupName $resourceGroupName `
  -TemplateFile "setup.json" `
  -Mode Complete `
  -workspaceName $synapseWorkspace `
  -dataLakeAccountName $dataLakeAccountName `
  -sparkPoolName $sparkPool `
  -sqlDatabaseName $sqlDatabaseName `
  -sqlUser $sqlUser `
  -sqlPassword $sqlPassword `
  -Force

# Gán quyền cho Data Lake Blob Store
write-host "Granting permissions on the $dataLakeAccountName storage account..."
write-host "(you can ignore any warnings!)"
$subscriptionId = (Get-AzContext).Subscription.Id
$userName = ((az ad signed-in-user show) | ConvertFrom-JSON).UserPrincipalName
$id = (Get-AzADServicePrincipal -DisplayName $synapseWorkspace).id
New-AzRoleAssignment -Objectid $id -RoleDefinitionName "Storage Blob Data Owner" -Scope "/subscriptions/$subscriptionId/resourceGroups/$resourceGroupName/providers/Microsoft.Storage/storageAccounts/$dataLakeAccountName" -ErrorAction SilentlyContinue;
New-AzRoleAssignment -SignInName $userName -RoleDefinitionName "Storage Blob Data Owner" -Scope "/subscriptions/$subscriptionId/resourceGroups/$resourceGroupName/providers/Microsoft.Storage/storageAccounts/$dataLakeAccountName" -ErrorAction SilentlyContinue;

# Tạo database
write-host "Creating the $sqlDatabaseName database..."
sqlcmd -S "$synapseWorkspace.sql.azuresynapse.net" -U $sqlUser -P $sqlPassword -d $sqlDatabaseName -I -i setup.sql

# Tải dữ liệu
write-host "Loading data..."
Get-ChildItem "./data/*.txt" -File | Foreach-Object {
    write-host ""
    $file = $_.FullName
    Write-Host "$file"
    $table = $_.Name.Replace(".txt","")
    bcp dbo.$table in $file -S "$synapseWorkspace.sql.azuresynapse.net" -U $sqlUser -P $sqlPassword -d $sqlDatabaseName -f $file.Replace("txt", "fmt") -q -k -E -b 5000
}

# Tạm dừng SQL Pool
write-host "Pausing the $sqlDatabaseName SQL Pool..."
Suspend-AzSynapseSqlPool -WorkspaceName $synapseWorkspace -Name $sqlDatabaseName -AsJob

# Tải tập tin CSV lên Data Lake
write-host "Uploading CSV files to Data Lake..."
$storageAccount = Get-AzStorageAccount -ResourceGroupName $resourceGroupName -Name $dataLakeAccountName
$storageContext = $storageAccount.Context
Get-ChildItem "./files/*.csv" -File | Foreach-Object {
    write-host ""
    $file = $_.Name
    Write-Host $file
    $blobPath = "sales_data/$file"
    Set-AzStorageBlobContent -File $_.FullName -Container "files" -Blob $blobPath -Context $storageContext
}

write-host "Script completed at $(Get-Date)"
