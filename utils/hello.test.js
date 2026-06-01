const { greet } = require('./hello');

test('greet returns correct greeting', () => {
  expect(greet('World')).toBe('Hello, World!');
  expect(greet('Archon')).toBe('Hello, Archon!');
});
