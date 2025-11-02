// ============================================================================
// STELLAR DUELS - Decentralized PvP Turn-Based Combat Game
// ============================================================================
// A smart contract demonstrating:
// - On-chain state management (players, games, balances)
// - Cryptographic commit-reveal scheme (hidden moves)
// - Game logic execution and validation
// - Token staking and prize distribution
// ============================================================================

// The #![no_std] attribute tells Rust not to include the standard library
// Soroban contracts run in a WASM environment with limited resources
#![no_std]

// Import the Soroban SDK - this is the foundation for all contract development
use soroban_sdk::{
    contract,      // Macro to define the contract
    contractimpl,  // Macro to define contract methods
    contracttype,  // Macro to define types that can be stored
    Address,       // Stellar address type (identifies accounts/contracts)
    BytesN,        // Fixed-size byte array (for hashes)
    Env,           // Environment - provides access to blockchain state, crypto, etc.
    Vec,           // Dynamic array
    token,         // Token interface for XLM transfers
};

// ============================================================================
// DATA STRUCTURES
// ============================================================================

/// Represents a player's move in the game
/// Similar to Rock-Paper-Scissors but themed for combat
#[contracttype]
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum Move {
    Attack = 1,   // Beats Defense (overpowers shield)
    Defense = 2,  // Beats Magic (blocks spell)
    Magic = 3,    // Beats Attack (confuses warrior)
}

/// Tracks the current state of a game
#[contracttype]
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum GameState {
    WaitingForPlayer,  // Game created, waiting for second player
    MovesCommitted,    // Both players submitted hidden moves
    Completed,         // Game finished, winner determined
}

/// Complete game data structure
/// This is stored on-chain for each active game
#[contracttype]
#[derive(Clone, Debug)]
pub struct Game {
    pub game_id: u64,              // Unique game identifier
    pub player_one: Address,        // First player's address
    pub player_two: Option<Address>, // Second player (None until someone joins)
    pub stake_amount: i128,         // XLM tokens staked per player
    pub state: GameState,           // Current game state
    
    // Commit-reveal mechanism - using empty bytes to represent "None"
    pub p1_commitment: BytesN<32>, // Player 1's move hash (all zeros = not committed)
    pub p2_commitment: BytesN<32>, // Player 2's move hash (all zeros = not committed)
    
    pub p1_move: u32,      // Player 1's revealed move (0 = not revealed, 1-3 = move)
    pub p2_move: u32,      // Player 2's revealed move (0 = not revealed, 1-3 = move)
    
    pub winner: Option<Address>,    // Winner's address (None = draw or incomplete)
}

/// Player profile stored on-chain
#[contracttype]
#[derive(Clone, Debug)]
pub struct Player {
    pub address: Address,
    pub wins: u32,
    pub losses: u32,
    pub draws: u32,
}

// ============================================================================
// STORAGE KEYS
// ============================================================================
// Soroban uses a key-value storage model
// We define enum variants that act as keys to organize our data

#[contracttype]
#[derive(Clone)]
pub enum DataKey {
    GameCounter,           // Stores the next game ID (auto-increment)
    Game(u64),             // Stores Game struct by game_id
    Player(Address),       // Stores Player struct by address
    ActiveGames,           // Stores Vec<u64> of active game IDs
}

// ============================================================================
// SMART CONTRACT IMPLEMENTATION
// ============================================================================

#[contract]
pub struct StellarDuelsContract;

#[contractimpl]
impl StellarDuelsContract {
    
    // ========================================================================
    // PLAYER MANAGEMENT
    // ========================================================================
    
    /// Register a new player or retrieve existing player data
    /// This function is idempotent - calling it multiple times is safe
    pub fn register_player(env: Env, player: Address) -> Player {
        // Verify that the caller is authorized to register this address
        // This prevents someone from registering another person's address
        player.require_auth();
        
        let key = DataKey::Player(player.clone());
        
        // Check if player already exists in storage
        if let Some(existing_player) = env.storage().persistent().get::<DataKey, Player>(&key) {
            return existing_player;
        }
        
        // Create new player profile
        let new_player = Player {
            address: player.clone(),
            wins: 0,
            losses: 0,
            draws: 0,
        };
        
        // Store in persistent storage (survives contract upgrades)
        env.storage().persistent().set(&key, &new_player);
        
        new_player
    }
    
    /// Retrieve player statistics
    pub fn get_player(env: Env, player: Address) -> Option<Player> {
        let key = DataKey::Player(player);
        env.storage().persistent().get(&key)
    }
    
