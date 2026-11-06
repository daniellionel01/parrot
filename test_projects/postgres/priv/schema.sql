create type mood as enum ('happy', 'sad');

create table smallints (value smallint not null, nullable_value smallint);
create table integers (value integer not null, nullable_value integer);
create table bigints (value bigint not null, nullable_value bigint);
create table reals (value real not null, nullable_value real);
create table doubles (value double precision not null, nullable_value double precision);
create table numerics (value numeric(10, 2) not null, nullable_value numeric(10, 2));
create table texts (value text not null, nullable_value text);
create table varchars (value varchar(10) not null, nullable_value varchar(10));
create table chars (value char(5) not null, nullable_value char(5));
create table booleans (value boolean not null, nullable_value boolean);
create table byteas (value bytea not null, nullable_value bytea);
create table uuids (value uuid not null, nullable_value uuid);
create table jsons (value json not null, nullable_value json);
create table jsonbs (value jsonb not null, nullable_value jsonb);
create table dates (value date not null, nullable_value date);
create table timestamps (value timestamp not null, nullable_value timestamp);
create table timestamptzs (value timestamptz not null, nullable_value timestamptz);
create table times (value time not null, nullable_value time);
create table moods (value mood not null, nullable_value mood);
create table mood_arrays (value mood[] not null, nullable_value mood[]);
create table text_arrays (value text[] not null, nullable_value text[]);
create table integer_arrays (value integer[] not null, nullable_value integer[]);

-- https://github.com/daniellionel01/parrot/issues/74
create table keywords ("type" text not null, "case" text not null);
