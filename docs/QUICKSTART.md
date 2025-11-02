# 🚀 Quick Start Guide - Stellar Duels

Complete setup guide for absolute beginners.

---

## Prerequisites

### 1. Install Rust

**Windows (PowerShell)**:
```powershell
# Download and run installer
Invoke-WebRequest -Uri "https://win.rustup.rs/x86_64" -OutFile "rustup-init.exe"
.\rustup-init.exe
```

Follow prompts, then restart your terminal.

**Verify**:
```powershell
rustc --version
# Should show: rustc 1.xx.x
```

---

### 2. Install Stellar CLI

```powershell
cargo install --locked stellar-cli
```

This takes 5-10 minutes. Grab a coffee! ☕

**Verify**:
```powershell
stellar --version
# Should show: stellar-cli x.x.x
```

---

### 3. Add WASM Target

Soroban contracts compile to WebAssembly:

```powershell
rustup target add wasm32-unknown-unknown
```

---

### 4. Configure Testnet

```powershell
stellar network add `
  --global testnet `
  --rpc-url https://soroban-testnet.stellar.org:443 `
  --network-passphrase "Test SDF Network ; September 2015"
```

**Verify**:
```powershell
stellar network ls
# Should list 'testnet'
```

---

### 5. Create Player Identities

```powershell
# Create two player identities
stellar keys generate --global player1 --network testnet
stellar keys generate --global player2 --network testnet
```

**View addresses**:
```powershell
stellar keys address player1
stellar keys address player2
```

---

### 6. Fund Accounts with Test XLM

```powershell
# Get 10,000 test XLM for each (from Friendbot)
stellar keys fund player1 --network testnet
stellar keys fund player2 --network testnet
```

**Verify balances**:
```powershell
stellar keys show player1
stellar keys show player2
```

---

## Build & Deploy

### 1. Clone/Navigate to Project

```powershell
cd "d:\New folder\stellar_duels"
```

### 2. Build Contract

```powershell
stellar contract build
```

**Expected output**:
```
   Compiling stellar_duels v0.1.0
   Finished release [optimized] target(s) in 12.3s
```

**WASM file created at**:
`target/wasm32-unknown-unknown/release/stellar_duels.wasm`

### 3. Deploy to Testnet

```powershell
stellar contract deploy `
  --wasm target/wasm32-unknown-unknown/release/stellar_duels.wasm `
  --source player1 `
  --network testnet
```

**Save the contract ID** (long string like `CCXYZ123...`):
```powershell
$contractId = "<paste_contract_id_here>"

# Or save to file
$contractId | Out-File -FilePath ".contract_id" -Encoding utf8 -NoNewline
```

---

## Play Your First Game

### Step 1: Get Native Token Address

```powershell
$tokenAddr = stellar contract id asset --asset native --network testnet
Write-Host "Token Address: $tokenAddr"
```

### Step 2: Register Players

```powershell
stellar contract invoke `
  --id $contractId `
  --source player1 `
  --network testnet `
  -- register_player `
  --player player1

stellar contract invoke `
  --id $contractId `
  --source player2 `
  --network testnet `
  -- register_player `
  --player player2
```

### Step 3: Create Game

```powershell
# Player 1 creates game with 100 XLM stake
$gameId = stellar contract invoke `
  --id $contractId `
  --source player1 `
  --network testnet `
  -- create_game `
  --creator player1 `
  --stake_amount 1000000000 `
  --token_address $tokenAddr

Write-Host "Game ID: $gameId"
```

### Step 4: Join Game

```powershell
stellar contract invoke `
  --id $contractId `
  --source player2 `
  --network testnet `
  -- join_game `
  --game_id $gameId `
  --player player2 `
  --token_address $tokenAddr
```

### Step 5: Generate Commitments

**Install Node.js** (if not already):
- Download from https://nodejs.org/
- Restart PowerShell after installation

**Generate moves**:
```powershell
# Player 1 chooses Attack (1)
node scripts/utils/generate_commitment.js 1
```

**Sample Output**:
```
🎲 Move Commitment Generated
============================================================

Move:       Attack (1)

Commitment (hash):
  7a3f2e1d9c8b7a6f5e4d3c2b1a0f9e8d7c6b5a4f3e2d1c0b9a8f7e6d5c4b3a2f

Salt (keep secret!):
  9b8a7c6d5e4f3a2b1c0d9e8f7a6b5c4d3e2f1a0b9c8d7e6f5a4b3c2d1e0f9a8b
```

**Save these values**:
```powershell
$p1Commitment = "7a3f2e1d9c8b7a6f5e4d3c2b1a0f9e8d7c6b5a4f3e2d1c0b9a8f7e6d5c4b3a2f"
$p1Salt = "9b8a7c6d5e4f3a2b1c0d9e8f7a6b5c4d3e2f1a0b9c8d7e6f5a4b3c2d1e0f9a8b"
```

