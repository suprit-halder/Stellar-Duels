# ============================================================================
# DEPLOY.PS1 - Deploy Stellar Duels to Testnet
# ============================================================================
# This script deploys your compiled contract to the Stellar testnet
# ============================================================================

param(
    [string]$Source = "player1",  # Identity to use for deployment
    [string]$Network = "testnet"
)

Write-Host "🚀 Deploying Stellar Duels to $Network..." -ForegroundColor Cyan
Write-Host ""

# Check if WASM file exists
$wasmPath = "target/wasm32-unknown-unknown/release/stellar_duels.wasm"
if (-not (Test-Path $wasmPath)) {
    Write-Host "❌ WASM file not found. Build the contract first:" -ForegroundColor Red
    Write-Host "   .\scripts\build.ps1" -ForegroundColor White
    exit 1
}

# Check if source identity exists
Write-Host "🔑 Checking identity: $Source" -ForegroundColor Yellow
$identityCheck = stellar keys show $Source 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Identity '$Source' not found. Create it with:" -ForegroundColor Red
    Write-Host "   stellar keys generate --global $Source --network $Network" -ForegroundColor White
    Write-Host "   stellar keys fund $Source --network $Network" -ForegroundColor White
    exit 1
}

Write-Host "✅ Identity found" -ForegroundColor Green
Write-Host ""

# Deploy the contract
Write-Host "📤 Deploying contract..." -ForegroundColor Yellow
Write-Host "   This may take a moment..." -ForegroundColor Gray
Write-Host ""

$deployment = stellar contract deploy `
    --wasm $wasmPath `
    --source $Source `
    --network $Network 2>&1

if ($LASTEXITCODE -eq 0) {
    $contractId = $deployment | Select-Object -Last 1
    
    Write-Host ""
    Write-Host "✅ Deployment successful!" -ForegroundColor Green
    Write-Host ""
    Write-Host "📋 CONTRACT ID:" -ForegroundColor Cyan
    Write-Host "   $contractId" -ForegroundColor White
    Write-Host ""
    Write-Host "💾 Saving to .contract_id file..." -ForegroundColor Yellow
    $contractId | Out-File -FilePath ".contract_id" -Encoding utf8 -NoNewline
    Write-Host "✅ Saved!" -ForegroundColor Green
    Write-Host ""
    Write-Host "🎮 Next steps:" -ForegroundColor Yellow
    Write-Host "   1. Register players: .\scripts\register_player.ps1 -Player player1" -ForegroundColor White
    Write-Host "   2. Play a game: .\scripts\play_game.ps1" -ForegroundColor White
    Write-Host ""
    Write-Host "📚 Or use the contract directly:" -ForegroundColor Yellow
    Write-Host "   stellar contract invoke --id $contractId --source $Source --network $Network -- <function_name>" -ForegroundColor Gray
} else {
    Write-Host ""
    Write-Host "❌ Deployment failed:" -ForegroundColor Red
    Write-Host $deployment -ForegroundColor Red
    exit 1
}
