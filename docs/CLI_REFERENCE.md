# CLI Reference - Stellar Duels Contract Functions

Complete reference for all contract functions with examples.

---

## Setup Commands

### Get Native Token Address (XLM)

```powershell
stellar contract id asset --asset native --network testnet
```

**Output**: Contract address for native XLM (e.g., `CDLZFC3SYJYD...`)

Save this - you'll need it for all stake-related functions.

---

## Player Management

### register_player

Register a new player or retrieve existing player profile.

**Signature**:
```rust
fn register_player(env: Env, player: Address) -> Player
```

**Parameters**:
- `player` (Address): The player's Stellar address

**Returns**: Player struct with stats (wins, losses, draws)

**Example**:
```powershell
stellar contract invoke `
  --id <CONTRACT_ID> `
  --source player1 `
  --network testnet `
  -- register_player `
  --player player1
```

**Output**:
```json
{
  "address": "GAXYZ...",
  "wins": 0,
  "losses": 0,
  "draws": 0
}
```

**Notes**:
- Idempotent: calling multiple times is safe
- Required before creating or joining games
- Requires authorization (`player.require_auth()`)

---

### get_player

Query a player's statistics.

**Signature**:
```rust
fn get_player(env: Env, player: Address) -> Option<Player>
```

**Parameters**:
- `player` (Address): The player's address to query

**Returns**: `Some(Player)` if registered, `None` otherwise

**Example**:
```powershell
stellar contract invoke `
  --id <CONTRACT_ID> `
  --source anyone `
  --network testnet `
  -- get_player `
  --player GAXYZ...
```

**Notes**:
- Read-only: no authorization required
- Returns None for unregistered players

---

## Game Management

### create_game

Create a new game with a stake amount.

**Signature**:
```rust
fn create_game(
    env: Env,
    creator: Address,
    stake_amount: i128,
    token_address: Address
) -> u64
```

**Parameters**:
- `creator` (Address): The game creator (becomes player_one)
- `stake_amount` (i128): Amount to stake in stroops (1 XLM = 10,000,000 stroops)
- `token_address` (Address): Token contract address (use native XLM address)

**Returns**: Game ID (u64)

**Example**:
```powershell
# Stake 100 XLM (1,000,000,000 stroops)
$tokenAddr = stellar contract id asset --asset native --network testnet

stellar contract invoke `
  --id <CONTRACT_ID> `
  --source player1 `
  --network testnet `
  -- create_game `
  --creator player1 `
  --stake_amount 1000000000 `
  --token_address $tokenAddr
```

**Output**: `1` (game ID)

**Side Effects**:
- Transfers `stake_amount` XLM from creator to contract
- Increments global game counter
- Adds game to active games list

**Requirements**:
- Creator must be registered
- Creator must have sufficient XLM balance + gas
- Requires authorization

---

### join_game

Join an existing game as player_two.

**Signature**:
```rust
fn join_game(
    env: Env,
    game_id: u64,
    player: Address,
    token_address: Address
) -> Game
```

**Parameters**:
- `game_id` (u64): The game ID to join
- `player` (Address): The joining player's address
- `token_address` (Address): Token contract address

**Returns**: Updated Game struct

**Example**:
```powershell
$tokenAddr = stellar contract id asset --asset native --network testnet

stellar contract invoke `
  --id <CONTRACT_ID> `
  --source player2 `
  --network testnet `
  -- join_game `
  --game_id 1 `
  --player player2 `
  --token_address $tokenAddr
```

**Side Effects**:
- Transfers matching `stake_amount` from player to contract
- Sets `game.player_two` to joining player

**Requirements**:
- Game must exist
- Game state must be `WaitingForPlayer`
- Player cannot be the same as player_one
- Player must be registered
- Requires authorization

---

### get_game

Retrieve game data.

**Signature**:
```rust
fn get_game(env: Env, game_id: u64) -> Option<Game>
```

**Parameters**:
- `game_id` (u64): The game ID to query

**Returns**: `Some(Game)` if exists, `None` otherwise

**Example**:
```powershell
stellar contract invoke `
  --id <CONTRACT_ID> `
  --source anyone `
  --network testnet `
  -- get_game `
  --game_id 1
```

**Output**:
```json
{
  "game_id": 1,
  "player_one": "GAXYZ...",
  "player_two": "GABCD...",
  "stake_amount": 1000000000,
  "state": "MovesCommitted",
  "p1_commitment": "7a3f2e...",
  "p2_commitment": "9b2c1d...",
  "p1_move": null,
  "p2_move": null,
  "winner": null
}
```

**Notes**:
- Read-only: no authorization required
- Useful for monitoring game progress

---

### get_active_games

List all active game IDs.

**Signature**:
```rust
fn get_active_games(env: Env) -> Vec<u64>
```

**Returns**: Vector of game IDs in `WaitingForPlayer` or `MovesCommitted` state

**Example**:
```powershell
stellar contract invoke `
  --id <CONTRACT_ID> `
  --source anyone `
  --network testnet `
  -- get_active_games