    // ========================================================================
    // GAME MANAGEMENT
    // ========================================================================
    
    /// Create a new game with a stake amount
    /// The creator becomes player_one and must deposit stake_amount XLM
    pub fn create_game(
        env: Env,
        creator: Address,
        stake_amount: i128,
        token_address: Address,
    ) -> u64 {
        // Verify the creator authorized this action
        creator.require_auth();
        
        // Ensure player is registered
        assert!(
            env.storage().persistent().has(&DataKey::Player(creator.clone())),
            "Player must be registered first"
        );
        
        // Get next game ID (auto-increment counter)
        let game_id = Self::get_and_increment_counter(&env);
        
        // Transfer stake from creator to contract
        // This locks the funds until the game completes
        let token_client = token::Client::new(&env, &token_address);
        token_client.transfer(
            &creator,
            &env.current_contract_address(),
            &stake_amount,
        );
        
        // Create game data structure
        let game = Game {
            game_id,
            player_one: creator.clone(),
            player_two: None,
            stake_amount,
            state: GameState::WaitingForPlayer,
            p1_commitment: BytesN::from_array(&env, &[0u8; 32]),
            p2_commitment: BytesN::from_array(&env, &[0u8; 32]),
            p1_move: 0,
            p2_move: 0,
            winner: None,
        };
        
        // Store game in persistent storage
        env.storage().persistent().set(&DataKey::Game(game_id), &game);
        
        // Add to active games list
        Self::add_to_active_games(&env, game_id);
        
        game_id
    }
    
    /// Join an existing game as player_two
    /// Must deposit the same stake_amount as player_one
    pub fn join_game(
        env: Env,
        game_id: u64,
        player: Address,
        token_address: Address,
    ) -> Game {
        player.require_auth();
        
        // Retrieve the game
        let mut game: Game = env.storage()
            .persistent()
            .get(&DataKey::Game(game_id))
            .expect("Game not found");
        
        // Validate game state
        assert_eq!(game.state, GameState::WaitingForPlayer, "Game is not accepting players");
        assert!(game.player_two.is_none(), "Game already has two players");
        assert!(player != game.player_one, "Cannot play against yourself");
        
        // Ensure player is registered
        assert!(
            env.storage().persistent().has(&DataKey::Player(player.clone())),
            "Player must be registered first"
        );
        
        // Transfer stake from joining player to contract
        let token_client = token::Client::new(&env, &token_address);
        token_client.transfer(
            &player,
            &env.current_contract_address(),
            &game.stake_amount,
        );
        
        // Update game with second player
        game.player_two = Some(player);
        
        // Save updated game
        env.storage().persistent().set(&DataKey::Game(game_id), &game);
        
        game
    }
    
    /// Retrieve game data
    pub fn get_game(env: Env, game_id: u64) -> Option<Game> {
        env.storage().persistent().get(&DataKey::Game(game_id))
    }
    
    /// List all active game IDs
    pub fn get_active_games(env: Env) -> Vec<u64> {
        env.storage()
            .persistent()
            .get(&DataKey::ActiveGames)
            .unwrap_or(Vec::new(&env))
    }
    
    // ========================================================================
    // COMMIT-REVEAL MECHANISM
    // ========================================================================
    
    /// Submit a move commitment (hash of move + secret salt)
    /// This hides the move from the opponent until reveal phase
    /// 
    /// How to generate commitment off-chain:
    /// 1. Choose your move (1=Attack, 2=Defense, 3=Magic)
    /// 2. Generate random 32-byte salt
    /// 3. commitment = SHA256(move_bytes || salt_bytes)
    /// 4. Submit this commitment hash
    pub fn commit_move(
        env: Env,
        game_id: u64,
        player: Address,
        commitment: BytesN<32>,
    ) -> Game {
        player.require_auth();
        
        let mut game: Game = env.storage()
            .persistent()
            .get(&DataKey::Game(game_id))
            .expect("Game not found");
        
        // Ensure game has two players
        assert!(game.player_two.is_some(), "Waiting for second player");
        
        // Create zero bytes for comparison
        let zero_commitment = BytesN::from_array(&env, &[0u8; 32]);
        
        // Determine if this is player 1 or player 2
        if player == game.player_one {
            assert_eq!(game.p1_commitment, zero_commitment, "Player 1 already committed");
            game.p1_commitment = commitment;
        } else if Some(player.clone()) == game.player_two {
            assert_eq!(game.p2_commitment, zero_commitment, "Player 2 already committed");
            game.p2_commitment = commitment;
        } else {
            panic!("Player not in this game");
        }
        
        // If both players committed, advance state
        if game.p1_commitment != zero_commitment && game.p2_commitment != zero_commitment {
            game.state = GameState::MovesCommitted;
        }
        
        env.storage().persistent().set(&DataKey::Game(game_id), &game);
        
        game
    }
    
