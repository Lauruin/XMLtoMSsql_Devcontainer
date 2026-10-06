# XML → CSV → Azure SQL (PowerShell devcontainer)

Parse an XML export, flatten it to CSV, and load it into SQL — all inside a
dev container, so the host stays clean.

## What this is

Two containers run side by side:

- **app** — the container you work in (Python base image, plus PowerShell, .NET 10 SDK,
  SqlPackage, sqlcmd, Azure CLI, azd, Docker CLI).
- **db** — a local SQL Server 2025 (Developer edition) at `localhost,1433` from inside `app`.

The `app` container shares the `db` container's network, so `localhost,1433` just works.
The database schema lives in a SQL Database project that targets **Azure SQL Database**,
so its build doubles as a compatibility check [1].

## Prerequisites

- Docker running on the host
- VS Code with the **Dev Containers** extension [1]

## Quick start

```bash
git clone <your-repo-url> xmlsql
cd xmlsql
cp .devcontainer/.env.example .devcontainer/.env   # then set a real sa password
code .
```

Then in VS Code: `F1` → **Dev Containers: Reopen in Container**. The first build pulls
both images and takes a few minutes [1].

To stop for the day: `F1` → **Dev Containers: Stop Container**, then shut down.

## Repo layout

```
.devcontainer/        container definition (docker-compose, devcontainer.json, mssql/)
database/Library/     SQL Database project (schema) — builds to Library.dacpac
scripts/              PowerShell pipeline + SQL helper scripts
data/                 source XML (sample committed; real exports ignored)
out/                  generated CSV (ignored)
```

## How the scripts work

### `scripts/XmlToCsv.ps1` — XML → CSV

```powershell
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
```

Three ideas do all the work:

1. **`[xml]`** casts the file text into a navigable object tree.
2. **`$doc.root.Record`** iterates the record elements; `$r.NACHN` grabs a child element.
3. **`[pscustomobject]`** turns each record into a "row". A `foreach` that emits objects
   collects them into an array automatically.

`-Encoding utf8BOM` is deliberate: it keeps umlauts intact and is friendly to SQL import.

### `scripts/Load-ToSql.ps1` — CSV → SQL

```powershell
Install-Module -Name dbatools -Scope CurrentUser -Force   # one-time

$secure = ConvertTo-SecureString $env:MSSQL_SA_PASSWORD -AsPlainText -Force
$cred   = [System.Management.Automation.PSCredential]::new("sa", $secure)

$rows = Import-Csv ./out/personal.csv

Write-DbaDbTableData -SqlInstance 'localhost,1433' -Database 'Library' `
    -Table 'dbo.Employees' -InputObject $rows -AutoCreateTable `
    -SqlCredential $cred -TrustServerCertificate
```

`Import-Csv` reverses the export. `Write-DbaDbTableData` uses **bulk copy**, so it stays
fast as the file grows, and `-AutoCreateTable` creates the target table on first run.
Prefer it over hand-built `INSERT` strings, which break on names containing apostrophes.

### `scripts/Verify.ps1` — check the result

```powershell
Invoke-Sqlcmd -ServerInstance 'localhost,1433' -Database 'Library' `
  -Credential $cred -TrustServerCertificate `
  -Query 'SELECT COUNT(*) AS n FROM dbo.Employees;'
```

## Step-by-step guide

1. **Set the password.** Put `MSSQL_SA_PASSWORD=...` in `.devcontainer/.env`. SQL Server
   needs at least eight characters from three of: uppercase, lowercase, digits, symbols.
   The template default is development-only and public — change it [1].
2. **Open in the container.** `F1` → **Dev Containers: Reopen in Container** [1].
3. **Confirm the container.** In the integrated terminal, run `pwsh -v` and check
   `localhost,1433` answers with `Invoke-Sqlcmd`.
4. **Add your XML.** Drop it in `data/` (the fake sample is committed; real exports are
   not).
5. **Convert.** `pwsh ./scripts/XmlToCsv.ps1` → inspect `out/personal.csv`.
6. **Load.** `pwsh ./scripts/Load-ToSql.ps1`.
7. **Verify.** `pwsh ./scripts/Verify.ps1` → expect the row count to match your records.
8. **Change the schema** by editing the `.sql` files in `database/Library`, then run the
   **Build SQL Database project** and **Publish SQL Database project** tasks in VS Code.
   If the build fails, the errors point at objects Azure SQL Database doesn't support [1].
9. **Point at Azure SQL** once local work is done — swap the credential for an access
   token (`az account get-access-token --resource https://database.windows.net`) and use
   your server name.

## Notes and gotchas

- **The local engine is not Azure SQL.** The SQL Database project sets its target platform
  to Azure SQL Database, so the *schema* build is your compatibility check. Test against a
  real Azure SQL Database before you ship [1].
- **If the db container never becomes healthy**, SQL Server likely crashed at startup.
  Run **Dev Containers: Rebuild Container** [1].
- **`Error: No such container`** after an interrupted rebuild: run **Dev Containers:
  Rebuild Container**; it rebuilds from scratch and republishes the database [1].
- **arm64 hosts**: SQL Server has no arm64 image and runs under unsupported emulation [1].
- **Corporate networks**: if creation fails with a connection reset, NuGet
  (`api.nuget.org`) is the usual culprit — point it at an allowed feed [1].
- **Never commit `.devcontainer/.env`.** Commit `.env.example` instead.

## Extras you can add

Optional Dev Container Features, added to the `features` block in
`.devcontainer/devcontainer.json` [2]:

- `ghcr.io/devcontainers/features/powershell:2` — PowerShell [2]
- `ghcr.io/eitsupi/devcontainer-features/jq-likes:2` — includes `xq` for XML inspection [2]
- `ghcr.io/eitsupi/devcontainer-features/duckdb-cli:1` — query the CSV with SQL [2]

## Sharing with teammates

The setup is entirely files, so GitHub carries it: commit `.devcontainer/`, `scripts/`,
`data/`, `database/`, the `.gitignore` and this README. A teammate clones, creates their
own `.devcontainer/.env`, opens the folder in VS Code and reopens in the container [1].# XMLtoMSsql_Devcontainer
