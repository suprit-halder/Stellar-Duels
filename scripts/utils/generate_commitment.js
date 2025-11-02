/**
 * ============================================================================
 * GENERATE_COMMITMENT.JS - Create cryptographic commitments for moves
 * ============================================================================
 * This utility generates the hash commitment needed for the commit-reveal
 * scheme in Stellar Duels.
 * 
 * Usage:
 *   node generate_commitment.js <move_id>
 * 
 * Example:
 *   node generate_commitment.js 1  # Attack
 *   node generate_commitment.js 2  # Defense
 *   node generate_commitment.js 3  # Magic
 * ============================================================================
 */

const crypto = require('crypto');

/**
 * Generate a cryptographic commitment for a move
 * @param {number} moveId - The move choice (1=Attack, 2=Defense, 3=Magic)
 * @returns {Object} - { commitment: hex string, salt: hex string }
 */
function generateCommitment(moveId) {
    // Validate move
    if (![1, 2, 3].includes(moveId)) {
        throw new Error('Invalid move. Must be 1 (Attack), 2 (Defense), or 3 (Magic)');
    }
    
    // Generate cryptographically secure random 32-byte salt
    const salt = crypto.randomBytes(32);
    
    // Convert move_id to 4 bytes (big-endian, matching Rust's to_be_bytes)
    const moveBuffer = Buffer.allocUnsafe(4);
    moveBuffer.writeUInt32BE(moveId);
    
    // Concatenate: 4 bytes (move) + 32 bytes (salt) = 36 bytes total
    const data = Buffer.concat([moveBuffer, salt]);
    
    // Hash with SHA256
    const hash = crypto.createHash('sha256').update(data).digest();
    
    return {
        commitment: hash.toString('hex'),
        salt: salt.toString('hex'),
        moveId: moveId,
        moveName: getMoveN(moveId)
    };
}

/**
 * Get human-readable move name
 */
function getMoveName(moveId) {
    const moves = { 1: 'Attack', 2: 'Defense', 3: 'Magic' };
    return moves[moveId] || 'Unknown';
}

// ============================================================================
// CLI Interface
// ============================================================================

if (require.main === module) {
    const args = process.argv.slice(2);
    
    if (args.length === 0) {
        console.log('📜 Stellar Duels - Commitment Generator');
        console.log('');
        console.log('Usage: node generate_commitment.js <move_id>');
        console.log('');
        console.log('Moves:');
        console.log('  1 = Attack   (beats Defense)');
        console.log('  2 = Defense  (beats Magic)');
        console.log('  3 = Magic    (beats Attack)');
        console.log('');
        console.log('Example:');
        console.log('  node generate_commitment.js 1');
        process.exit(0);
    }
    
    const moveId = parseInt(args[0]);
    
    try {
        const result = generateCommitment(moveId);
        
        console.log('');
        console.log('🎲 Move Commitment Generated');
        console.log('='.repeat(60));
        console.log('');
        console.log(`Move:       ${result.moveName} (${result.moveId})`);
        console.log('');
        console.log('Commitment (hash):');
        console.log(`  ${result.commitment}`);
        console.log('');
        console.log('Salt (keep secret!):');
        console.log(`  ${result.salt}`);
        console.log('');
        console.log('='.repeat(60));
        console.log('');
        console.log('⚠️  IMPORTANT:');
        console.log('   1. Submit the COMMITMENT when calling commit_move()');
        console.log('   2. Keep the SALT secret until reveal phase');
        console.log('   3. Use the SALT when calling reveal_move()');
        console.log('');
        console.log('📋 Submit commitment with:');
        console.log(`   stellar contract invoke --id <CONTRACT_ID> --source <PLAYER> --network testnet -- commit_move --game_id <ID> --player <PLAYER> --commitment ${result.commitment}`);
        console.log('');
        console.log('🔓 Reveal later with:');
        console.log(`   stellar contract invoke --id <CONTRACT_ID> --source <PLAYER> --network testnet -- reveal_move --game_id <ID> --player <PLAYER> --move_choice ${result.moveId} --salt ${result.salt}`);
        console.log('');
        
    } catch (error) {
        console.error('❌ Error:', error.message);
        process.exit(1);
    }
}

module.exports = { generateCommitment };
