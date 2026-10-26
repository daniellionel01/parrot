create extension if not exists "uuid-ossp";
create extension if not exists hstore;

drop table if exists users;
drop type if exists user_role;

create type user_role as enum ('admin', 'user', 'guest');

create extension citext;

create table users (
  id serial primary key,
  email citext not null unique,
  username varchar(255) not null unique,
  created_at timestamp default current_timestamp,
  date_of_birth date,

  profile jsonb,
  extra_info json,

  favorite_numbers integer[],
  role user_role,
  document bytea
);

create table posts (
  id serial primary key,
  created_at timestamp default current_timestamp,
  title varchar(255) not null unique,

  user_id integer not null references users(id) on delete cascade
);

CREATE FUNCTION public.get_tournament_champion_bets_safe()
    RETURNS TABLE
            (
                id              uuid,
                created_by      uuid,
                updated_by      uuid,
                updated_at      timestamp without time zone,
                tournament_name text,
                team_name       text
            )
    LANGUAGE plpgsql
    STABLE
AS
$$
BEGIN
  RETURN QUERY
  SELECT
    gen_random_uuid()         AS id,
    gen_random_uuid()         AS created_by,
    gen_random_uuid()         AS updated_by,
    now()::timestamp          AS updated_at,
    'Dummy Tournament'::text  AS tournament_name,
    'Dummy Team'::text        AS team_name;
END;
$$;
