# ============================================================================
# CHECK_SETUP.PS1 - Verify development environment
# ============================================================================
# Run this script to ensure all prerequisites are installed correctly
# ============================================================================

Write-Host ""
Write-Host "🔍 Stellar Duels - Environment Check" -ForegroundColor Cyan
Write-Host "=".PadRight(60, '=') -ForegroundColor Cyan
Write-Host ""

$allGood = $true

# Check Rust
Write-Host "Checking Rust..." -ForegroundColor Yellow
$rustVersion = rustc --version 2>$null
if ($LASTEXITCODE -eq 0) {
    Write-Host "  ✅ Rust installed: $rustVersion" -ForegroundColor Green
} else {
    Write-Host "  ❌ Rust not found" -ForegroundColor Red
    Write-Host "     Install from: https://rustup.rs/" -ForegroundColor Gray
    $allGood = $false
}

# Check Cargo
Write-Host "Checking Cargo..." -ForegroundColor Yellow
$cargoVersion = cargo --version 2>$null
if ($LASTEXITCODE -eq 0) {
    Write-Host "  ✅ Cargo installed: $cargoVersion" -ForegroundColor Green
} else {
    Write-Host "  ❌ Cargo not found" -ForegroundColor Red
    $allGood = $false
}

# Check Stellar CLI
Write-Host "Checking Stellar CLI..." -ForegroundColor Yellow
$stellarVersion = stellar --version 2>$null
if ($LASTEXITCODE -eq 0) {
    Write-Host "  ✅ Stellar CLI installed: $stellarVersion" -ForegroundColor Green
} else {
    Write-Host "  ❌ Stellar CLI not found" -ForegroundColor Red
    Write-Host "     Install with: cargo install --locked stellar-cli" -ForegroundColor Gray
    $allGood = $false
}

# Check WASM target
Write-Host "Checking WASM target..." -ForegroundColor Yellow
$wasmTarget = rustup target list --installed 2>$null | Select-String "wasm32-unknown-unknown"
if ($wasmTarget) {
    Write-Host "  ✅ WASM target installed" -ForegroundColor Green
} else {
    Write-Host "  ❌ WASM target not found" -ForegroundColor Red
    Write-Host "     Install with: rustup target add wasm32-unknown-unknown" -ForegroundColor Gray
    $allGood = $false
}

# Check Node.js (optional but recommended)
Write-Host "Checking Node.js (optional)..." -ForegroundColor Yellow
$nodeVersion = node --version 2>$null
if ($LASTEXITCODE -eq 0) {
    Write-Host "  ✅ Node.js installed: $nodeVersion" -ForegroundColor Green
} else {
    Write-Host "  ⚠️  Node.js not found (optional for commitment generation)" -ForegroundColor Yellow
    Write-Host "     Install from: https://nodejs.org/" -ForegroundColor Gray
}

# Check network configuration
Write-Host "Checking Stellar network configuration..." -ForegroundColor Yellow
$networks = stellar network ls 2>$null | Select-String "testnet"
if ($networks) {
    Write-Host "  ✅ Testnet configured" -ForegroundColor Green
} else {
    Write-Host "  ⚠️  Testnet not configured" -ForegroundColor Yellow
    Write-Host "     Configure with:" -ForegroundColor Gray
    Write-Host "     stellar network add --global testnet \" -ForegroundColor Gray
    Write-Host "       --rpc-url https://soroban-testnet.stellar.org:443 \" -ForegroundColor Gray
    Write-Host "       --network-passphrase 'Test SDF Network ; September 2015'" -ForegroundColor Gray
}

# Check identities
Write-Host "Checking player identities..." -ForegroundColor Yellow
$player1 = stellar keys show player1 2>$null
$player2 = stellar keys show player2 2>$null

if ($LASTEXITCODE -eq 0) {
    Write-Host "  ✅ Player identities found" -ForegroundColor Green
} else {
    Write-Host "  ⚠️  Player identities not found" -ForegroundColor Yellow
    Write-Host "     Create with:" -ForegroundColor Gray
    Write-Host "     stellar keys generate --global player1 --network testnet" -ForegroundColor Gray
    Write-Host "     stellar keys generate --global player2 --network testnet" -ForegroundColor Gray
    Write-Host "     stellar keys fund player1 --network testnet" -ForegroundColor Gray
    Write-Host "     stellar keys fund player2 --network testnet" -ForegroundColor Gray
}

# Check project structure
Write-Host "Checking project files..." -ForegroundColor Yellow
if (Test-Path "Cargo.toml") {
    Write-Host "  ✅ Cargo.toml found" -ForegroundColor Green
} else {
    Write-Host "  ❌ Cargo.toml not found - are you in the project directory?" -ForegroundColor Red
    $allGood = $false
}

if (Test-Path "src/lib.rs") {
    Write-Host "  ✅ src/lib.rs found" -ForegroundColor Green
} else {
    Write-Host "  ❌ src/lib.rs not found" -ForegroundColor Red
    $allGood = $false
}

# Summary
Write-Host ""
Write-Host "=".PadRight(60, '=') -ForegroundColor Cyan
if ($allGood) {
    Write-Host "✅ All critical checks passed! You're ready to build." -ForegroundColor Green
    Write-Host ""
    Write-Host "Next steps:" -ForegroundColor Yellow
    Write-Host "  1. Build the contract: .\scripts\build.ps1" -ForegroundColor White
    Write-Host "  2. Deploy to testnet: .\scripts\deploy.ps1" -ForegroundColor White
    Write-Host "  3. Play a game: .\scripts\play_game.ps1" -ForegroundColor White
} else {
    Write-Host "⚠️  Some required tools are missing. Install them and run this check again." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Quick install commands:" -ForegroundColor Yellow
    Write-Host "  Rust:        https://rustup.rs/" -ForegroundColor White
    Write-Host "  Stellar CLI: cargo install --locked stellar-cli" -ForegroundColor White
    Write-Host "  WASM target: rustup target add wasm32-unknown-unknown" -ForegroundColor White
}
Write-Host ""
