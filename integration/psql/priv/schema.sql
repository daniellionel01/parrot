create extension if not exists "uuid-ossp";
create extension if not exists hstore;

drop table if exists users;
drop type if exists user_role;

create type user_role as enum ('admin', 'user', 'guest');

create type permission as enum ('admin', 'readonly');

create type Simple as enum ();

create table users (
  id serial primary key,
  username varchar(255) not null unique,
  created_at timestamp default current_timestamp,
  date_of_birth date,

  profile jsonb,
  extra_info json,

  favorite_numbers integer[],
  role user_role,
  permission permission,
  document bytea,

  simple Simple
);

create table posts (
  id serial primary key,
  created_at timestamp default current_timestamp,
  title varchar(255) not null unique,

  user_id integer not null references users(id) on delete cascade
);
