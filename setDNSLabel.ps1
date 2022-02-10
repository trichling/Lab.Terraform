param (
    [Parameter(Mandatory)] [string] $ClusterName,
    [Parameter(Mandatory)] [string] $RessourceGroupInfrastructure
)

Write-Host "az network public-ip list -g $RessourceGroupInfrastructure --query ""[?tags.service=='ingress-nginx/ingress-nginx-controller'].name | [0]"""
$INGRESS_IP_NAME = $(az network public-ip list -g $RessourceGroupInfrastructure --query "[?tags.service=='ingress-nginx/ingress-nginx-controller'].name | [0]")  
$INGRESS_IP_NAME = $INGRESS_IP_NAME.Replace("""", "")
Write-Host $INGRESS_IP_NAME
Write-Host "az network public-ip update -g $RessourceGroupInfrastructure -n $INGRESS_IP_NAME --dns-name $ClusterName"
az network public-ip update -g $RessourceGroupInfrastructure -n $INGRESS_IP_NAME --dns-name $ClusterName