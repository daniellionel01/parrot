drop database if exists jsontypedef;

create database if not exists jsontypedef;

use jsontypedef;

create table users (
  id int auto_increment primary key,
  col_int int,
  col_varchar_nullable varchar(255),
  col_varchar_notnull varchar(255) not null,
  col_text text
);

create table authors (
  id bigint not null auto_increment primary key,
  name text not null,
  bio text
);

insert into
  users
values
  (1, 13, "danny", "danny not null", "");
