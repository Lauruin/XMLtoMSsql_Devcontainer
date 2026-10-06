Install-Module -Name dbatools -Scope CurrentUser -Force   # one-time

$secure = ConvertTo-SecureString $env:MSSQL_SA_PASSWORD -AsPlainText -Force
$cred   = [System.Management.Automation.PSCredential]::new("sa", $secure)

$rows = Import-Csv ./out/personal.csv

Write-DbaDbTableData -SqlInstance 'localhost,1433' -Database 'Library' `
    -Table 'dbo.Employees' -InputObject $rows #-AutoCreateTable `
    -SqlCredential $cred #-TrustServerCertificate
