# Odoo 20 - Fix Collation and Run Script
# This script reads odoo.conf, fixes PostgreSQL collation issues, and initializes Odoo

$psqlPath = 'C:\Program Files\PostgreSQL\18\bin\psql.exe'
$configPath = '.\odoo.conf'

# Check if odoo.conf exists in the current directory
if (-not (Test-Path $configPath)) {
    Write-Error "Error: odoo.conf not found in the current directory."
    exit 1
}

# Parse odoo.conf for database settings
$dbName = $null
$dbUser = $null
$dbPassword = $null

foreach ($line in Get-Content $configPath) {
    if ($line -match '^\s*([a-zA-Z0-9_-]+)\s*=\s*(.*)$') {
        $key = $Matches[1].Trim()
        $value = $Matches[2].Trim()
        
        switch ($key) {
            'db_name'     { $dbName = $value }
            'db_user'     { $dbUser = $value }
            'db_password' { $dbPassword = $value }
        }
    }
}

# Fallbacks if any values are missing from the config file
if (-not $dbUser) { $dbUser = 'postgres' }
if (-not $dbName) { $dbName = 'odoo20_db' }
if ($dbPassword) {
    $env:PGPASSWORD = $dbPassword
}

Write-Host "[Info] Using Database: $dbName" -ForegroundColor Cyan
Write-Host "[Info] Using DB User: $dbUser" -ForegroundColor Cyan
Write-Host ""

# Step 3: Create database
Write-Host "[3/5] Creating $dbName with C collation..." -ForegroundColor Yellow
& $psqlPath -U $dbUser -h localhost -d postgres -c "CREATE DATABASE $dbName OWNER $dbUser LC_COLLATE='C' LC_CTYPE='C' TEMPLATE template0 ENCODING 'UTF8';" 2>&1 | Out-Null

# Step 4: Verify collation
Write-Host "[4/5] Verifying collation..." -ForegroundColor Yellow
& $psqlPath -U $dbUser -h localhost -d postgres -c "SELECT datname, datcollate, datctype FROM pg_database WHERE datname = '$dbName';"

Write-Host ""
Write-Host "[5/5] Initializing Odoo database..." -ForegroundColor Yellow
Write-Host ""

# Step 5: Initialize Odoo
python odoo-bin -c odoo.conf -i base -d $dbName --without-demo --stop-after-init