# ============================================================================
# PLAY_GAME.PS1 - Complete game walkthrough
# ============================================================================
# This script demonstrates a full game between two players
# ============================================================================

param(
    [string]$Player1 = "player1",
    [string]$Player2 = "player2",
    [int]$StakeAmount = 1000000000,  # 100 XLM in stroops
    [string]$Network = "testnet"
)

Write-Host ""
Write-Host "⚔️  STELLAR DUELS - Game Demo ⚔️" -ForegroundColor Cyan
Write-Host "=".PadRight(60, '=') -ForegroundColor Cyan
Write-Host ""

# Get contract ID
if (-not (Test-Path ".contract_id")) {
    Write-Host "❌ Contract not deployed. Run:" -ForegroundColor Red
    Write-Host "   .\scripts\deploy.ps1" -ForegroundColor White
    exit 1
}

$contractId = Get-Content ".contract_id" -Raw
$contractId = $contractId.Trim()

Write-Host "📋 Contract ID: $contractId" -ForegroundColor Gray
Write-Host "👥 Player 1: $Player1" -ForegroundColor Gray
Write-Host "👥 Player 2: $Player2" -ForegroundColor Gray
Write-Host "💰 Stake: $StakeAmount stroops" -ForegroundColor Gray
Write-Host ""

# Get native token address
Write-Host "🔍 Getting native token address..." -ForegroundColor Yellow
$tokenAddress = stellar contract id asset --asset native --network $Network 2>&1 | Select-Object -Last 1
Write-Host "✅ Token: $tokenAddress" -ForegroundColor Green
Write-Host ""

# ============================================================================
# STEP 1: Register Players
# ============================================================================

Write-Host "📝 STEP 1: Registering players..." -ForegroundColor Cyan
Write-Host ""

Write-Host "  Registering $Player1..." -ForegroundColor Yellow
stellar contract invoke `
    --id $contractId `
    --source $Player1 `
    --network $Network `
    -- register_player `
    --player $Player1 | Out-Null

Write-Host "  ✅ $Player1 registered" -ForegroundColor Green

Write-Host "  Registering $Player2..." -ForegroundColor Yellow
stellar contract invoke `
    --id $contractId `
    --source $Player2 `
    --network $Network `
    -- register_player `
    --player $Player2 | Out-Null

Write-Host "  ✅ $Player2 registered" -ForegroundColor Green
Write-Host ""

# ============================================================================
# STEP 2: Create Game
# ============================================================================

Write-Host "🎮 STEP 2: Creating game..." -ForegroundColor Cyan
Write-Host ""

$gameIdOutput = stellar contract invoke `
    --id $contractId `
    --source $Player1 `
    --network $Network `
    -- create_game `
    --creator $Player1 `
    --stake_amount $StakeAmount `
    --token_address $tokenAddress 2>&1

$gameId = $gameIdOutput | Select-Object -Last 1
Write-Host "  ✅ Game created with ID: $gameId" -ForegroundColor Green
Write-Host ""

# ============================================================================
# STEP 3: Join Game
# ============================================================================

Write-Host "🤝 STEP 3: Player 2 joining game..." -ForegroundColor Cyan
Write-Host ""

stellar contract invoke `
    --id $contractId `
    --source $Player2 `
    --network $Network `
    -- join_game `
    --game_id $gameId `
    --player $Player2 `
    --token_address $tokenAddress | Out-Null

Write-Host "  ✅ $Player2 joined the game" -ForegroundColor Green
Write-Host ""

# ============================================================================
# STEP 4: Generate Commitments
# ============================================================================

Write-Host "🎲 STEP 4: Generating secret moves..." -ForegroundColor Cyan
Write-Host ""

Write-Host "  ⚠️  In a real game, each player generates their commitment privately." -ForegroundColor Yellow
Write-Host "  ⚠️  For this demo, we'll generate both here (cheating for demo purposes!)." -ForegroundColor Yellow
Write-Host ""

# Check if Node.js is available
$nodeCheck = Get-Command node -ErrorAction SilentlyContinue
if (-not $nodeCheck) {
    Write-Host "  ⚠️  Node.js not found. Using manual commitments..." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  💡 To use the commitment generator, install Node.js from:" -ForegroundColor Cyan
    Write-Host "     https://nodejs.org/" -ForegroundColor White
    Write-Host ""
    Write-Host "  📖 Manual commitment generation:" -ForegroundColor Cyan
    Write-Host "     1. Choose move (1=Attack, 2=Defense, 3=Magic)" -ForegroundColor White
    Write-Host "     2. Generate random 32-byte salt" -ForegroundColor White
    Write-Host "     3. Compute: SHA256(move_bytes || salt_bytes)" -ForegroundColor White
    Write-Host ""
    Write-Host "  ⏭️  Skipping commitment phase for this demo..." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "✅ Demo complete! Manual steps:" -ForegroundColor Green
    Write-Host ""
    Write-Host "Next steps to play manually:" -ForegroundColor Yellow
    Write-Host "  1. Generate commitments (use scripts/utils/generate_commitment.js)" -ForegroundColor White
    Write-Host "  2. Both players: call commit_move with their commitment hash" -ForegroundColor White
    Write-Host "  3. Both players: call reveal_move with move_choice and salt" -ForegroundColor White
    Write-Host "  4. Anyone: call finalize_game to determine winner" -ForegroundColor White
    Write-Host ""
    Write-Host "Example commitment:" -ForegroundColor Yellow
    Write-Host "  node scripts/utils/generate_commitment.js 1" -ForegroundColor Gray
    Write-Host ""
    exit 0
}

