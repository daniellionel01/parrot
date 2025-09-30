create table users (
  id integer primary key autoincrement,
  username text not null unique,
  created_at text default current_timestamp,
  balance real not null default 0.0,
  last_known_location decimal(9, 6),
  role text,
  avatar blob
);

create table posts (
  id integer primary key autoincrement,
  created_at text default current_timestamp,
  title text not null unique,

  user_id integer not null,

  foreign key (user_id) references users(id) on delete cascade
);
