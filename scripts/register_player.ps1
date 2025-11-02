# ============================================================================
# REGISTER_PLAYER.PS1 - Register a player in Stellar Duels
# ============================================================================

param(
    [Parameter(Mandatory=$true)]
    [string]$Player,
    [string]$Network = "testnet"
)

Write-Host "👤 Registering player: $Player" -ForegroundColor Cyan
Write-Host ""

# Get contract ID
if (-not (Test-Path ".contract_id")) {
    Write-Host "❌ Contract ID not found. Deploy the contract first:" -ForegroundColor Red
    Write-Host "   .\scripts\deploy.ps1" -ForegroundColor White
    exit 1
}

$contractId = Get-Content ".contract_id" -Raw
$contractId = $contractId.Trim()

Write-Host "📋 Contract ID: $contractId" -ForegroundColor Gray
Write-Host ""

# Register player
Write-Host "📝 Registering..." -ForegroundColor Yellow

stellar contract invoke `
    --id $contractId `
    --source $Player `
    --network $Network `
    -- register_player `
    --player $Player

if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "✅ Player registered successfully!" -ForegroundColor Green
    Write-Host ""
    Write-Host "📊 View stats with:" -ForegroundColor Yellow
    Write-Host "   stellar contract invoke --id $contractId --source $Player --network $Network -- get_player --player $Player" -ForegroundColor Gray
} else {
    Write-Host ""
    Write-Host "❌ Registration failed" -ForegroundColor Red
    exit 1
}
