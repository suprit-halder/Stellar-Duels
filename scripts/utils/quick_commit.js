const crypto = require('crypto');

// Generate commitment for move 1 (Attack)
const move1 = 1;
const salt1 = crypto.randomBytes(32);
const moveBuffer1 = Buffer.allocUnsafe(4);
moveBuffer1.writeUInt32BE(move1);
const data1 = Buffer.concat([moveBuffer1, salt1]);
const commitment1 = crypto.createHash('sha256').update(data1).digest('hex');

// Generate commitment for move 3 (Magic)
const move2 = 3;
const salt2 = crypto.randomBytes(32);
const moveBuffer2 = Buffer.allocUnsafe(4);
moveBuffer2.writeUInt32BE(move2);
const data2 = Buffer.concat([moveBuffer2, salt2]);
const commitment2 = crypto.createHash('sha256').update(data2).digest('hex');

console.log(JSON.stringify({
    p1: { move: move1, commitment: commitment1, salt: salt1.toString('hex') },
    p2: { move: move2, commitment: commitment2, salt: salt2.toString('hex') }
}));
