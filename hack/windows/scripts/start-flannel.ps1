Param(
    [parameter(Mandatory = $true)] $ManagementIP
)

$BaseDir = "c:\rainbond"
$helper = "$BaseDir\scripts\helper.psm1"
$LogDir = "$BaseDir\log"

function SetupDirectories()
{
    md $BaseDir -ErrorAction Ignore
    md $LogDir -ErrorAction Ignore
    md c:\flannel -ErrorAction Ignore
    md $BaseDir\cni\config -ErrorAction Ignore
    md C:\etc\kube-flannel -ErrorAction Ignore
}

function CopyFiles(){
    cp $BaseDir\flanneld.exe c:\flannel\flanneld.exe
    cp $BaseDir\net-conf.json C:\etc\kube-flannel\net-conf.json
}

SetupDirectories
CopyFiles

ipmo $helper

# Prepare Network & Start Infra services
$NetworkMode = "L2Bridge"
$NetworkName = "cbr0"
# CleanupOldNetwork $NetworkName

# before flannel start, kube-api must have this node
$hns = "$BaseDir\scripts\hns.psm1"
ipmo $hns

# Create a L2Bridge to trigger a vSwitch creation. Do this only once as it causes network blip
if(!(Get-HnsNetwork | ? Name -EQ "External"))
{
    New-HNSNetwork -Type $NetworkMode -AddressPrefix "192.168.255.0/30" -Gateway "192.168.255.1" -Name "External" -Verbose
}
# Start Flanneld
Start-Sleep 5
# CleanupOldNetwork $NetworkName
# Start FlannelD, which would recreate the network.
# Expect disruption in node connectivity for few seconds
[Environment]::SetEnvironmentVariable("NODE_NAME", (hostname).ToLower())
C:\rainbond\flanneld.exe --kubeconfig-file=C:\rainbond\config --iface=$ipaddress --healthz-port=10110 --ip-masq=1 --kube-subnet-mgr=1
