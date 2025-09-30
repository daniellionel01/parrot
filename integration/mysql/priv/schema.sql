drop table if exists users;

create table `users` (
  `id` int auto_increment primary key,
  `username` varchar(255) not null unique,
  `created_at` timestamp default current_timestamp,
  `status` enum('like', 'neutral'),
  `admin` tinyint(1) not null default 1
);
