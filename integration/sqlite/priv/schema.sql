create table users (
  id integer primary key autoincrement,
  username text not null unique,
  created_at text default current_timestamp,
  balance real not null default 0.0,
  last_known_location decimal(9, 6),
  role text,
  avatar blob
);