**Repeat for Player 2** (choose Defense = 2):
```powershell
node scripts/utils/generate_commitment.js 2

$p2Commitment = "<paste_p2_commitment>"
$p2Salt = "<paste_p2_salt>"
```

### Step 6: Submit Commitments

```powershell
# Player 1 commits
stellar contract invoke `
  --id $contractId `
  --source player1 `
  --network testnet `
  -- commit_move `
  --game_id $gameId `
  --player player1 `
  --commitment $p1Commitment

# Player 2 commits
stellar contract invoke `
  --id $contractId `
  --source player2 `
  --network testnet `
  -- commit_move `
  --game_id $gameId `
  --player player2 `
  --commitment $p2Commitment
```

### Step 7: Reveal Moves

```powershell
# Player 1 reveals Attack (1)
stellar contract invoke `
  --id $contractId `
  --source player1 `
  --network testnet `
  -- reveal_move `
  --game_id $gameId `
  --player player1 `
  --move_choice 1 `
  --salt $p1Salt

# Player 2 reveals Defense (2)
stellar contract invoke `
  --id $contractId `
  --source player2 `
  --network testnet `
  -- reveal_move `
  --game_id $gameId `
  --player player2 `
  --move_choice 2 `
  --salt $p2Salt
```

### Step 8: Finalize Game

```powershell
stellar contract invoke `
  --id $contractId `
  --source player1 `
  --network testnet `
  -- finalize_game `
  --game_id $gameId `
  --token_address $tokenAddr
```

### Step 9: Check Results

```powershell
# Get final game state
stellar contract invoke `
  --id $contractId `
  --source player1 `
  --network testnet `
  -- get_game `
  --game_id $gameId

# Check player stats
stellar contract invoke `
  --id $contractId `
  --source player1 `
  --network testnet `
  -- get_player `
  --player player1

stellar contract invoke `
  --id $contractId `
  --source player2 `
  --network testnet `
  -- get_player `
  --player player2
```

**Result**: Attack (1) beats Defense (2) → Player 1 wins 200 XLM! 🎉

---

## Using the Helper Scripts

### Build Script

```powershell
.\scripts\build.ps1
```

Compiles the contract and shows file size.

### Deploy Script

```powershell
.\scripts\deploy.ps1 -Source player1 -Network testnet
```

Deploys contract and saves ID to `.contract_id`.

### Register Player Script

```powershell
.\scripts\register_player.ps1 -Player player1
.\scripts\register_player.ps1 -Player player2
```

### Full Game Demo (Automated)

```powershell
.\scripts\play_game.ps1 -Player1 player1 -Player2 player2 -StakeAmount 1000000000
```

Runs a complete game from start to finish!

---

## Troubleshooting

### Error: "command not found: stellar"

**Solution**: Restart your terminal after installing stellar-cli.

---

### Error: "Insufficient funds"

**Solution**: Fund your account again:
```powershell
stellar keys fund player1 --network testnet
```

---

### Error: "Move does not match commitment"

**Cause**: Used wrong salt or move ID.

**Solution**: Double-check you're using the exact salt from commitment generation.

---

### Error: "WASM file not found"

**Solution**: Build the contract first:
```powershell
stellar contract build
```

---

### Node.js not found

**Solution**:
1. Install from https://nodejs.org/
2. Restart PowerShell
3. Verify: `node --version`

---

## Next Steps

### 1. Read the Documentation

- `README.md` - Project overview
- `docs/ARCHITECTURE.md` - Deep dive into design
- `docs/CLI_REFERENCE.md` - Complete function reference

### 2. Experiment

Try different scenarios:
- Multiple games simultaneously
- Different stake amounts
- All move combinations (9 possibilities)

### 3. Build a Frontend

Ideas:
- Web UI with React + Stellar SDK
- Discord bot for playing
- Mobile app with Flutter

### 4. Extend the Contract

Add features:
- Tournaments
- ELO ratings
- NFT rewards
- Multiple move types

### 5. Deploy to Mainnet

**⚠️ Use real XLM carefully!**

```powershell
# Configure mainnet (public network)
stellar network add `
  --global mainnet `
  --rpc-url https://soroban-rpc.mainnet.stellar.org:443 `
  --network-passphrase "Public Global Stellar Network ; September 2015"

# Deploy (costs real XLM)
stellar contract deploy `
  --wasm target/wasm32-unknown-unknown/release/stellar_duels.wasm `
  --source <mainnet_identity> `
  --network mainnet
```

---

## Resources

- [Soroban Docs](https://soroban.stellar.org/docs)
- [Stellar CLI Docs](https://developers.stellar.org/docs/tools/cli)
- [Rust Book](https://doc.rust-lang.org/book/)
- [Soroban Examples](https://github.com/stellar/soroban-examples)

---

## Getting Help

- **Stellar Discord**: https://discord.gg/stellar
- **Stack Overflow**: Tag questions with `soroban` and `stellar`
- **GitHub Issues**: Report bugs in this repo

---

**Congratulations!** 🎉 You've built and deployed a blockchain game!

Now go create something amazing! ⚔️✨
