drop table if exists posts;
drop table if exists users;

create table users (
  id int auto_increment primary key,
  username varchar(255) not null unique,
  created_at timestamp default current_timestamp,
  status enum('like', 'neutral'),
  admin tinyint(1) not null default 1
);

create table posts (
  id int auto_increment primary key,
  created_at timestamp default current_timestamp,
  title varchar(255) not null unique,

  user_id integer,

  foreign key (user_id) references users(id) on delete cascade
);
