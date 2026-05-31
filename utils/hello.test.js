const { greet } = require('./hello');

console.assert(
  greet('World') === 'Hello, World!',
  'greet("World") should return "Hello, World!"'
);

console.assert(
  greet('Archon') === 'Hello, Archon!',
  'greet("Archon") should return "Hello, Archon!"'
);

console.log('All tests passed.');
