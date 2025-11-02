🎮 Project Description

Stellar Duels is a decentralized, turn-based Player-versus-Player (PvP) combat game built on the Stellar blockchain using the Soroban Smart Contract Platform. The project showcases the potential of blockchain gaming through transparent gameplay logic, secure move commitments, and token-based incentives.

Players engage in on-chain duels where outcomes are determined by smart contract logic rather than a central authority. By integrating cryptographic commit-reveal mechanisms and token staking, Stellar Duels ensures fairness, transparency, and verifiable results for every match.

🌐 Project Vision

Our vision is to pioneer trustless and transparent on-chain gaming by leveraging Stellar’s Soroban platform. Stellar Duels aims to:

Redefine Fair Play: Guarantee cheat-proof gameplay through cryptographic commitments.

Promote Blockchain Gaming Adoption: Demonstrate accessible, low-fee decentralized gaming on Stellar.

Enable True Ownership: Empower players to control their assets and rewards on-chain.

Encourage Developer Innovation: Provide an open blueprint for future Soroban-based gaming DApps.

Foster Competitive Transparency: Build a verifiable leaderboard and battle history open to all participants.

⚙️ Key Features
1. On-Chain Game Management

Players can create and join duel sessions directly through smart contract calls.

Game state (players, stakes, moves, results) is persistently stored on-chain.

Fair matchmaking logic ensures verifiable results without central servers.

2. Commit-Reveal System

Each player first submits a hashed move (commit phase) to hide their choice.

In the reveal phase, players disclose their move and nonce.

Prevents front-running and ensures fairness in move disclosure.

3. Move Logic & Outcome Determination

Supported moves: Attack (1), Defense (2), and Magic (3).

Rules: Attack beats Defense, Defense beats Magic, Magic beats Attack.

Contract automatically determines the winner and distributes rewards.

4. Token Staking & Rewards

Players stake tokens (e.g., XLM) to participate in duels.

The winner receives the pooled stake minus minimal fees.

Optional reward pool for high-ranking players and tournaments.

5. Event Logging & Transparency

Emits events for duel creation, commitment, reveal, and result declaration.

Complete on-chain record of all duels for auditing and leaderboard display.

6. Security & Access Control

Enforces player authentication via verified Stellar addresses.

Protects against replay, double-commit, and timeout exploits.

Ensures that all gameplay logic executes deterministically on-chain.

🚀 Future Scope

Freighter Wallet Integration: Seamless game interaction through browser wallet signing.

Leaderboard Module: On-chain ranking system for top players.

NFT Battle Assets: Unique character or item NFTs for visual and gameplay customization.

Cross-Game Economy: Shared tokens or achievements across multiple Stellar-based games.

DAO-Driven Governance: Community voting for rule changes, balancing, and tournament hosting.

7. Contract Details
   
   Contract ID CBHVZGXKAXHA4T2JM4B4J255UOS537HYH4HI6JJS4SK35FDK4QKKCWIR
<img width="1798" height="891" alt="Screenshot 2025-11-02 175755" src="https://github.com/user-attachments/assets/8e8c5154-8d80-4014-8ca9-b9026ad8b05e" />