    /// Reveal your move and verify it matches the commitment
    /// This is where the magic happens: the contract validates honesty
    pub fn reveal_move(
        env: Env,
        game_id: u64,
        player: Address,
        move_choice: u32,
        salt: BytesN<32>,
    ) -> Game {
        player.require_auth();
        
        let mut game: Game = env.storage()
            .persistent()
            .get(&DataKey::Game(game_id))
            .expect("Game not found");
        
        assert_eq!(game.state, GameState::MovesCommitted, "Not ready for reveals");
        
        // Validate move choice
        assert!(move_choice >= 1 && move_choice <= 3, "Invalid move (must be 1, 2, or 3)");
        
        // Calculate what the commitment should be
        let calculated_commitment = Self::calculate_commitment(&env, move_choice, salt);
        
        // Verify and store the revealed move
        if player == game.player_one {
            assert_ne!(game.p1_commitment, BytesN::from_array(&env, &[0u8; 32]), "No commitment found");
            assert_eq!(calculated_commitment, game.p1_commitment, "Move does not match commitment");
            game.p1_move = move_choice;
        } else if Some(player.clone()) == game.player_two {
            assert_ne!(game.p2_commitment, BytesN::from_array(&env, &[0u8; 32]), "No commitment found");
            assert_eq!(calculated_commitment, game.p2_commitment, "Move does not match commitment");
            game.p2_move = move_choice;
        } else {
            panic!("Player not in this game");
        }
        
        env.storage().persistent().set(&DataKey::Game(game_id), &game);
        
        game
    }
    
    // ========================================================================
    // GAME RESOLUTION
    // ========================================================================
    
    /// Finalize the game: determine winner and distribute prizes
    pub fn finalize_game(
        env: Env,
        game_id: u64,
        token_address: Address,
    ) -> Game {
        let mut game: Game = env.storage()
            .persistent()
            .get(&DataKey::Game(game_id))
            .expect("Game not found");
        
        assert_eq!(game.state, GameState::MovesCommitted, "Game not ready to finalize");
        
        // Both moves must be revealed (non-zero)
        assert!(game.p1_move > 0, "Player 1 hasn't revealed");
        assert!(game.p2_move > 0, "Player 2 hasn't revealed");
        
        let p1_move = game.p1_move;
        let p2_move = game.p2_move;
        
        // Determine winner using game logic
        let winner_addr = Self::determine_winner(&game, p1_move, p2_move);
        
        game.winner = winner_addr.clone();
        game.state = GameState::Completed;
        
        // Distribute prizes
        let token_client = token::Client::new(&env, &token_address);
        let total_pot = game.stake_amount * 2;
        
        if let Some(winner) = &winner_addr {
            // Winner takes all
            token_client.transfer(
                &env.current_contract_address(),
                winner,
                &total_pot,
            );
            
            // Update player stats
            Self::update_player_stats(&env, &game.player_one, winner == &game.player_one);
            let p2 = game.player_two.as_ref().unwrap();
            Self::update_player_stats(&env, p2, winner == p2);
        } else {
            // Draw - refund both players
            token_client.transfer(
                &env.current_contract_address(),
                &game.player_one,
                &game.stake_amount,
            );
            let p2 = game.player_two.as_ref().unwrap();
            token_client.transfer(
                &env.current_contract_address(),
                p2,
                &game.stake_amount,
            );
            
            // Update stats for draw
            Self::increment_draws(&env, &game.player_one);
            Self::increment_draws(&env, p2);
        }
        
        // Remove from active games
        Self::remove_from_active_games(&env, game_id);
        
        env.storage().persistent().set(&DataKey::Game(game_id), &game);
        
        game
    }
    
    // ========================================================================
    // HELPER FUNCTIONS (PRIVATE LOGIC)
    // ========================================================================
    