# Generate commitments using Node.js
Write-Host "  🎲 Player 1 chooses: Attack (1)" -ForegroundColor White
$p1Json = node scripts/utils/generate_commitment.js 1 2>&1 | ConvertFrom-Json
$p1Commitment = $p1Json.commitment
$p1Salt = $p1Json.salt

Write-Host "  🎲 Player 2 chooses: Magic (3)" -ForegroundColor White
$p2Json = node scripts/utils/generate_commitment.js 3 2>&1 | ConvertFrom-Json
$p2Commitment = $p2Json.commitment
$p2Salt = $p2Json.salt

Write-Host ""
Write-Host "  ✅ Commitments generated" -ForegroundColor Green
Write-Host ""

# ============================================================================
# STEP 5: Commit Moves
# ============================================================================

Write-Host "🔒 STEP 5: Submitting commitments..." -ForegroundColor Cyan
Write-Host ""

Write-Host "  $Player1 commits..." -ForegroundColor Yellow
stellar contract invoke `
    --id $contractId `
    --source $Player1 `
    --network $Network `
    -- commit_move `
    --game_id $gameId `
    --player $Player1 `
    --commitment $p1Commitment | Out-Null

Write-Host "  ✅ Player 1 committed" -ForegroundColor Green

Write-Host "  $Player2 commits..." -ForegroundColor Yellow
stellar contract invoke `
    --id $contractId `
    --source $Player2 `
    --network $Network `
    -- commit_move `
    --game_id $gameId `
    --player $Player2 `
    --commitment $p2Commitment | Out-Null

Write-Host "  ✅ Player 2 committed" -ForegroundColor Green
Write-Host ""

# ============================================================================
# STEP 6: Reveal Moves
# ============================================================================

Write-Host "🔓 STEP 6: Revealing moves..." -ForegroundColor Cyan
Write-Host ""

Write-Host "  $Player1 reveals Attack..." -ForegroundColor Yellow
stellar contract invoke `
    --id $contractId `
    --source $Player1 `
    --network $Network `
    -- reveal_move `
    --game_id $gameId `
    --player $Player1 `
    --move_choice 1 `
    --salt $p1Salt | Out-Null

Write-Host "  ✅ Player 1 revealed" -ForegroundColor Green

Write-Host "  $Player2 reveals Magic..." -ForegroundColor Yellow
stellar contract invoke `
    --id $contractId `
    --source $Player2 `
    --network $Network `
    -- reveal_move `
    --game_id $gameId `
    --player $Player2 `
    --move_choice 3 `
    --salt $p2Salt | Out-Null

Write-Host "  ✅ Player 2 revealed" -ForegroundColor Green
Write-Host ""

# ============================================================================
# STEP 7: Finalize Game
# ============================================================================

Write-Host "🏆 STEP 7: Finalizing game..." -ForegroundColor Cyan
Write-Host ""

stellar contract invoke `
    --id $contractId `
    --source $Player1 `
    --network $Network `
    -- finalize_game `
    --game_id $gameId `
    --token_address $tokenAddress | Out-Null

Write-Host "  ✅ Game finalized!" -ForegroundColor Green
Write-Host ""

# ============================================================================
# STEP 8: Check Results
# ============================================================================

Write-Host "📊 STEP 8: Checking results..." -ForegroundColor Cyan
Write-Host ""

Write-Host "  Attack (1) vs Magic (3)" -ForegroundColor White
Write-Host "  Magic beats Attack!" -ForegroundColor Magenta
Write-Host ""
Write-Host "  🎉 Winner: $Player2" -ForegroundColor Green
Write-Host ""

Write-Host "Player stats:" -ForegroundColor Yellow
stellar contract invoke `
    --id $contractId `
    --source $Player1 `
    --network $Network `
    -- get_player `
    --player $Player1

stellar contract invoke `
    --id $contractId `
    --source $Player2 `
    --network $Network `
    -- get_player `
    --player $Player2

Write-Host ""
Write-Host "=".PadRight(60, '=') -ForegroundColor Cyan
Write-Host "✅ Game complete! Play again with:" -ForegroundColor Green
Write-Host "   .\scripts\play_game.ps1" -ForegroundColor White
Write-Host ""
