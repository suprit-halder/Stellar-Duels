# 🎮 Stellar Duels - Decentralized PvP Combat Game

A complete turn-based combat game built on the **Soroban Smart Contract Platform** (Stellar blockchain). This project demonstrates core blockchain gaming concepts including on-chain state management, cryptographic commitments, and token staking.

## 🎯 What You'll Learn

- **Smart Contract Development**: Writing and deploying Soroban contracts in Rust
- **State Management**: Persistent on-chain storage for players and games
- **Commit-Reveal Scheme**: Cryptographic hiding of player moves to prevent cheating
- **Token Integration**: Staking and distributing XLM tokens
- **Blockchain Game Design**: Fair, trustless PvP gameplay

## 🏗️ Architecture Overview

### Game Flow

```
1. Register Players → 2. Create Game → 3. Join Game → 4. Commit Moves → 5. Reveal Moves → 6. Finalize & Distribute Prizes
```

### Combat Mechanics (Rock-Paper-Scissors Style)

- **Attack (1)** beats **Defense (2)** - Overwhelms shields
- **Defense (2)** beats **Magic (3)** - Blocks spells
- **Magic (3)** beats **Attack (1)** - Confuses warriors

### Commit-Reveal Protocol

**Why?** In blockchain, all transactions are public. If players submitted moves directly, the second player would see the first player's move and always win.

**Solution:** Two-phase commit-reveal:

1. **Commit Phase**: Each player submits `SHA256(move || salt)` where salt is a random 32-byte secret
2. **Reveal Phase**: Players reveal their move and salt. Contract verifies the hash matches.

This ensures both players commit to their moves before either is revealed.

## 📁 Project Structure

```
stellar_duels/
├── Cargo.toml              # Rust dependencies and build config
├── src/
│   └── lib.rs              # Main smart contract (700+ lines, fully documented)
├── scripts/
│   ├── build.sh            # Build the contract
│   ├── deploy.sh           # Deploy to testnet
│   ├── play_game.sh        # Full game example
│   └── utils/
│       └── generate_commitment.js  # Helper to create commitments
├── README.md               # This file
└── docs/
    ├── ARCHITECTURE.md     # Deep dive into contract design
    └── CLI_REFERENCE.md    # All contract functions and parameters
```

## 🚀 Quick Start

### Prerequisites

1. **Install Rust**:
   ```bash
   curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
   ```

2. **Install Stellar CLI**:
   ```bash
   cargo install --locked stellar-cli
   ```

3. **Add WASM target**:
   ```bash
   rustup target add wasm32-unknown-unknown
   ```

4. **Configure testnet** (if not already done):
   ```bash
   stellar network add \
     --global testnet \
     --rpc-url https://soroban-testnet.stellar.org:443 \
     --network-passphrase "Test SDF Network ; September 2015"
   ```

5. **Create identity** (your player account):
   ```bash
   stellar keys generate --global player1 --network testnet
   stellar keys generate --global player2 --network testnet
   ```

6. **Fund accounts** (get test XLM):
   ```bash
   stellar keys fund player1 --network testnet
   stellar keys fund player2 --network testnet
   ```

### Build and Deploy

```bash
# Build the contract
stellar contract build

# Deploy to testnet
stellar contract deploy \
  --wasm target/wasm32-unknown-unknown/release/stellar_duels.wasm \
  --source player1 \
  --network testnet
```

Save the contract ID that gets returned (e.g., `CCXYZ...`).

## 🎮 Playing a Game

### Step 1: Register Players

```bash
stellar contract invoke \
  --id <CONTRACT_ID> \
  --source player1 \
  --network testnet \
  -- register_player \
  --player player1

stellar contract invoke \
  --id <CONTRACT_ID> \
  --source player2 \
  --network testnet \
  -- register_player \
  --player player2
```

### Step 2: Create a Game

```bash
# Player 1 creates game with 100 XLM stake
stellar contract invoke \
  --id <CONTRACT_ID> \
  --source player1 \
  --network testnet \
  -- create_game \
  --creator player1 \
  --stake_amount 1000000000 \
  --token_address <NATIVE_TOKEN_ADDRESS>
```

> **Note**: XLM amounts are in stroops (1 XLM = 10,000,000 stroops). Use native token address for XLM.

This returns a `game_id` (e.g., `1`).

### Step 3: Join the Game

```bash
# Player 2 joins with matching stake
stellar contract invoke \
  --id <CONTRACT_ID> \
  --source player2 \
  --network testnet \
  -- join_game \
  --game_id 1 \
  --player player2 \
  --token_address <NATIVE_TOKEN_ADDRESS>
```

### Step 4: Generate and Submit Commitments

**Off-chain** (use Node.js or Python):

```javascript
// generate_commitment.js
const crypto = require('crypto');

function generateCommitment(moveId) {
  // Generate random 32-byte salt
  const salt = crypto.randomBytes(32);
  
  // Convert move to 4 bytes (big-endian)
  const moveBuffer = Buffer.allocUnsafe(4);
  moveBuffer.writeUInt32BE(moveId);
  
  // Concatenate move + salt
  const data = Buffer.concat([moveBuffer, salt]);
  
  // Hash with SHA256
  const commitment = crypto.createHash('sha256').update(data).digest('hex');
  
  return { commitment, salt: salt.toString('hex') };
}

// Player 1 chooses Attack (1)
const p1 = generateCommitment(1);
console.log('Player 1 Commitment:', p1.commitment);
console.log('Player 1 Salt:', p1.salt);

// Player 2 chooses Magic (3)
const p2 = generateCommitment(3);
console.log('Player 2 Commitment:', p2.commitment);
console.log('Player 2 Salt:', p2.salt);
```