    /// Calculate the commitment hash from move and salt
    /// This is the same calculation players do off-chain
    fn calculate_commitment(env: &Env, move_id: u32, salt: BytesN<32>) -> BytesN<32> {
        // Convert move_id to 4 bytes (big-endian)
        let move_bytes = move_id.to_be_bytes();
        
        // Create 36-byte array: 4 bytes (move) + 32 bytes (salt)
        let mut data = [0u8; 36];
        data[..4].copy_from_slice(&move_bytes);
        data[4..].copy_from_slice(salt.to_array().as_ref());
        
        // Hash the concatenated data
        let bytes = soroban_sdk::Bytes::from_array(env, &data);
        env.crypto().sha256(&bytes).into()
    }
    
    /// Game logic: determine winner based on moves
    /// Returns Some(Address) for winner, None for draw
    fn determine_winner(game: &Game, p1_move: u32, p2_move: u32) -> Option<Address> {
        if p1_move == p2_move {
            return None; // Draw
        }
        
        // Attack (1) beats Defense (2), Defense (2) beats Magic (3), Magic (3) beats Attack (1)
        let p1_wins = match (p1_move, p2_move) {
            (1, 2) => true,  // Attack beats Defense
            (2, 3) => true,  // Defense beats Magic
            (3, 1) => true,  // Magic beats Attack
            _ => false,
        };
        
        if p1_wins {
            Some(game.player_one.clone())
        } else {
            game.player_two.clone()
        }
    }
    
    /// Update player win/loss statistics
    fn update_player_stats(env: &Env, player_addr: &Address, won: bool) {
        let key = DataKey::Player(player_addr.clone());
        let mut player: Player = env.storage()
            .persistent()
            .get(&key)
            .expect("Player not found");
        
        if won {
            player.wins += 1;
        } else {
            player.losses += 1;
        }
        
        env.storage().persistent().set(&key, &player);
    }
    
    /// Increment draw count for player
    fn increment_draws(env: &Env, player_addr: &Address) {
        let key = DataKey::Player(player_addr.clone());
        let mut player: Player = env.storage()
            .persistent()
            .get(&key)
            .expect("Player not found");
        
        player.draws += 1;
        
        env.storage().persistent().set(&key, &player);
    }
    
    /// Get and increment the game counter (atomic operation)
    fn get_and_increment_counter(env: &Env) -> u64 {
        let key = DataKey::GameCounter;
        let counter: u64 = env.storage()
            .persistent()
            .get(&key)
            .unwrap_or(1);
        
        env.storage().persistent().set(&key, &(counter + 1));
        
        counter
    }
    
    /// Add game to active games list
    fn add_to_active_games(env: &Env, game_id: u64) {
        let key = DataKey::ActiveGames;
        let mut active: Vec<u64> = env.storage()
            .persistent()
            .get(&key)
            .unwrap_or(Vec::new(env));
        
        active.push_back(game_id);
        env.storage().persistent().set(&key, &active);
    }
    
    /// Remove game from active games list
    fn remove_from_active_games(env: &Env, game_id: u64) {
        let key = DataKey::ActiveGames;
        let active: Vec<u64> = env.storage()
            .persistent()
            .get(&key)
            .unwrap_or(Vec::new(env));
        
        // Filter out the game_id - rebuild vec without it
        let mut filtered = Vec::new(env);
        for id in active.iter() {
            if id != game_id {
                filtered.push_back(id);
            }
        }
        
        env.storage().persistent().set(&key, &filtered);
    }
}

// ============================================================================
// TESTS
// ============================================================================

#[cfg(test)]
mod test {
    use super::*;
    use soroban_sdk::{testutils::Address as _, Address, Env};

    #[test]
    fn test_player_registration() {
        let env = Env::default();
        env.mock_all_auths();  // Mock authorization for testing
        
        let contract_id = env.register_contract(None, StellarDuelsContract);
        let client = StellarDuelsContractClient::new(&env, &contract_id);
        
        let player = Address::generate(&env);
        
        let registered = client.register_player(&player);
        assert_eq!(registered.wins, 0);
        assert_eq!(registered.losses, 0);
        assert_eq!(registered.draws, 0);
    }
    
    #[test]
    fn test_commitment_calculation() {
        let env = Env::default();
        
        let move_id: u32 = 1; // Attack
        let salt = BytesN::from_array(&env, &[42u8; 32]);
        
        let commitment = StellarDuelsContract::calculate_commitment(&env, move_id, salt.clone());
        
        // Same inputs should produce same hash
        let commitment2 = StellarDuelsContract::calculate_commitment(&env, move_id, salt.clone());
        assert_eq!(commitment, commitment2);
        
        // Different move should produce different hash
        let commitment3 = StellarDuelsContract::calculate_commitment(&env, 2, salt);
        assert_ne!(commitment, commitment3);
    }
}
