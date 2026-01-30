INSERT INTO
  users (username)
VALUES
  ('bob'),
  ('charlie');

INSERT INTO users (
  username,
  email,
  profile,
  extra_info,
  favorite_numbers,
  role,
  document
) VALUES (
  'alice',
  'alice@example.com',
  '{"a": 1, "b": 2}',
  '{"c": 3}',
  ARRAY[3, 11],
  'user',
  decode('DEADBEEF', 'hex')
);
