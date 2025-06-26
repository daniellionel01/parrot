INSERT INTO
  users (username)
VALUES
  ('bob'),
  ('charlie');

INSERT INTO users (
  username,
  profile,
  extra_info,
  favorite_numbers,
  role,
  document
) VALUES (
  'alice',
  '{"a": 1, "b": 2}',
  '{"c": 3}',
  ARRAY[3, 11],
  'user',
  decode('DEADBEEF', 'hex')
);