Run: `node generate_commitment.js`

**On-chain** (submit commitments):

```bash
# Player 1 submits commitment
stellar contract invoke \
  --id <CONTRACT_ID> \
  --source player1 \
  --network testnet \
  -- commit_move \
  --game_id 1 \
  --player player1 \
  --commitment <P1_COMMITMENT_HEX>

# Player 2 submits commitment
stellar contract invoke \
  --id <CONTRACT_ID> \
  --source player2 \
  --network testnet \
  -- commit_move \
  --game_id 1 \
  --player player2 \
  --commitment <P2_COMMITMENT_HEX>
```

### Step 5: Reveal Moves

```bash
# Player 1 reveals Attack (1) with their salt
stellar contract invoke \
  --id <CONTRACT_ID> \
  --source player1 \
  --network testnet \
  -- reveal_move \
  --game_id 1 \
  --player player1 \
  --move_choice 1 \
  --salt <P1_SALT_HEX>

# Player 2 reveals Magic (3) with their salt
stellar contract invoke \
  --id <CONTRACT_ID> \
  --source player2 \
  --network testnet \
  -- reveal_move \
  --game_id 1 \
  --player player2 \
  --move_choice 3 \
  --salt <P2_SALT_HEX>
```

### Step 6: Finalize Game

```bash
stellar contract invoke \
  --id <CONTRACT_ID> \
  --source player1 \
  --network testnet \
  -- finalize_game \
  --game_id 1 \
  --token_address <NATIVE_TOKEN_ADDRESS>
```

**Result**: Magic (3) beats Attack (1) → Player 2 wins and receives 200 XLM!

## 📊 Query Functions

### Get Player Stats

```bash
stellar contract invoke \
  --id <CONTRACT_ID> \
  --source player1 \
  --network testnet \
  -- get_player \
  --player player1
```

### Get Game Details

```bash
stellar contract invoke \
  --id <CONTRACT_ID> \
  --source player1 \
  --network testnet \
  -- get_game \
  --game_id 1
```

### List Active Games

```bash
stellar contract invoke \
  --id <CONTRACT_ID> \
  --source player1 \
  --network testnet \
  -- get_active_games
```

## 🧪 Testing

Run unit tests:

```bash
cargo test
```

Run specific test:

```bash
cargo test test_commitment_calculation -- --nocapture
```

## 🔒 Security Considerations

1. **Commitment Security**: Always use cryptographically secure random salts (32 bytes minimum)
2. **Front-Running**: The commit-reveal scheme prevents move snooping
3. **Abandonment**: Consider adding timeout mechanisms for incomplete games
4. **Reentrancy**: Soroban's execution model prevents reentrancy attacks
5. **Integer Overflow**: Profile uses `opt-level="z"` with overflow checks enabled

## 🎓 Learning Path for Beginners

### Understanding the Code

1. **Start with data structures** (`lib.rs` lines 20-90)
   - `Move` enum: represents player actions
   - `Game` struct: the complete game state
   - `DataKey` enum: how we organize storage

2. **Study storage patterns** (`register_player`, line 120)
   - `env.storage().persistent()`: long-term data
   - Key-value model: `DataKey::Player(address) → Player struct`

3. **Understand authorization** (`require_auth()` calls)
   - Ensures only the player can act for themselves
   - Prevents impersonation

4. **Learn commit-reveal** (`commit_move` + `reveal_move`)
   - Why: prevents cheating in public blockchain
   - How: cryptographic hashing

5. **Trace the game flow**
   - Create → Join → Commit → Reveal → Finalize
   - State transitions: `GameState` enum

### Next Steps

- **Add Features**: Implement timeouts, spectator mode, tournaments
- **Frontend**: Build a web UI with Stellar SDK for JavaScript
- **Advanced**: Add NFT rewards, ranking system, multiple move types
- **Mainnet**: Deploy to production (use real XLM carefully!)

## 📚 Resources

- [Soroban Docs](https://soroban.stellar.org/docs)
- [Stellar CLI Reference](https://developers.stellar.org/docs/tools/cli)
- [Soroban SDK Docs](https://docs.rs/soroban-sdk/)
- [Example Contracts](https://github.com/stellar/soroban-examples)

## 🤝 Contributing

This is an educational project! Ideas for improvement:

- Add matchmaking system
- Implement ELO rating
- Create tournament bracket logic
- Build React/Next.js frontend
- Add move history and replay system

## 📄 License

MIT License - Educational use encouraged!

## 💡 Tips & Tricks

### Getting Native Token Address

```bash
stellar contract id asset --asset native --network testnet
```

### Checking Balances

```bash
stellar contract invoke \
  --id <NATIVE_TOKEN_ADDRESS> \
  --source player1 \
  --network testnet \
  -- balance \
  --id player1
```

### Debugging Failed Transactions

Add `--fee 1000000` if you get "insufficient fee" errors.

### Resetting Testnet Data

Your test XLM and deployed contracts persist. To start fresh:
- Generate new identities
- Deploy new contract instance

---

**Happy Dueling! ⚔️✨**

Questions? Issues? Check the code comments in `src/lib.rs` - every function is documented for learners!