```

**Output**: `[1, 3, 7]`

**Notes**:
- Games are removed from this list when finalized
- Useful for matchmaking UIs

---

## Commit-Reveal Mechanism

### commit_move

Submit a cryptographic commitment for your move.

**Signature**:
```rust
fn commit_move(
    env: Env,
    game_id: u64,
    player: Address,
    commitment: BytesN<32>
) -> Game
```

**Parameters**:
- `game_id` (u64): The game ID
- `player` (Address): Your address (must be player_one or player_two)
- `commitment` (BytesN<32>): SHA256 hash of (move_id || salt)

**Returns**: Updated Game struct

**Generating Commitment** (off-chain):

**JavaScript**:
```javascript
const crypto = require('crypto');

function generateCommitment(moveId) {
    const salt = crypto.randomBytes(32);
    const moveBuffer = Buffer.allocUnsafe(4);
    moveBuffer.writeUInt32BE(moveId);
    const data = Buffer.concat([moveBuffer, salt]);
    const commitment = crypto.createHash('sha256').update(data).digest('hex');
    return { commitment, salt: salt.toString('hex') };
}

const { commitment, salt } = generateCommitment(1); // 1=Attack
console.log('Commitment:', commitment);
console.log('Salt (keep secret!):', salt);
```

**PowerShell**:
```powershell
node scripts/utils/generate_commitment.js 1
```

**Example**:
```powershell
# Assume commitment = 7a3f2e1d9c8b7a6f... from generator
stellar contract invoke `
  --id <CONTRACT_ID> `
  --source player1 `
  --network testnet `
  -- commit_move `
  --game_id 1 `
  --player player1 `
  --commitment 7a3f2e1d9c8b7a6f5e4d3c2b1a0f9e8d7c6b5a4f3e2d1c0b9a8f7e6d5c4b3a2f
```

**State Transitions**:
- First commitment: stays in `WaitingForPlayer` or current state
- Second commitment: advances to `MovesCommitted`

**Requirements**:
- Game must have two players
- Player must not have already committed
- Requires authorization

**CRITICAL**: Keep your salt secret until reveal phase!

---

### reveal_move

Reveal your move and verify it matches your commitment.

**Signature**:
```rust
fn reveal_move(
    env: Env,
    game_id: u64,
    player: Address,
    move_choice: u32,
    salt: BytesN<32>
) -> Game
```

**Parameters**:
- `game_id` (u64): The game ID
- `player` (Address): Your address
- `move_choice` (u32): Your move (1=Attack, 2=Defense, 3=Magic)
- `salt` (BytesN<32>): The random salt you used for commitment

**Returns**: Updated Game struct

**Move Values**:
- `1` = Attack (beats Defense)
- `2` = Defense (beats Magic)
- `3` = Magic (beats Attack)

**Example**:
```powershell
# Using the salt from commitment generation
stellar contract invoke `
  --id <CONTRACT_ID> `
  --source player1 `
  --network testnet `
  -- reveal_move `
  --game_id 1 `
  --player player1 `
  --move_choice 1 `
  --salt 9b8a7c6d5e4f3a2b1c0d9e8f7a6b5c4d3e2f1a0b9c8d7e6f5a4b3c2d1e0f9a8b
```

**Verification**:
The contract recalculates:
```
calculated_hash = SHA256(move_choice || salt)
```
And compares to your stored commitment. Transaction fails if mismatch.

**Requirements**:
- Game state must be `MovesCommitted`
- Player must have submitted a commitment
- `SHA256(move_choice || salt)` must match commitment
- `move_choice` must be 1, 2, or 3
- Requires authorization

**Common Errors**:
- `"Move does not match commitment"`: Salt or move doesn't match what you committed
- `"Invalid move"`: move_choice not in range [1, 3]

---

## Game Resolution

### finalize_game

Determine the winner and distribute prizes.

**Signature**:
```rust
fn finalize_game(
    env: Env,
    game_id: u64,
    token_address: Address
) -> Game
```

**Parameters**:
- `game_id` (u64): The game ID to finalize
- `token_address` (Address): Token contract address for prize distribution

**Returns**: Final Game struct with winner determined

**Example**:
```powershell
$tokenAddr = stellar contract id asset --asset native --network testnet

stellar contract invoke `
  --id <CONTRACT_ID> `
  --source anyone `
  --network testnet `
  -- finalize_game `
  --game_id 1 `
  --token_address $tokenAddr
```

**Side Effects**:
- **If there's a winner**:
  - Transfers entire pot (stake × 2) to winner
  - Updates winner's `wins` count (+1)
  - Updates loser's `losses` count (+1)
- **If it's a draw**:
  - Refunds stake to both players
  - Updates both players' `draws` count (+1)
- Sets `game.state` to `Completed`
- Removes game from active games list

**Win Conditions**:
- Attack (1) beats Defense (2)
- Defense (2) beats Magic (3)
- Magic (3) beats Attack (1)
- Same move = Draw

**Requirements**:
- Game state must be `MovesCommitted`
- Both players must have revealed their moves
- Can be called by anyone (no authorization needed)

