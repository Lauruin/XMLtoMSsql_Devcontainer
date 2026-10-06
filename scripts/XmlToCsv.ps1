param(
    [string]$XmlPath = "./data/personal.xml",
    [string]$CsvPath = "./out/personal.csv"
)

[xml]$doc = Get-Content -Path $XmlPath -Raw

$records = foreach ($r in $doc.root.Record) {
    [pscustomobject]@{
        PERNR = [int]$r.PERNR
        NACHN = $r.NACHN
        NAME2 = $r.NAME2
        VORNA = $r.VORNA
        GBJHR = [int]$r.GBJHR
        GBMON = [int]$r.GBMON
        GBTAG = [int]$r.GBTAG
        ENAME = $r.ENAME
    }
}

$records | Export-Csv -Path $CsvPath -NoTypeInformation -Encoding utf8BOM
Write-Host "Exported $($records.Count) records to $CsvPath"