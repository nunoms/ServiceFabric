param(
[switch] $CreateCluster = $false
)

#This script needs to run with administrator privileges
function EnsureAdminPrivileges {
    If (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(`
        [Security.Principal.WindowsBuiltInRole] “Administrator”))
    {
        Write-Warning “You do not have Administrator rights to run this script!`nPlease re-run this script as an Administrator!”
        Break
    }
}

EnsureAdminPrivileges;

#Setting up local cluster - you can skip if you already deployed an app using Visual Studio
if ($CreateCluster) {
    & "$ENV:ProgramFiles\Microsoft SDKs\Service Fabric\ClusterSetup\DevClusterSetup.ps1 -Force"
}
#In case the following commands don't work
Import-Module "$ENV:ProgramFiles\Microsoft SDKs\Service Fabric\Tools\PSModule\ServiceFabricSDK\ServiceFabricSDK.psm1"

#Set this variable to reference the app package - these can be created from VS by right-clicking the Service Fabric project and choosing "Package"
$appPackage = (Get-Item -Path ".\" -Verbose).FullName + "\WordCountV1.sfpkg"

#connect to cluster
Write-Host "Connecting to local cluster" -ForegroundColor Cyan
Connect-ServiceFabricCluster localhost:19000

#publish application
Write-Host "Publishing V1 of Wordcount application." -ForegroundColor Cyan
Publish-NewServiceFabricApplication -ApplicationPackagePath $appPackage -ApplicationName "fabric:/WordCount" -OverwriteBehavior Always

#Launch the browser window to look at our running app
Start-Process -FilePath "http://localhost:8081/wordcount/index.html"

#Let's look at our app details in the cluster
Write-Host "Getting details of application" -ForegroundColor Cyan
Get-ServiceFabricApplication -ApplicationName 'fabric:/WordCount'

#Get the set of services included in the app
Write-Host "Getting list of services for this application" -ForegroundColor Cyan
Get-ServiceFabricService -ApplicationName 'fabric:/WordCount'

#Get list of partitions for a particular service
Write-Host "Getting partitions for the WordCountService" -ForegroundColor Cyan
Get-ServiceFabricPartition 'fabric:/WordCount/WordCountService'

#Open the Local Cluster Manager - look at partitions and how Service Fabric spreads load
Start-Process -FilePath  http://localhost:19080/Explorer

#upgrade the application
Write-Host "Upgrading the application...press any key to continue" -ForegroundColor Yellow
Read-Host
$newAppPackage = (Get-Item -Path ".\" -Verbose).FullName + "\WordCountV2.sfpkg"
Publish-UpgradedServiceFabricApplication -ApplicationPackagePath $newAppPackage -ApplicationName "fabric:/WordCount" -UpgradeParameters @{"FailureAction"="Rollback"; "UpgradeReplicaSetCheckTimeout"=1; "Monitored"=$true; "Force"=$true}

#notice only the WordCountService version was updated
Write-Host "Listing services for the application" -ForegroundColor Cyan
Get-ServiceFabricService -ApplicationName 'fabric:/WordCount'

#Unpublish the application
Write-Host "Unpublishing application...press any key to continue" -ForegroundColor Cyan
Read-Host
Unpublish-ServiceFabricApplication -ApplicationName "fabric:/WordCount"

#unregister application types - removes code and configuration from cluster image store
Write-Host "Unregistering application types" -ForegroundColor Cyan
Remove-ServiceFabricApplicationType -ApplicationTypeName WordCount -ApplicationTypeVersion 2.0.0
Remove-ServiceFabricApplicationType -ApplicationTypeName WordCount -ApplicationTypeVersion 1.0.0