**Notes**:
- This is the only way to unlock staked funds
- Idempotent: calling multiple times on completed game is safe (no-op)

---

## Complete Game Flow Example

### 1. Setup (One-time)

```powershell
# Generate identities
stellar keys generate --global player1 --network testnet
stellar keys generate --global player2 --network testnet

# Fund with test XLM
stellar keys fund player1 --network testnet
stellar keys fund player2 --network testnet

# Get token address
$tokenAddr = stellar contract id asset --asset native --network testnet

# Deploy contract
stellar contract deploy `
  --wasm target/wasm32-unknown-unknown/release/stellar_duels.wasm `
  --source player1 `
  --network testnet

# Save contract ID
$contractId = "<returned_contract_id>"
```

### 2. Register Players

```powershell
stellar contract invoke `
  --id $contractId --source player1 --network testnet `
  -- register_player --player player1

stellar contract invoke `
  --id $contractId --source player2 --network testnet `
  -- register_player --player player2
```

### 3. Create and Join Game

```powershell
# Player 1 creates game (100 XLM stake)
$gameId = stellar contract invoke `
  --id $contractId --source player1 --network testnet `
  -- create_game `
  --creator player1 `
  --stake_amount 1000000000 `
  --token_address $tokenAddr

# Player 2 joins
stellar contract invoke `
  --id $contractId --source player2 --network testnet `
  -- join_game `
  --game_id $gameId `
  --player player2 `
  --token_address $tokenAddr
```

### 4. Generate Commitments (Off-chain)

```powershell
# Player 1 chooses Attack (1)
node scripts/utils/generate_commitment.js 1
# Output: commitment=7a3f..., salt=9b8a...
$p1Commit = "7a3f..."
$p1Salt = "9b8a..."

# Player 2 chooses Magic (3)
node scripts/utils/generate_commitment.js 3
# Output: commitment=5c2d..., salt=8f7e...
$p2Commit = "5c2d..."
$p2Salt = "8f7e..."
```

### 5. Commit Moves

```powershell
stellar contract invoke `
  --id $contractId --source player1 --network testnet `
  -- commit_move `
  --game_id $gameId --player player1 --commitment $p1Commit

stellar contract invoke `
  --id $contractId --source player2 --network testnet `
  -- commit_move `
  --game_id $gameId --player player2 --commitment $p2Commit
```

### 6. Reveal Moves

```powershell
stellar contract invoke `
  --id $contractId --source player1 --network testnet `
  -- reveal_move `
  --game_id $gameId --player player1 --move_choice 1 --salt $p1Salt

stellar contract invoke `
  --id $contractId --source player2 --network testnet `
  -- reveal_move `
  --game_id $gameId --player player2 --move_choice 3 --salt $p2Salt
```

### 7. Finalize

```powershell
stellar contract invoke `
  --id $contractId --source player1 --network testnet `
  -- finalize_game --game_id $gameId --token_address $tokenAddr
```

**Result**: Player 2 wins (Magic beats Attack) and receives 200 XLM!

---

## Error Messages

Common errors and solutions:

| Error | Cause | Solution |
|-------|-------|----------|
| `Player must be registered first` | Calling game function before registering | Run `register_player` first |
| `Game not found` | Invalid game_id | Check `get_active_games()` |
| `Cannot play against yourself` | player_one == player_two | Use different addresses |
| `Game already has two players` | Trying to join full game | Create new game |
| `Move does not match commitment` | Wrong salt or move in reveal | Use exact salt from commitment generation |
| `Invalid move` | move_choice not 1, 2, or 3 | Use valid move ID |
| `Not ready for reveals` | Revealing before both committed | Wait for both commitments |
| `Insufficient funds` | Not enough XLM for stake | Fund account with `stellar keys fund` |

---

## Tips & Tricks

### Checking Balances

```powershell
$nativeToken = stellar contract id asset --asset native --network testnet

stellar contract invoke `
  --id $nativeToken `
  --source player1 `
  --network testnet `
  -- balance --id player1
```

### Watching a Game

```powershell
# Poll game state
while ($true) {
    stellar contract invoke `
      --id $contractId --source player1 --network testnet `
      -- get_game --game_id 1
    Start-Sleep -Seconds 5
}
```

### Converting XLM to Stroops

```powershell
$xlmAmount = 100
$stroops = $xlmAmount * 10000000
Write-Host "Stake: $stroops stroops"
```

### Debugging Failed Transactions

Add verbose logging:
```powershell
stellar contract invoke --help  # See all options
# Add: --fee 1000000 for higher gas limit
```

---

## Advanced Usage

### Scripting Multiple Games

```powershell
# Tournament script
1..8 | ForEach-Object {
    $gameId = stellar contract invoke ... -- create_game ...
    Write-Host "Created game $gameId"
}
```

### Event Monitoring

```powershell
# Check recent transactions
stellar account get-transactions <player_address> --network testnet
```

---

**Full Documentation**: See `README.md` and `docs/ARCHITECTURE.md`
