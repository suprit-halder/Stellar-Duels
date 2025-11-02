# Architecture Deep Dive - Stellar Duels

## Table of Contents
1. [System Overview](#system-overview)
2. [Smart Contract Architecture](#smart-contract-architecture)
3. [Data Structures](#data-structures)
4. [State Management](#state-management)
5. [Cryptographic Commit-Reveal](#cryptographic-commit-reveal)
6. [Game Flow & State Machine](#game-flow--state-machine)
7. [Security Considerations](#security-considerations)
8. [Gas Optimization](#gas-optimization)

---

## System Overview

Stellar Duels is a fully on-chain PvP game demonstrating blockchain gaming primitives:

```
┌─────────────┐         ┌──────────────────┐         ┌─────────────┐
│   Player 1  │────────▶│  Smart Contract  │◀────────│   Player 2  │
│  (Client)   │         │   (Soroban WASM) │         │  (Client)   │
└─────────────┘         └──────────────────┘         └─────────────┘
      │                          │                           │
      │                    Persistent                        │
      │                     Storage                          │
      │                          │                           │
      ▼                          ▼                           ▼
┌──────────────────────────────────────────────────────────────┐
│              Stellar Blockchain (Testnet/Mainnet)            │
│  • Player Profiles      • Game State      • Token Balances   │
└──────────────────────────────────────────────────────────────┘
```

**Key Components:**

1. **Smart Contract**: Rust code compiled to WASM, deployed on Soroban
2. **Persistent Storage**: Key-value store for player data and game states
3. **Token Integration**: XLM staking and prize distribution
4. **Client Layer**: CLI tools and scripts (extensible to web frontend)

---

## Smart Contract Architecture

### Module Organization

```rust
src/lib.rs
├── Data Structures (40 lines)
│   ├── Move enum (Attack, Defense, Magic)
│   ├── GameState enum (state machine states)
│   ├── Game struct (complete game data)
│   └── Player struct (profile + stats)
│
├── Storage Keys (10 lines)
│   └── DataKey enum (organizes persistent storage)
│
├── Contract Implementation (600+ lines)
│   ├── Player Management
│   │   ├── register_player()
│   │   └── get_player()
│   │
│   ├── Game Management
│   │   ├── create_game()
│   │   ├── join_game()
│   │   └── get_game() / get_active_games()
│   │
│   ├── Commit-Reveal Mechanism
│   │   ├── commit_move()
│   │   └── reveal_move()
│   │
│   ├── Game Resolution
│   │   └── finalize_game()
│   │
│   └── Helper Functions (private)
│       ├── calculate_commitment()
│       ├── determine_winner()
│       ├── update_player_stats()
│       └── storage utilities
│
└── Tests (50+ lines)
    ├── test_player_registration()
    └── test_commitment_calculation()
```

### Contract Interface (Public Functions)

| Function | Parameters | Returns | Description |
|----------|-----------|---------|-------------|
| `register_player` | `player: Address` | `Player` | Register/retrieve player profile |
| `get_player` | `player: Address` | `Option<Player>` | Query player stats |
| `create_game` | `creator, stake, token` | `u64` (game_id) | Start new game with stake |
| `join_game` | `game_id, player, token` | `Game` | Join as player_two |
| `get_game` | `game_id: u64` | `Option<Game>` | Query game state |
| `get_active_games` | - | `Vec<u64>` | List all active game IDs |
| `commit_move` | `game_id, player, commitment` | `Game` | Submit move hash |
| `reveal_move` | `game_id, player, move, salt` | `Game` | Reveal and verify move |
| `finalize_game` | `game_id, token` | `Game` | Determine winner, distribute prizes |

---

## Data Structures

### Move Enum
```rust
pub enum Move {
    Attack = 1,   // Beats Defense
    Defense = 2,  // Beats Magic
    Magic = 3,    // Beats Attack
}
```

**Design Decision**: Using discriminant values (1, 2, 3) allows easy serialization and client-side generation of commitments.

### Game Struct
```rust
pub struct Game {
    pub game_id: u64,
    pub player_one: Address,
    pub player_two: Option<Address>,  // None until someone joins
    pub stake_amount: i128,
    pub state: GameState,
    
    // Commit-reveal data
    pub p1_commitment: Option<BytesN<32>>,
    pub p2_commitment: Option<BytesN<32>>,
    pub p1_move: Option<Move>,
    pub p2_move: Option<Move>,
    
    pub winner: Option<Address>,
}
```

**Storage Cost**: Each `Game` consumes approximately:
- Fixed overhead: ~100 bytes
- Addresses: 32 bytes × 3 = 96 bytes
- Hashes: 32 bytes × 2 = 64 bytes
- **Total**: ~260 bytes per game

### Player Struct
```rust
pub struct Player {
    pub address: Address,
    pub wins: u32,
    pub losses: u32,
    pub draws: u32,
}
```

**Design Decision**: Simple stats for MVP. Extensible to ELO rating, NFT badges, etc.

---

## State Management

### Storage Model

Soroban uses a **key-value persistent storage**:

```rust
pub enum DataKey {
    GameCounter,           // u64: next game ID
    Game(u64),             // Game struct by ID
    Player(Address),       // Player struct by address
    ActiveGames,           // Vec<u64>: list of active game IDs
}
```

### Storage Operations

```rust
// Write
env.storage().persistent().set(&key, &value);

// Read
env.storage().persistent().get::<KeyType, ValueType>(&key);

// Check existence
env.storage().persistent().has(&key);
```

**Persistent vs Temporary**:
- **Persistent**: Survives rent periods (player profiles, game history)
- **Temporary**: Cheaper but expires (could use for in-progress games)

**Current Implementation**: All data uses persistent storage for simplicity.

---

## Cryptographic Commit-Reveal

### The Problem

Blockchain transactions are public. If players submitted moves directly:

```
❌ BAD FLOW:
1. Player 1 submits "Attack" → Visible on-chain
2. Player 2 sees "Attack" in pending transactions
3. Player 2 submits "Magic" (beats Attack) → Always wins!
```

### The Solution: Commit-Reveal

```
✅ SECURE FLOW:

COMMIT PHASE:
1. Player 1: commitment = SHA256(move || salt) → Submit hash only
2. Player 2: commitment = SHA256(move || salt) → Submit hash only
   (Neither player knows the other's move yet)

REVEAL PHASE:
3. Player 1: reveals (move, salt) → Contract verifies hash matches
4. Player 2: reveals (move, salt) → Contract verifies hash matches
   (Both moves are now locked in and verified)
```

### Implementation Details

**Commitment Generation (Client-Side)**:
```javascript
// JavaScript example
const move = 1; // Attack
const salt = crypto.randomBytes(32);

// 4 bytes (move) + 32 bytes (salt) = 36 bytes
const moveBuffer = Buffer.allocUnsafe(4);
moveBuffer.writeUInt32BE(move);
const data = Buffer.concat([moveBuffer, salt]);

// Hash the concatenated data
const commitment = crypto.createHash('sha256').update(data).digest();
```

**Verification (Smart Contract)**:
```rust
fn calculate_commitment(env: &Env, move_id: u32, salt: BytesN<32>) -> BytesN<32> {
    let move_bytes = move_id.to_be_bytes();
    let mut data = [0u8; 36];
    data[..4].copy_from_slice(&move_bytes);
    data[4..].copy_from_slice(salt.as_ref());
    
    let bytes = Bytes::from_array(env, &data);
    env.crypto().sha256(&bytes)
}
```

**Security Properties**:
- **Hiding**: Commitment reveals nothing about the move (one-way hash)
- **Binding**: Can't change move after committing (hash collision infeasible)
- **Verifiable**: Contract cryptographically proves honesty

---

## Game Flow & State Machine

### State Diagram

```
                    create_game()
      START ─────────────────────────▶ WAITING_FOR_PLAYER
                                              │
                                              │ join_game()
                                              ▼
                                       MOVES_COMMITTED ◀─┐
                                              │          │
                                              │          │ commit_move()
                                              │          │ (both players)
                                              │          │
                                              ▼          │
                                       MOVES_COMMITTED ──┘
                                              │
                                              │ reveal_move()
                                              │ (both players)
                                              ▼
                                       MOVES_COMMITTED
                                              │
                                              │ finalize_game()
                                              ▼
                                         COMPLETED
                                              │
                                              ▼
                                      (Prize distributed)
```

### State Transitions

| Current State | Action | Next State | Side Effects |
|--------------|--------|------------|--------------|
| - | `create_game()` | WAITING_FOR_PLAYER | Lock P1 stake |
| WAITING_FOR_PLAYER | `join_game()` | WAITING_FOR_PLAYER | Lock P2 stake |
| WAITING_FOR_PLAYER | `commit_move()` (1st) | WAITING_FOR_PLAYER | Store commitment |
| WAITING_FOR_PLAYER | `commit_move()` (2nd) | MOVES_COMMITTED | Store commitment |
| MOVES_COMMITTED | `reveal_move()` | MOVES_COMMITTED | Verify & store move |
| MOVES_COMMITTED | `finalize_game()` | COMPLETED | Determine winner, transfer tokens |

### Invariants

The contract maintains these invariants:

1. **Two-player games**: `player_two.is_some()` before moves can be committed
2. **Stake equality**: Both players deposit the same `stake_amount`
3. **Move validity**: Revealed moves must be 1, 2, or 3
4. **Hash integrity**: `calculate_commitment(move, salt) == stored_commitment`
5. **Finality**: Once `state == Completed`, game cannot be modified

---

## Security Considerations

### Authorization

Every state-changing function uses `require_auth()`:

```rust
pub fn commit_move(env: Env, player: Address, ...) {
    player.require_auth();  // Ensures caller owns this address
    // ...
}
```

This prevents:
- **Impersonation**: Can't submit moves for other players
- **Unauthorized actions**: Only the address owner can sign

### Commitment Security

**CRITICAL**: Salt must be:
- **Random**: Use cryptographically secure RNG (not `Math.random()`)
- **Secret**: Never share until reveal phase
- **Unique**: Different for each game

**Bad Example** ❌:
```javascript
const salt = Buffer.from('my_secret_password');  // Predictable!
```

**Good Example** ✅:
```javascript
const salt = crypto.randomBytes(32);  // Truly random
```

### Reentrancy

Soroban's execution model **prevents reentrancy**:
- Each invocation runs to completion
- No callbacks during token transfers
- State is saved atomically

Traditional reentrancy attacks (like the DAO hack) are not possible.

### Integer Overflow

Our profile uses:
```toml
[profile.release]
overflow-checks = true
```

This ensures:
- Addition/multiplication panics on overflow
- No silent wrapping (e.g., `u32::MAX + 1` panics, doesn't wrap to 0)

### Front-Running

**Not Applicable**: The commit-reveal scheme eliminates front-running concerns.

Traditional front-running scenario:
```
❌ Vulnerable:
1. Player 1 submits tx: "I choose Attack"
2. Player 2 sees tx in mempool
3. Player 2 submits tx with higher fee: "I choose Magic"
4. Player 2's tx gets mined first → unfair advantage
```

Our commit-reveal prevents this:
```
✅ Protected:
1. Player 1 submits: SHA256(Attack || salt) = 0x7a3f...
2. Player 2 sees: 0x7a3f... (meaningless hash)
3. Player 2 submits: SHA256(Defense || salt) = 0x9b2c...
4. Order doesn't matter - both moves are hidden
```

### Abandoned Games

**Current Limitation**: No timeout mechanism.

**Risk**: A player could commit but never reveal, locking funds forever.

**Future Enhancement**:
```rust
pub struct Game {
    // ...
    pub commit_deadline: u64,  // Timestamp
    pub reveal_deadline: u64,
}

pub fn claim_timeout_win(env: Env, game_id: u64) {
    let game = // ...
    assert!(env.ledger().timestamp() > game.reveal_deadline);
    // Award win to player who revealed, refund if neither revealed
}
```

---

## Gas Optimization

### Contract Size

Our profile optimizes for WASM size:

```toml
[profile.release]
opt-level = "z"        # Optimize for size (vs "3" for speed)
lto = true             # Link-time optimization
codegen-units = 1      # Better cross-function optimization
strip = "symbols"      # Remove debug symbols
```

**Result**: Contract compiles to ~15-25 KB WASM.

### Storage Access Patterns

**Expensive**: Multiple reads/writes

```rust
// ❌ Inefficient
let game = env.storage().get(&key);
game.p1_move = Some(move);
env.storage().set(&key, &game);
let game = env.storage().get(&key);  // Redundant read!
game.p2_move = Some(move);
env.storage().set(&key, &game);
```

**Optimized**: Single read/write per function

```rust
// ✅ Efficient
let mut game = env.storage().get(&key);
game.p1_move = Some(move);
game.p2_move = Some(move);
env.storage().set(&key, &game);  // One write
```

### Function Inlining

Helper functions are private and simple:

```rust
#[inline]
fn calculate_commitment(...) { ... }
```

Rust inlines these at compile time, reducing call overhead.

### Data Structure Choices

- **`BytesN<32>`** (fixed-size) instead of `Bytes` (dynamic) for hashes
- **`u32`** for counters (sufficient for millions of games)
- **`Option<T>`** instead of sentinel values (more explicit, same size)

---

## Future Enhancements

### 1. Tournaments
```rust
pub struct Tournament {
    pub tournament_id: u64,
    pub games: Vec<u64>,
    pub bracket: Vec<(Address, Address)>,
}
```

### 2. ELO Rating System
```rust
pub struct Player {
    // ...
    pub elo_rating: i32,
}

fn update_elo(winner_elo: i32, loser_elo: i32) -> (i32, i32) {
    // Standard ELO formula
}
```

### 3. NFT Rewards
```rust
pub fn mint_victory_nft(env: Env, winner: Address, game_id: u64) {
    // Call NFT contract to mint badge
}
```

### 4. Spectator Mode
```rust
pub fn get_game_events(env: Env, game_id: u64) -> Vec<GameEvent> {
    // Return commit/reveal timestamps for transparency
}
```

### 5. Multiple Move Types
```rust
pub enum Move {
    Attack, Defense, Magic,
    Counter, Heal, Fireball,  // Expand combat system
    // Each with unique rules
}
```

---

## Conclusion

Stellar Duels demonstrates production-ready patterns for blockchain games:

- ✅ Secure commit-reveal for hidden information
- ✅ Persistent state management
- ✅ Token staking and distribution
- ✅ Clean state machine design
- ✅ Comprehensive error handling
- ✅ Gas-optimized storage access

**Next Steps**: Build a web frontend, add tournaments, deploy to mainnet!
