create table users (
  id integer primary key autoincrement,
  username text not null unique,
  created_at text not null default current_timestamp,
  balance real not null default 0.0
);
