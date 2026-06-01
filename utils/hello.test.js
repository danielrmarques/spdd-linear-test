const { greet } = require('./hello');

test('greet returns Hello, World!', () => {
  expect(greet('World')).toBe('Hello, World!');
});

test('greet returns Hello, Archon!', () => {
  expect(greet('Archon')).toBe('Hello, Archon!');
});
